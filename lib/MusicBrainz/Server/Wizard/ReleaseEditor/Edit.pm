package MusicBrainz::Server::Wizard::ReleaseEditor::Edit;
use Moose;
use namespace::autoclean;

extends 'MusicBrainz::Server::Wizard::ReleaseEditor';

use MusicBrainz::Server::Constants qw(
    $EDIT_RELEASE_EDIT
    $EDIT_RELEASE_ARTIST
);

augment 'create_edits' => sub
{
    my ($self, %opts) = @_;
    my ($data, $create_edit, $editnote, $previewing)
        = @opts{qw( data create_edit edit_note previewing )};

    $self->_load_release;
    $self->c->stash( medium_formats => [ $self->c->model('MediumFormat')->get_all ] );

    # release edit
    # ----------------------------------------

    my @fields = qw( name comment packaging_id status_id script_id language_id
                     country_id barcode date as_auto_editor );
    my %args = map { $_ => $data->{$_} } grep { defined $data->{$_} } @fields;

    $args{'to_edit'} = $self->release;
    $self->c->stash->{changes} = 0;

    # If the release artist will be changed by an EDIT_RELEASE_ARTIST edit, do
    # not change the release artist in the EDIT_RELEASE_EDIT.
    $args{artist_credit} = $data->{artist_credit} unless $data->{change_track_artists};

    $create_edit->($EDIT_RELEASE_EDIT, $editnote, %args);

    # release artist edit
    # ----------------------------------------
    # if the 'change track artists' checkbox is checked, also enter a release
    # artist edit.

    if ($data->{change_track_artists})
    {
        $create_edit->(
            $EDIT_RELEASE_ARTIST, $editnote, release => $self->release,
            update_tracklists => 1, artist_credit => $data->{artist_credit});
    }

    return $self->release;
};

augment 'load' => sub
{
    my ($self) = @_;

    $self->_load_release;
    $self->c->model('Medium')->load_for_releases($self->release);

    $self->c->stash( medium_formats => [ $self->c->model('MediumFormat')->get_all ] );

    return $self->release;
};

# this just loads the remaining bits of a release, not yet loaded by 'load'
sub _load_release
{
    my ($self) = @_;

    $self->c->model('ReleaseLabel')->load($self->release);
    $self->c->model('Label')->load(@{ $self->release->labels });
    $self->c->model('ReleaseGroupType')->load($self->release->release_group);
    $self->c->model('Release')->annotation->load_latest ($self->release);
}

__PACKAGE__->meta->make_immutable;
1;
