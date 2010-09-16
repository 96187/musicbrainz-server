package MusicBrainz::Server::Form::Search::Search;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

has_field 'query' => (
    type => 'Text',
    required => 1,
);

has_field 'type' => (
    type => 'Select',
    required => 1
);

has_field 'direct' => (
    type => 'Boolean',
);

has_field 'advanced' => (
    type => 'Boolean',
);

has_field 'limit' => (
    type                => 'Integer',
    input_without_param => 25,
    range_start         => 1,
    range_end           => 100,
);

sub options_type
{
    return [
        'artist'        => 'Artist',
        'release_group' => 'Release Group',
        'release'       => 'Release',
        'recording'     => 'Recording',
        'work'          => 'Work',
        'label'         => 'Label',
        'annotation'    => 'Annotation',
        'cdstub'        => 'CD Stub',
        'editor'        => 'Editor',
        'freedb'        => 'FreeDB',
        'tag'           => 'Tag',
    ];
}

1;
