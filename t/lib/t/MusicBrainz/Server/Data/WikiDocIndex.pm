package t::MusicBrainz::Server::Data::WikiDocIndex;
use Test::Routine;
use Test::More;

use File::Temp;
use MusicBrainz::Server::Test;

use_ok 'MusicBrainz::Server::Data::WikiDocIndex';

has index_filename => (
    is => 'ro',
    default => sub { File::Temp::tmpnam() },
);

sub DEMOLISH {
    unlink shift->index_filename;
}

with 't::Context';

test all => sub {

my $test = shift;

open my $fh, ">", $test->index_filename;
print $fh "Test_Page=123\n";
close $fh;

my $wdi = MusicBrainz::Server::Data::WikiDocIndex->new(
    c => $test->c,
    _index_file => $test->index_filename
);

my $rev = $wdi->get_page_version('Test_Page');
is($rev, 123);

$rev = $wdi->get_page_version('Test_Page_2');
is($rev, undef);

$wdi->set_page_version('Test_Page_2', 100);

$rev = $wdi->get_page_version('Test_Page_2');
is($rev, 100);

my $index = $wdi->get_index;
is_deeply($index, { 'Test_Page' => 123, 'Test_Page_2' => 100 });

$wdi->set_page_version('Test_Page', undef);

$rev = $wdi->get_page_version('Test_Page');
is($rev, undef);

$index = $wdi->get_index;
is_deeply($index, { 'Test_Page_2' => 100 });

};

1;
