package MusicBrainz::Server::Edit::Release::AddReleaseLabel;
use Carp;
use Moose;
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );
use MusicBrainz::Server::Constants qw( $EDIT_RELEASE_ADDRELEASELABEL );
use MusicBrainz::Server::Edit::Types qw( Nullable NullableOnPreview );
use MusicBrainz::Server::Translation qw( l ln );

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::Role::Preview';
with 'MusicBrainz::Server::Edit::Release';

sub edit_name { l('Add release label') }
sub edit_type { $EDIT_RELEASE_ADDRELEASELABEL }
sub alter_edit_pending { { Release => [ shift->release_id ] } }
sub related_entities { { release => [ shift->release_id ] } }

has '+data' => (
    isa => Dict[
        release_id => NullableOnPreview[Int],
        label_id => Nullable[Int],
        catalog_number => Nullable[Str]
    ]
);

sub release_id { shift->data->{release_id} }
sub label_id { shift->data->{label_id} }

after 'initialize' => sub {
    my $self = shift;

    return if $self->preview;

    croak "No release_id specified" unless $self->data->{release_id};
};

sub foreign_keys
{
    my $self = shift;

    return {
        Release => { $self->release_id => [] },
        Label => { $self->label_id => [] },
    };
};

sub build_display_data
{
    my ($self, $loaded) = @_;

    return {
        release => $loaded->{Release}->{ $self->release_id },
        label => $loaded->{Label}->{ $self->label_id },
        catalog_number => $self->data->{catalog_number},
    };
}

sub initialize
{
    my ($self, %opts) = @_;

    $self->data({
        release_id => $opts{release_id},
        label_id => $opts{label_id},
        catalog_number => $opts{catalog_number},
    });
};

sub accept
{
    my $self = shift;
    $self->c->model('ReleaseLabel')->insert($self->data);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
