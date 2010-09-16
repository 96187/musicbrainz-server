#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    no warnings 'redefine';
    use DBDefs;
    *DBDefs::_RUNNING_TESTS = sub { 1 };
    *DBDefs::WEB_SERVER = sub { "localhost" };
}

BEGIN { use_ok 'MusicBrainz::Server::Data::Vote' }

use MusicBrainz::Server::Email;
use MusicBrainz::Server::Types qw( :vote );
use MusicBrainz::Server::Test;

my $c = MusicBrainz::Server::Test->create_test_context();
MusicBrainz::Server::Test->prepare_test_database($c, '+vote');
MusicBrainz::Server::Test->prepare_raw_test_database($c, '+vote_stats');

{
    package MockEdit;
    use Moose;
    extends 'MusicBrainz::Server::Edit';
    sub edit_type { 1 }
    sub edit_name { 'mock edit' }
}

use MusicBrainz::Server::EditRegistry;
MusicBrainz::Server::EditRegistry->register_type("MockEdit", 1);

my $edit = $c->model('Edit')->create(
    editor_id => 1,
    edit_type => 1,
    foo => 'bar',
);

# Test voting on an edit
$c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => $VOTE_NO });
$c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => $VOTE_YES });
$c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => $VOTE_ABSTAIN });
$c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => $VOTE_YES });

my $email_transport = MusicBrainz::Server::Email->get_test_transport;
is(scalar @{ $email_transport->deliveries }, 1);

my $email = $email_transport->deliveries->[-1]->{email};
is($email->get_header('Subject'), 'Someone has voted against your edit');
is($email->get_header('References'), sprintf '<edit-%d@musicbrainz.org>', $edit->id);
is($email->get_header('To'), '"editor1" <editor1@example.com>');
like($email->get_body, qr{http://localhost/edit/${\ $edit->id }});
like($email->get_body, qr{'editor2'});

$edit = $c->model('Edit')->get_by_id($edit->id);
$c->model('Vote')->load_for_edits($edit);

is(scalar @{ $edit->votes }, 4);
is($edit->votes->[0]->vote, $VOTE_NO);
is($edit->votes->[1]->vote, $VOTE_YES);
is($edit->votes->[2]->vote, $VOTE_ABSTAIN);
is($edit->votes->[3]->vote, $VOTE_YES);

is($edit->votes->[$_]->superseded, 1) for 0..2;
is($edit->votes->[3]->superseded, 0);
is($edit->votes->[$_]->editor_id, 2) for 0..3;

# Make sure the person who created a vote cannot vote
$c->model('Vote')->enter_votes(1, { edit_id => $edit->id, vote => $VOTE_NO });
$edit = $c->model('Edit')->get_by_id($edit->id);
$c->model('Vote')->load_for_edits($edit);
is(scalar @{ $email_transport->deliveries }, 1);
is($email_transport->deliveries->[-1]->{email}, $email);

is(scalar @{ $edit->votes }, 5);
is($edit->votes->[$_]->editor_id, 2) for 0..3;

# Check the vote counts
$edit = $c->model('Edit')->get_by_id($edit->id);
$c->model('Vote')->load_for_edits($edit);
is($edit->yes_votes, 1);
is($edit->no_votes, 1);

$c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => $VOTE_ABSTAIN });
$edit = $c->model('Edit')->get_by_id($edit->id);
is($edit->yes_votes, 0);
is($edit->no_votes, 1);

# Make sure future no votes do not cause another email to be sent out
$c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => $VOTE_NO });
is(scalar @{ $email_transport->deliveries }, 1);
is($email_transport->deliveries->[-1]->{email}, $email);

# Entering invalid votes doesn't do anything
$c->model('Vote')->load_for_edits($edit);
my $old_count = @{ $edit->votes };
$c->model('Vote')->enter_votes(2, { edit_id => $edit->id, vote => 123 });
is(@{ $edit->votes }, $old_count, 'vote count should not have changed');

# Check the voting statistics
my $stats = $c->model('Vote')->editor_statistics(1);
is_deeply($stats, [
    {
        name   => 'Yes',
        recent => {
            count      => 2,
            percentage => 40,
        },
        all    => {
            count      => 3,
            percentage => 50
        }
    },
    {
        name   => 'No',
        recent => {
            count      => 2,
            percentage => 40,
        },
        all    => {
            count      => 2,
            percentage => 33
        }
    },
    {
        name   => 'Abstain',
        recent => {
            count      => 1,
            percentage => 20,
        },
        all    => {
            count      => 1,
            percentage => 17
        }
    },
    {
        name   => 'Total',
        recent => {
            count      => 5,
        },
        all    => {
            count      => 6,
        }
    }
]);

done_testing;
