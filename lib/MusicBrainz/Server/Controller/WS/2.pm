package MusicBrainz::Server::Controller::WS::2;
use Moose;
use aliased 'MusicBrainz::Server::WebService::WebServiceStash';

BEGIN { extends 'MusicBrainz::Server::Controller'; }

use aliased 'MusicBrainz::Server::Buffer';

use Function::Parameters 'f';
use MusicBrainz::Server::Constants qw(
    $EDIT_RELEASE_EDIT_BARCODES
    $EDIT_RECORDING_ADD_PUIDS
);
use MusicBrainz::Server::WebService::XMLSerializer;
use MusicBrainz::Server::WebService::XMLSearch qw( xml_search );
use MusicBrainz::Server::WebService::Validator;
use MusicBrainz::Server::Data::Utils qw( type_to_model );
use MusicBrainz::Server::Validation qw( is_valid_isrc is_valid_iswc is_valid_discid );
use MusicBrainz::Server::Data::Utils qw( object_to_ids );
use Readonly;
use Data::OptList;
use Scalar::Util qw( looks_like_number );
use TryCatch;
use XML::XPath;

Readonly our $MAX_ITEMS => 25;

# This defines what options are acceptable for WS calls.
# Note that the validator will automatically add inc= arguments to the allowed list
# based on other inc= arguments.  (puids are allowed if recordings are allowed, etc..)
my $ws_defs = Data::OptList::mkopt([
     artist => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     artist => {
                         method   => 'GET',
                         linked   => [ qw(recording release release-group work) ],
                         inc      => [ qw(aliases
                                          _relations tags user-tags ratings user-ratings) ],
                         optional => [ qw(limit offset) ]
     },
     artist => {
                         method   => 'GET',
                         inc      => [ qw(recordings releases release-groups works
                                          aliases various-artists
                                          _relations tags user-tags ratings user-ratings) ],
     },
     label => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     label => {
                         method   => 'GET',
                         linked   => [ qw(release) ],
                         inc      => [ qw(aliases
                                          _relations tags user-tags ratings user-ratings) ],
                         optional => [ qw(limit offset) ],
     },
     label => {
                         method   => 'GET',
                         inc      => [ qw(releases aliases
                                          _relations tags user-tags ratings user-ratings) ],
     },
     recording => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     recording => {
                         method   => 'GET',
                         linked   => [ qw(artist release) ],
                         inc      => [ qw(artist-credits puids isrcs
                                          _relations tags user-tags ratings user-ratings) ],
                         optional => [ qw(limit offset) ],
     },
     recording => {
                         method   => 'GET',
                         inc      => [ qw(artists releases artist-credits puids isrcs aliases
                                          _relations tags user-tags ratings user-ratings) ]
     },
     recording => {
                         method => 'POST'
     },
     release => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     release => {
                         method   => 'GET',
                         linked   => [ qw(artist label recording release-group) ],
                         inc      => [ qw(artist-credits labels discids media _relations) ],
                         optional => [ qw(limit offset) ],
     },
     release => {
                         method   => 'GET',
                         inc      => [ qw(artists labels recordings release-groups aliases
                                          tags user-tags ratings user-ratings
                                          artist-credits discids media _relations) ]
     },
     release => {
                         method   => 'POST',
                         optional => [ qw( client ) ],
     },
     "release-group" => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     "release-group" => {
                         method   => 'GET',
                         linked   => [ qw(artist release) ],
                         inc      => [ qw(artist-credits
                                          _relations tags user-tags ratings user-ratings) ],
                         optional => [ qw(limit offset) ],
     },
     "release-group" => {
                         method   => 'GET',
                         inc      => [ qw(artists releases artist-credits aliases
                                          _relations tags user-tags ratings user-ratings) ]
     },
     work => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     work => {
                         method   => 'GET',
                         linked   => [ qw(artist) ],
                         inc      => [ qw(artists aliases artist-credits
                                          _relations tags user-tags ratings user-ratings) ],
                         optional => [ qw(limit offset) ],
     },
     work => {
                         method   => 'GET',
                         inc      => [ qw(artists aliases artist-credits
                                          _relations tags user-tags ratings user-ratings) ],
     },
     discid => {
                         method   => 'GET',
                         inc      => [ qw(artists labels recordings release-groups artist-credits
                                          aliases puids isrcs _relations) ]
     },
     puid => {
                         method   => 'GET',
                         inc      => [ qw(artists releases puids isrcs artist-credits aliases
                                          _relations tags user-tags ratings user-ratings) ]
     },
     isrc => {
                         method   => 'GET',
                         inc      => [ qw(artists releases puids isrcs artist-credits aliases
                                          _relations tags user-tags ratings user-ratings) ]
     },
     iswc => {
                         method   => 'GET',
                         inc      => [ qw(artists aliases artist-credits
                                          _relations tags user-tags ratings user-ratings) ],
     },
     tag => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     tag => {
                         method   => 'GET',
                         required => [ qw(id entity) ],
     },
     tag => {
                         method   => 'POST',
                         optional => [ qw(client) ],
     },
     rating => {
                         method   => 'GET',
                         required => [ qw(id entity) ],
     },
     rating => {
                         method   => 'POST',
                         optional => [ qw(client) ],
     },
     cdstub => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
     freedb => {
                         method   => 'GET',
                         required => [ qw(query) ],
                         optional => [ qw(limit offset) ],
     },
]);

with 'MusicBrainz::Server::WebService::Validator' =>
{
     defs => $ws_defs,
};

Readonly my %serializers => (
    xml => 'MusicBrainz::Server::WebService::XMLSerializer',
);

sub bad_req : Private
{
    my ($self, $c) = @_;
    $c->res->status(400);
    $c->res->content_type("application/xml; charset=UTF-8");
    $c->res->body($c->stash->{serializer}->output_error($c->stash->{error}));
}

sub success : Private
{
    my ($self, $c) = @_;
    $c->res->content_type("application/xml; charset=UTF-8");
    $c->res->body($c->stash->{serializer}->output_success);
}

sub unauthorized : Private
{
    my ($self, $c) = @_;
    $c->res->status(401);
    $c->res->content_type("text/plain; charset=utf-8");
    $c->res->body($c->stash->{serializer}->output_error("Your credentials ".
        "could not be verified.\nEither you supplied the wrong credentials ".
        "(e.g., bad password), or your client doesn't understand how to ".
        "supply the credentials required."));
}

sub not_found : Private
{
    my ($self, $c) = @_;
    $c->res->status(404);
    $c->res->content_type("text/plain; charset=utf-8");
    $c->res->body($c->stash->{serializer}->output_error("Not Found"));
}

sub begin : Private
{
}

sub end : Private
{
}

sub root : Chained('/') PathPart("ws/2") CaptureArgs(0)
{
    my ($self, $c) = @_;

    $self->validate($c, \%serializers) or $c->detach('bad_req');

    $c->authenticate({}, 'musicbrainz.org') if ($c->stash->{authorization_required});
}

sub _error
{
    my ($c, $error) = @_;

    $c->stash->{error} = $error;
    $c->detach('bad_req');
}

sub _search
{
    my ($self, $c, $entity) = @_;

    my $result = xml_search($entity, $c->stash->{args});
    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    if (exists $result->{xml})
    {
        $c->res->body($result->{xml});
    }
    else
    {
        $c->res->status($result->{code});
        $c->res->body($c->stash->{serializer}->output_error($result->{error}));
    }
}

sub _tags_and_ratings
{
    my ($self, $c, $modelname, $entities, $stash) = @_;

    my %map = object_to_ids (@$entities);
    my $model = $c->model($modelname);

    if ($c->stash->{inc}->tags)
    {
        my @tags = $model->tags->find_tags_for_entities (map { $_->id } @$entities);

        for (@tags)
        {
            my $opts = $stash->store ($map{$_->entity_id}->[0]);

            $opts->{tags} = [] unless $opts->{tags};
            push @{ $opts->{tags} }, $_;
        }
    }

    if ($c->stash->{inc}->user_tags)
    {
        my @tags = $model->tags->find_user_tags_for_entities (
            $c->user->id, map { $_->id } @$entities);

        for (@tags)
        {
            my $opts = $stash->store ($map{$_->entity_id}->[0]);

            $opts->{user_tags} = [] unless $opts->{user_tags};
            push @{ $opts->{user_tags} }, $_;
        }
    }

    if ($c->stash->{inc}->ratings)
    {
        $model->load_meta(@$entities);

        for (@$entities)
        {
            if ($_->rating_count)
            {
                $stash->store ($_)->{ratings} = {
                    rating => $_->rating * 5 / 100,
                    count => $_->rating_count,
                };
            }
        }
    }

    if ($c->stash->{inc}->user_ratings)
    {
        $model->rating->load_user_ratings($c->user->id, @$entities);
        for (@$entities)
        {
            $stash->store ($_)->{user_ratings} = $_->user_rating * 5 / 100
                if $_->user_rating;
        }
    }
}

sub _limit_and_offset
{
    my ($self, $c) = @_;

    my $args = $c->stash->{args};
    my $limit = $args->{limit} ? $args->{limit} : 25;
    my $offset = $args->{offset} ? $args->{offset} : 0;

    return ($limit > 100 ? 100 : $limit, $offset);
}

sub make_list
{
    my ($self, $results, $total, $offset) = @_;

    return {
        items => $results,
        total => defined $total ? $total : scalar @$results,
        offset => defined $offset ? $offset : 0
    };
}

sub linked_artists
{
    my ($self, $c, $stash, $artists) = @_;

    $self->_tags_and_ratings($c, 'Artist', $artists, $stash);

    if ($c->stash->{inc}->aliases)
    {
        my @aliases = @{ $c->model('Artist')->alias->find_by_entity_id(map { $_->id } @$artists) };

        my %alias_per_artist;
        foreach (@aliases)
        {
            $alias_per_artist{$_->artist_id} = [] unless $alias_per_artist{$_->artist_id};
            push @{ $alias_per_artist{$_->artist_id} }, $_;
        }

        foreach (@$artists)
        {
            $stash->store ($_)->{aliases} = $alias_per_artist{$_->id};
        }
    }
}

sub linked_labels
{
    my ($self, $c, $stash, $labels) = @_;

    $self->_tags_and_ratings($c, 'Label', $labels, $stash);

    if ($c->stash->{inc}->aliases)
    {
        my @aliases = @{ $c->model('Label')->alias->find_by_entity_id(map { $_->id } @$labels) };

        my %alias_per_label;
        foreach (@aliases)
        {
            $alias_per_label{$_->label_id} = [] unless $alias_per_label{$_->label_id};
            push @{ $alias_per_label{$_->label_id} }, $_;
        }

        foreach (@$labels)
        {
            $stash->store ($_)->{aliases} = $alias_per_label{$_->id};
        }
    }
}

sub linked_recordings
{
    my ($self, $c, $stash, $recordings) = @_;

    if ($c->stash->{inc}->isrcs)
    {
        my @isrcs = $c->model('ISRC')->find_by_recording(map { $_->id } @$recordings);

        my %isrc_per_recording;
        for (@isrcs)
        {
            $isrc_per_recording{$_->recording_id} = [] unless $isrc_per_recording{$_->recording_id};
            push @{ $isrc_per_recording{$_->recording_id} }, $_;
        };

        for (@$recordings)
        {
            $stash->store ($_)->{isrcs} = $isrc_per_recording{$_->id};
        }
    }

    if ($c->stash->{inc}->puids)
    {
        my @puids = $c->model('RecordingPUID')->find_by_recording(map { $_->id } @$recordings);

        my %puid_per_recording;
        for (@puids)
        {
            $puid_per_recording{$_->recording_id} = [] unless $puid_per_recording{$_->recording_id};
            push @{ $puid_per_recording{$_->recording_id} }, $_;
        };

        for (@$recordings)
        {
            $stash->store ($_)->{puids} = $puid_per_recording{$_->id};
        }
    }

    if ($c->stash->{inc}->artist_credits)
    {
        $c->model('ArtistCredit')->load(@$recordings);
    }

    $self->_tags_and_ratings($c, 'Recording', $recordings, $stash);
}

sub linked_releases
{
    my ($self, $c, $stash, $releases) = @_;

    $c->model('ReleaseStatus')->load(@$releases);
    $c->model('ReleasePackaging')->load(@$releases);

    $c->model('Language')->load(@$releases);
    $c->model('Script')->load(@$releases);
    $c->model('Country')->load(@$releases);

    my @mediums;
    if ($c->stash->{inc}->media)
    {
        @mediums = map { $_->all_mediums } @$releases;

        unless (@mediums)
        {
            $c->model('Medium')->load_for_releases(@$releases);
            @mediums = map { $_->all_mediums } @$releases;
        }

        $c->model('MediumFormat')->load(@mediums);
    }

    if ($c->stash->{inc}->discids)
    {
        my @medium_cdtocs = $c->model('MediumCDTOC')->load_for_mediums(@mediums);
        $c->model('CDTOC')->load(@medium_cdtocs);
    }

    if ($c->stash->{inc}->artist_credits)
    {
        $c->model('ArtistCredit')->load(@$releases);
    }
}

sub linked_release_groups
{
    my ($self, $c, $stash, $release_groups) = @_;

    $c->model('ReleaseGroupType')->load(@$release_groups);

    if ($c->stash->{inc}->artist_credits)
    {
        $c->model('ArtistCredit')->load(@$release_groups);
    }

    $self->_tags_and_ratings($c, 'ReleaseGroup', $release_groups, $stash);
}

sub linked_works
{
    my ($self, $c, $stash, $works) = @_;

    if ($c->stash->{inc}->aliases)
    {
        my @aliases = @{ $c->model('Work')->alias->find_by_entity_id(map { $_->id } @$works) };

        my %alias_per_work;
        foreach (@aliases)
        {
            $alias_per_work{$_->work_id} = [] unless $alias_per_work{$_->work_id};
            push @{ $alias_per_work{$_->work_id} }, $_;
        }

        foreach (@$works)
        {
            $stash->store ($_)->{aliases} = $alias_per_work{$_->id};
        }
    }

    if ($c->stash->{inc}->artist_credits)
    {
        $c->model('ArtistCredit')->load(@$works);
    }

    $self->_tags_and_ratings($c, 'Work', $works, $stash);
}


sub artist : Chained('root') PathPart('artist') Args(1)
{
    my ($self, $c, $gid) = @_;

    if (!$gid || !MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $artist = $c->model('Artist')->get_by_gid($gid);
    unless ($artist) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;
    my $opts = $stash->store ($artist);

    $self->artist_toplevel ($c, $stash, $artist);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('artist', $artist, $c->stash->{inc}, $stash));
}

sub artist_toplevel
{
    my ($self, $c, $stash, $artist) = @_;

    my $opts = $stash->store ($artist);

    $self->linked_artists ($c, $stash, [ $artist ]);

    $c->model('ArtistType')->load($artist);
    $c->model('Gender')->load($artist);
    $c->model('Country')->load($artist);

    if ($c->stash->{inc}->recordings)
    {
        my @results = $c->model('Recording')->find_by_artist($artist->id, $MAX_ITEMS);
        $opts->{recordings} = $self->make_list (@results);

        $self->linked_recordings ($c, $stash, $opts->{recordings}->{items});
    }

    if ($c->stash->{inc}->releases)
    {
        my @results;
        if ($c->stash->{inc}->various_artists)
        {
            @results = $c->model('Release')->find_for_various_artists(
                $artist->id, $MAX_ITEMS, 0, $c->stash->{status}, $c->stash->{type});
        }
        else
        {
            @results = $c->model('Release')->find_by_artist(
                $artist->id, $MAX_ITEMS, 0, $c->stash->{status}, $c->stash->{type});
        }

        $opts->{releases} = $self->make_list (@results);

        $self->linked_releases ($c, $stash, $opts->{releases}->{items});
    }

    if ($c->stash->{inc}->release_groups)
    {
        my @results = $c->model('ReleaseGroup')->find_by_artist(
            $artist->id, $MAX_ITEMS, 0, $c->stash->{type});
        $opts->{release_groups} = $self->make_list (@results);

        $self->linked_release_groups ($c, $stash, $opts->{release_groups}->{items});
    }

    if ($c->stash->{inc}->works)
    {
        my @results = $c->model('Work')->find_by_artist($artist->id, $MAX_ITEMS);
        $opts->{works} = $self->make_list (@results);

        $self->linked_works ($c, $stash, $opts->{works}->{items});
    }

    if ($c->stash->{inc}->has_rels)
    {
        my $types = $c->stash->{inc}->get_rel_types();
        my @rels = $c->model('Relationship')->load_subset($types, $artist);
    }
}

sub artist_browse : Private
{
    my ($self, $c) = @_;

    my ($resource, $id) = @{ $c->stash->{linked} };
    my ($limit, $offset) = $self->_limit_and_offset ($c);

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $artists;
    my $total;
    if ($resource eq 'recording')
    {
        my $recording = $c->model('Recording')->get_by_gid($id);
        $c->detach('not_found') unless ($recording);

        my @tmp = $c->model('Artist')->find_by_recording ($recording->id, $limit, $offset);
        $artists = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'release')
    {
        my $release = $c->model('Release')->get_by_gid($id);
        $c->detach('not_found') unless ($release);

        my @tmp = $c->model('Artist')->find_by_release ($release->id, $limit, $offset);
        $artists = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'release-group')
    {
        my $rg = $c->model('ReleaseGroup')->get_by_gid($id);
        $c->detach('not_found') unless ($rg);

        my @tmp = $c->model('Artist')->find_by_release_group ($rg->id, $limit, $offset);
        $artists = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'work')
    {
        my $work = $c->model('Work')->get_by_gid($id);
        $c->detach('not_found') unless ($work);

        my @tmp = $c->model('Artist')->find_by_work ($work->id, $limit, $offset);
        $artists = $self->make_list (@tmp, $offset);
    }

    my $stash = WebServiceStash->new;

    for (@{ $artists->{items} })
    {
        $self->artist_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('artist-list', $artists, $c->stash->{inc}, $stash));
}

sub artist_search : Chained('root') PathPart('artist') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('artist_browse') if ($c->stash->{linked});
    $self->_search ($c, 'artist');
}

sub release_group_toplevel
{
    my ($self, $c, $stash, $rg) = @_;

    my $opts = $stash->store ($rg);

    $self->linked_release_groups ($c, $stash, [ $rg ]);

    if ($c->stash->{inc}->releases)
    {
        my @results = $c->model('Release')->find_by_release_group(
            $rg->id, $MAX_ITEMS, 0, $c->stash->{status});
        $opts->{releases} = $self->make_list (@results);

        $self->linked_releases ($c, $stash, $opts->{releases}->{items});
    }

    if ($c->stash->{inc}->artists)
    {
        $c->model('ArtistCredit')->load($rg);

        my @artists = map { $c->model('Artist')->load ($_); $_->artist } @{ $rg->artist_credit->names };

        $self->linked_artists ($c, $stash, \@artists);
    }

    if ($c->stash->{inc}->has_rels)
    {
        my $types = $c->stash->{inc}->get_rel_types();
        my @rels = $c->model('Relationship')->load_subset($types, $rg);
    }
}

sub release_group : Chained('root') PathPart('release-group') Args(1)
{
    my ($self, $c, $gid) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $rg = $c->model('ReleaseGroup')->get_by_gid($gid);
    unless ($rg) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;

    $self->release_group_toplevel ($c, $stash, $rg);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('release-group', $rg, $c->stash->{inc}, $stash));
}

sub release_group_browse : Private
{
    my ($self, $c) = @_;

    my ($resource, $id) = @{ $c->stash->{linked} };
    my ($limit, $offset) = $self->_limit_and_offset ($c);

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $rgs;
    my $total;
    if ($resource eq 'artist')
    {
        my $artist = $c->model('Artist')->get_by_gid($id);
        $c->detach('not_found') unless ($artist);

        my @tmp = $c->model('ReleaseGroup')->find_by_artist (
            $artist->id, $limit, $offset, $c->stash->{type});
        $rgs = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'release')
    {
        my $release = $c->model('Release')->get_by_gid($id);
        $c->detach('not_found') unless ($release);

        my @tmp = $c->model('ReleaseGroup')->find_by_release ($release->id, $limit, $offset);
        $rgs = $self->make_list (@tmp, $offset);
    }

    my $stash = WebServiceStash->new;

    for (@{ $rgs->{items} })
    {
        $self->release_group_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('release-group-list', $rgs, $c->stash->{inc}, $stash));
}

sub release_group_search : Chained('root') PathPart('release-group') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('release_group_browse') if ($c->stash->{linked});

    $self->_search ($c, 'release-group');
}

sub release_toplevel
{
    my ($self, $c, $stash, $release) = @_;

    $c->model('Release')->load_meta($release);
    $self->linked_releases ($c, $stash, [ $release ]);

    if ($c->stash->{inc}->artists)
    {
        $c->model('ArtistCredit')->load($release);

        my @artists = map { $c->model('Artist')->load ($_); $_->artist } @{ $release->artist_credit->names };

        $self->linked_artists ($c, $stash, \@artists);
    }

    if ($c->stash->{inc}->labels)
    {
        $c->model('ReleaseLabel')->load($release);
        $c->model('Label')->load($release->all_labels);

        my @labels = map { $_->label } $release->all_labels;

        $self->linked_labels ($c, $stash, \@labels);
    }

    if ($c->stash->{inc}->release_groups)
    {
         $c->model('ReleaseGroup')->load($release);

         my $rg = $release->release_group;

         $self->linked_release_groups ($c, $stash, [ $rg ]);
    }

    if ($c->stash->{inc}->recordings)
    {
        my @mediums;
        if (!$c->stash->{inc}->media)
        {
            $c->model('Medium')->load_for_releases($release);
        }

        @mediums = $release->all_mediums;

        my @tracklists = grep { defined } map { $_->tracklist } @mediums;
        $c->model('Track')->load_for_tracklists(@tracklists);

        my @recordings = $c->model('Recording')->load(map { $_->all_tracks } @tracklists);
        $c->model('Recording')->load_meta(@recordings);

        $self->linked_recordings ($c, $stash, \@recordings);
    }

    if ($c->stash->{inc}->has_rels)
    {
        my $types = $c->stash->{inc}->get_rel_types();
        my @rels = $c->model('Relationship')->load_subset($types, $release);
    }
}

sub release: Chained('root') PathPart('release') Args(1)
{
    my ($self, $c, $gid) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $release = $c->model('Release')->get_by_gid($gid);
    unless ($release) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;

    $self->release_toplevel ($c, $stash, $release);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('release', $release, $c->stash->{inc}, $stash));
}

sub release_browse : Private
{
    my ($self, $c) = @_;

    my ($resource, $id) = @{ $c->stash->{linked} };
    my ($limit, $offset) = $self->_limit_and_offset ($c);

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $releases;
    my $total;
    if ($resource eq 'artist')
    {
        my $artist = $c->model('Artist')->get_by_gid($id);
        $c->detach('not_found') unless ($artist);

        my @tmp = $c->model('Release')->find_by_artist (
            $artist->id, $limit, $offset, $c->stash->{status}, $c->stash->{type});
        $releases = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'label')
    {
        my $label = $c->model('Label')->get_by_gid($id);
        $c->detach('not_found') unless ($label);

        my @tmp = $c->model('Release')->find_by_label (
            $label->id, $limit, $offset, $c->stash->{status}, $c->stash->{type});
        $releases = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'release-group')
    {
        my $rg = $c->model('ReleaseGroup')->get_by_gid($id);
        $c->detach('not_found') unless ($rg);

        my @tmp = $c->model('Release')->find_by_release_group (
            $rg->id, $limit, $offset, $c->stash->{status});
        $releases = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'recording')
    {
        my $recording = $c->model('Recording')->get_by_gid($id);
        $c->detach('not_found') unless ($recording);

        my @tmp = $c->model('Release')->find_by_recording (
            $recording->id, $limit, $offset, $c->stash->{status}, $c->stash->{type});
        $releases = $self->make_list (@tmp, $offset);
    }

    my $stash = WebServiceStash->new;

    for (@{ $releases->{items} })
    {
        $self->release_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('release-list', $releases, $c->stash->{inc}, $stash));
}

sub release_search : Chained('root') PathPart('release') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('release_submit') if $c->request->method eq 'POST';
    $c->detach('release_browse') if ($c->stash->{linked});
    $self->_search ($c, 'release');
}

sub release_submit : Private
{
    my ($self, $c) = @_;

    my $xp = XML::XPath->new( xml => $c->request->body );

    my @submit;
    for my $node ($xp->find('/metadata/release-list/release')->get_nodelist) {
        my $id = $node->getAttribute('id') or
            _error ($c, "All releases must have an MBID present");

        _error($c, "$id is not a valid MBID")
            unless MusicBrainz::Server::Validation::IsGUID($id);

        my $barcode = $node->find('barcode')->string_value;

        _error($c, "$barcode is not a valid barcode")
            unless MusicBrainz::Server::Validation::IsValidEAN($barcode);

        push @submit, { release => $id, barcode => $barcode };
    }

    my %releases = %{ $c->model('Release')->get_by_gids(map { $_->{release} } @submit) };
    my %gid_map = map { $_->gid => $_->id } values %releases;

    for my $submission (@submit) {
        my $gid = $submission->{release};
        _error($c, "$gid does not match any existing releases")
            unless exists $gid_map{$gid};
    }

    try {
        $c->model('Edit')->create(
            editor_id => $c->user->id,
            privileges => $c->user->privileges,
            edit_type => $EDIT_RELEASE_EDIT_BARCODES,
            submissions => [ map +{
                release_id => $gid_map{ $_->{release} },
                barcode => $_->{barcode}
            }, @submit ]
        );
    }
    catch ($e) {
        _error($c, "This edit could not be successfully created: $e");
    }

    $c->detach('success');
}

sub recording_toplevel
{
    my ($self, $c, $stash, $recording) = @_;

    my $opts = $stash->store ($recording);

    $self->linked_recordings ($c, $stash, [ $recording ]);

    if ($c->stash->{inc}->releases)
    {
        my @results;
        if ($c->stash->{inc}->media)
        {
            @results = $c->model('Release')->load_with_tracklist_for_recording(
                $recording->id, $MAX_ITEMS, 0, $c->stash->{status}, $c->stash->{type});
        }
        else
        {
            @results = $c->model('Release')->find_by_recording(
                $recording->id, $MAX_ITEMS, 0, $c->stash->{status}, $c->stash->{type});
        }

        $self->linked_releases ($c, $stash, $results[0]);

        $opts->{releases} = $self->make_list (@results);
    }

    if ($c->stash->{inc}->artists)
    {
        $c->model('ArtistCredit')->load($recording);

        my @artists = map { $c->model('Artist')->load ($_); $_->artist } @{ $recording->artist_credit->names };

        $self->linked_artists ($c, $opts, \@artists);
    }

    if ($c->stash->{inc}->has_rels)
    {
        my $types = $c->stash->{inc}->get_rel_types();
        my @rels = $c->model('Relationship')->load_subset($types, $recording);
    }
}

sub recording: Chained('root') PathPart('recording') Args(1)
{
    my ($self, $c, $gid) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $recording = $c->model('Recording')->get_by_gid($gid);
    unless ($recording) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;

    $self->recording_toplevel ($c, $stash, $recording);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('recording', $recording, $c->stash->{inc}, $stash));
}

sub recording_browse : Private
{
    my ($self, $c) = @_;

    my ($resource, $id) = @{ $c->stash->{linked} };
    my ($limit, $offset) = $self->_limit_and_offset ($c);

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $recordings;
    my $total;
    if ($resource eq 'artist')
    {
        my $artist = $c->model('Artist')->get_by_gid($id);
        $c->detach('not_found') unless ($artist);

        my @tmp = $c->model('Recording')->find_by_artist ($artist->id, $limit, $offset);
        $recordings = $self->make_list (@tmp, $offset);
    }
    elsif ($resource eq 'release')
    {
        my $release = $c->model('Release')->get_by_gid($id);
        $c->detach('not_found') unless ($release);

        my @tmp = $c->model('Recording')->find_by_release ($release->id, $limit, $offset);
        $recordings = $self->make_list (@tmp, $offset);
    }

    my $stash = WebServiceStash->new;

    for (@{ $recordings->{items} })
    {
        $self->recording_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('recording-list', $recordings, $c->stash->{inc}, $stash));
}

sub recording_search : Chained('root') PathPart('recording') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('recording_submit') if $c->req->method eq 'POST';
    $c->detach('recording_browse') if ($c->stash->{linked});

    my $result = xml_search('recording', $c->stash->{args});
    $self->_search ($c, 'recording');
}

sub recording_submit : Private
{
    my ($self, $c) = @_;

    my $client = $c->req->query_params->{client}
        or _error($c, 'You must provide information about your client, by the client query parameter');

    my $xp = XML::XPath->new( xml => $c->request->body );

    my %submit;
    for my $node ($xp->find('/metadata/recording-list/recording')->get_nodelist)
    {
        my $id = $node->getAttribute('id') or
            _error ($c, "All releases must have an MBID present");

        _error($c, "$id is not a valid MBID")
            unless MusicBrainz::Server::Validation::IsGUID($id);

        my @puids = $node->find('puid-list/puid')->get_nodelist;
        for my $puid_node (@puids) {
            my $puid = $puid_node->getAttribute('id');
            _error($c, "$puid is not a valid PUID")
                unless MusicBrainz::Server::Validation::IsGUID($puid);

            $submit{ $id } ||= [];
            push @{ $submit{$id} }, $puid;
        }
    }

    my %recordings_by_id = %{ $c->model('Recording')->get_by_gids(keys %submit) };
    my %recordings_by_gid = map { $_->gid => $_->id } values %recordings_by_id;

    my @submissions;
    for my $recording_gid (keys %submit) {
        _error($c, "$recording_gid does not match any known recordings")
            unless exists $recordings_by_gid{$recording_gid};
    }

    my $buffer = Buffer->new(
        limit => 100,
        on_full => f($contents) {
            my $new_rows = $c->model('RecordingPUID')->filter_additions(@$contents);
            return unless @$new_rows;

            $c->model('Edit')->create(
                edit_type      => $EDIT_RECORDING_ADD_PUIDS,
                editor_id      => $c->user->id,
                client_version => $client,
                puids          => $new_rows
            );
        }
    );

    $buffer->flush_on_complete(sub {
        for my $recording_gid (keys %submit) {
            $buffer->add_items(map +{
                recording_id => $recordings_by_gid{$recording_gid},
                puid         => $_
            }, @{ $submit{$recording_gid} });
        }
    });

    $c->detach('success');
}

sub label_toplevel
{
    my ($self, $c, $stash, $label) = @_;

    my $opts = $stash->store ($label);

    $self->linked_labels ($c, $stash, [ $label ]);

    $c->model('LabelType')->load($label);
    $c->model('Country')->load($label);

    if ($c->stash->{inc}->aliases)
    {
        my $aliases = $c->model('Label')->alias->find_by_entity_id($label->id);
        $opts->{aliases} = $aliases;
    }

    if ($c->stash->{inc}->releases)
    {
        my @results = $c->model('Release')->find_by_label(
            $label->id, $MAX_ITEMS, 0, $c->stash->{status}, $c->stash->{type});
        $opts->{releases} = $self->make_list (@results);

        $self->linked_releases ($c, $stash, $opts->{releases}->{items});
    }

    if ($c->stash->{inc}->has_rels)
    {
        my $types = $c->stash->{inc}->get_rel_types();
        my @rels = $c->model('Relationship')->load_subset($types, $label);
    }
}

sub label : Chained('root') PathPart('label') Args(1)
{
    my ($self, $c, $gid) = @_;

    if (!$gid || !MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $label = $c->model('Label')->get_by_gid($gid);
    unless ($label) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;
    my $opts = $stash->store ($label);

    $self->label_toplevel ($c, $stash, $label);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('label', $label, $c->stash->{inc}, $stash));
}

sub label_browse : Private
{
    my ($self, $c) = @_;

    my ($resource, $id) = @{ $c->stash->{linked} };
    my ($limit, $offset) = $self->_limit_and_offset ($c);

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $labels;
    my $total;
    if ($resource eq 'release')
    {
        my $release = $c->model('Release')->get_by_gid($id);
        $c->detach('not_found') unless ($release);

        my @tmp = $c->model('Label')->find_by_release ($release->id, $limit, $offset);
        $labels = $self->make_list (@tmp, $offset);
    }

    my $stash = WebServiceStash->new;

    for (@{ $labels->{items} })
    {
        $self->label_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('label-list', $labels, $c->stash->{inc}, $stash));
}

sub label_search : Chained('root') PathPart('label') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('label_browse') if ($c->stash->{linked});
    $self->_search ($c, 'label');
}


sub work_toplevel
{
    my ($self, $c, $stash, $work) = @_;

    my $opts = $stash->store ($work);

    if ($c->stash->{inc}->artists)
    {
        $c->model('ArtistCredit')->load($work);

        my @artists = map { $c->model('Artist')->load ($_); $_->artist } @{ $work->artist_credit->names };

        $self->linked_artists ($c, $stash, \@artists);
    }

    if ($c->stash->{inc}->has_rels)
    {
        my $types = $c->stash->{inc}->get_rel_types();
        my @rels = $c->model('Relationship')->load_subset($types, $work);
    }

    $c->model('WorkType')->load($work);
}

sub work : Chained('root') PathPart('work') Args(1)
{
    my ($self, $c, $gid) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $work = $c->model('Work')->get_by_gid($gid);
    unless ($work) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;
    my $opts = $stash->store ($work);

    $self->work_toplevel ($c, $stash, $work);

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('work', $work, $c->stash->{inc}, $stash));
}

sub work_browse : Private
{
    my ($self, $c) = @_;

    my ($resource, $id) = @{ $c->stash->{linked} };
    my ($limit, $offset) = $self->_limit_and_offset ($c);

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    my $works;
    my $total;
    if ($resource eq 'artist')
    {
        my $artist = $c->model('Artist')->get_by_gid($id);
        $c->detach('not_found') unless ($artist);

        my @tmp = $c->model('Work')->find_by_artist ($artist->id, $limit, $offset);
        $works = $self->make_list (@tmp, $offset);
    }

    my $stash = WebServiceStash->new;

    for (@{ $works->{items} })
    {
        $self->work_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('work-list', $works, $c->stash->{inc}, $stash));
}

sub work_search : Chained('root') PathPart('work') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('work_browse') if ($c->stash->{linked});
    $self->_search ($c, 'work');
}

sub puid : Chained('root') PathPart('puid') Args(1)
{
    my ($self, $c, $id) = @_;

    if (!MusicBrainz::Server::Validation::IsGUID($id))
    {
        $c->stash->{error} = "Invalid puid.";
        $c->detach('bad_req');
    }

    my $stash = WebServiceStash->new;
    my $puid = $c->model('PUID')->get_by_puid($id);
    unless ($puid) {
        $c->detach('not_found');
    }

    my $opts = $stash->store ($puid);

    my @recording_puids = $c->model('RecordingPUID')->find_by_puid($puid->id);
    my @recordings = map { $_->recording } @recording_puids;
    $opts->{recordings} = $self->make_list (\@recordings);

    for (@recordings)
    {
        $self->recording_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('puid', $puid, $c->stash->{inc}, $stash));
}

sub isrc : Chained('root') PathPart('isrc') Args(1)
{
    my ($self, $c, $isrc) = @_;

    if (!is_valid_isrc($isrc))
    {
        $c->stash->{error} = "Invalid isrc.";
        $c->detach('bad_req');
    }

    my @isrcs = $c->model('ISRC')->find_by_isrc($isrc);
    unless (@isrcs) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;

    my @recordings = $c->model('Recording')->load(@isrcs);
    my $recordings = $self->make_list (\@recordings);

    for (@recordings)
    {
        $self->recording_toplevel ($c, $stash, $_);
    }

    for (@isrcs)
    {
        $stash->store ($_)->{recordings} = $recordings;
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('isrc', \@isrcs, $c->stash->{inc}, $stash));
}

sub discid : Chained('root') PathPart('discid') Args(1)
{
    my ($self, $c, $id) = @_;

    if (!is_valid_discid($id))
    {
        $c->stash->{error} = "Invalid discid.";
        $c->detach('bad_req');
    }

    my $cdtoc = $c->model('CDTOC')->get_by_discid($id);
    unless ($cdtoc) {
        $c->detach('not_found');
    }

    my @mediumcdtocs = $c->model('MediumCDTOC')->find_by_cdtoc($cdtoc->id);
    $c->model('Medium')->load(@mediumcdtocs);

    my $stash = WebServiceStash->new;
    my $opts = $stash->store ($cdtoc);

    my @releases = $c->model('Release')->find_by_medium(
        [ map { $_->medium_id } @mediumcdtocs ], $c->stash->{status}, $c->stash->{type});
    $opts->{releases} = $self->make_list (\@releases);

    for (@releases)
    {
        $self->release_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('discid', $cdtoc, $c->stash->{inc}, $stash));
}

sub iswc : Chained('root') PathPart('iswc') Args(1)
{
    my ($self, $c, $iswc) = @_;

    if (!is_valid_iswc($iswc))
    {
        $c->stash->{error} = "Invalid iswc.";
        $c->detach('bad_req');
    }

    my @works = $c->model('Work')->find_by_iswc($iswc);
    unless (@works) {
        $c->detach('not_found');
    }

    my $stash = WebServiceStash->new;
    my $opts = $stash->store ($iswc);
    $opts->{works} = $self->make_list (\@works);

    for (@works)
    {
        $self->work_toplevel ($c, $stash, $_);
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('isrc', \@works, $c->stash->{inc}, $stash));
}

sub tag_lookup : Private
{
    my ($self, $c) = @_;

    my ($entity, $model) = $self->_validate_entity ($c);

    my @tags = $c->model($model)->tags->find_user_tags($c->user->id, $entity->id);

    my $stash = WebServiceStash->new;
    $stash->store ($entity)->{user_tags} = \@tags;

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('tag-list', $entity, $c->stash->{inc}, $stash));
}


sub tag_search : Chained('root') PathPart('tag') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('tag_submit') if $c->request->method eq 'POST';
    $c->detach('tag_lookup') if exists $c->stash->{args}->{id};

    $self->_search ($c, 'tag');
}

sub rating_submit : Private
{
    my ($self, $c) = @_;

    $self->_validate_post ($c);

    my $xp = XML::XPath->new( xml => $c->request->body );

    my @submit;
    for my $node ($xp->find('/metadata/*/*')->get_nodelist)
    {
        my $type = $node->getName;
        $type =~ s/-/_/;

        my $model = type_to_model ($type);
        _error ($c, "Unrecognized entity $type.") unless $model;

        my $gid = $node->getAttribute ('id');
        _error ($c, "Cannot parse MBID: $gid.")
            unless MusicBrainz::Server::Validation::IsGUID($gid);

        my $entity = $c->model($model)->get_by_gid($gid);
        _error ($c, "Cannot find $type $gid.") unless $entity;

        my $rating = $node->find ('user-rating')->string_value;
        _error ($c, "Rating should be an integer between 0 and 100")
            unless looks_like_number ($rating) && $rating >= 0 && $rating <= 100;

        # postpone any updates until we've made some effort to parse the whole
        # body and report possible errors in it.
        push @submit, { model => $model,  entity => $entity,  rating => $rating }
    }

    for (@submit)
    {
        $c->model($_->{model})->rating->update(
            $c->user->id, $_->{entity}->id, $_->{rating});
    }

    $c->detach('success');
}

sub rating_lookup : Chained('root') PathPart('rating') Args(0)
{
    my ($self, $c) = @_;

    $c->detach('rating_submit') if $c->request->method eq 'POST';

    my ($entity, $model) = $self->_validate_entity ($c);

    $c->model($model)->rating->load_user_ratings ($c->user->id, $entity);

    my $stash = WebServiceStash->new;
    $stash->store ($entity)->{user_ratings} = $entity->user_rating;

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('rating', $entity, $c->stash->{inc}, $stash));
}


sub freedb_search : Chained('root') PathPart('freedb') Args(0)
{
    my ($self, $c) = @_;

    $self->_search ($c, 'freedb');
}

sub cdstub_search : Chained('root') PathPart('cdstub') Args(0)
{
    my ($self, $c) = @_;

    $self->_search ($c, 'cdstub');
}

sub _validate_post
{
    my ($self, $c) = @_;

    my $h = $c->request->headers;

    if (!$h->content_type_charset && $h->content_type_charset ne 'UTF-8')
    {
        _error ($c, "Unsupported charset, please use UTF-8.")
    }

    if ($h->content_type ne 'application/xml')
    {
        _error ($c, "Unsupported content-type, please use application/xml");
    }

    _error ($c, "Please specify the name and version number of your client application.")
        unless $c->req->params->{client};
}

sub _validate_entity
{
    my ($self, $c) = @_;

    my $gid = $c->stash->{args}->{id};
    my $entity = $c->stash->{args}->{entity};
    $entity =~ s/-/_/;

    my $model = type_to_model ($entity);

    if (!$gid || !MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    if (!$model)
    {
        $c->stash->{error} = "Invalid entity type.";
        $c->detach('bad_req');
    }

    $entity = $c->model($model)->get_by_gid($gid);
    $c->detach('not_found') unless ($entity);

    return ($entity, $model);
}

sub tag_submit : Private
{
    my ($self, $c) = @_;

    $self->_validate_post ($c);

    use XML::XPath;
    my $xp = XML::XPath->new( xml => $c->request->body );

    my @submit;
    for my $node ($xp->find('/metadata/*/*')->get_nodelist)
    {
        my $type = $node->getName;
        $type =~ s/-/_/;

        my $model = type_to_model ($type);
        _error ($c, "Unrecognized entity $type.") unless $model;

        my $gid = $node->getAttribute ('id');
        _error ($c, "Cannot parse MBID: $gid.")
            unless MusicBrainz::Server::Validation::IsGUID($gid);

        my $entity = $c->model($model)->get_by_gid($gid);
        _error ($c, "Cannot find $type $gid.") unless $entity;

        # postpone any updates until we've made some effort to parse the whole
        # body and report possible errors in it.
        push @submit, { model => $model,  entity => $entity, tags => [ map {
                $_->string_value
            } $node->find ('user-tag-list/user-tag/name')->get_nodelist ], };
    }

    for (@submit)
    {
        $c->model($_->{model})->tags->update(
            $c->user->id, $_->{entity}->id, join (", ", @{ $_->{tags} }));
    }

    $c->detach('success');
}

sub default : Path
{
    my ($self, $c, $resource) = @_;

    $c->stash->{serializer} = $serializers{$self->get_default_serialization_type}->new();
    $c->stash->{error} = "Invalid resource: $resource. ";
    $c->detach('bad_req');
}

no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation
Copyright (C) 2009 Lukas Lalinsky
Copyright (C) 2009 Robert Kaye

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
