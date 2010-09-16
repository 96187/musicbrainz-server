use strict;
use warnings;
use Test::More;
use Test::Moose;
use_ok 'MusicBrainz::Server::Entity::CDStub';
use_ok 'MusicBrainz::Server::Entity::CDStubTOC';
use_ok 'MusicBrainz::Server::Entity::CDStubTrack';

#check to see that all the attributes are present
my $cdstubtoc = MusicBrainz::Server::Entity::CDStubTOC->new();
has_attribute_ok($cdstubtoc, $_) for qw( cdstub_id cdstub discid track_count 
                                         leadout_offset track_offset );

my $cdstubtrack = MusicBrainz::Server::Entity::CDStubTrack->new();
has_attribute_ok($cdstubtrack, $_) for qw( cdstub_id cdstub title artist sequence length );

my $cdstub = MusicBrainz::Server::Entity::CDStub->new();
has_attribute_ok($cdstub, $_) for qw( discid title artist date_added last_modified 
                                      lookup_count modify_count source track_count 
                                      barcode comment );

# Now contstruct a CDStubTOC with a CDStub and a CDStubTrack
$cdstubtrack->title("Track title");
$cdstub->title("CDStub Title");
$cdstub->tracks([$cdstubtrack]);
$cdstubtoc->cdstub($cdstub);

# Check to see that the title of the CD Stub is as we expected
is ($cdstubtoc->cdstub->title, "CDStub Title");

# Check to see that the title of the CD Stub Track is as we expected
is ($cdstubtoc->cdstub->tracks->[0]->title, "Track title");

done_testing;
