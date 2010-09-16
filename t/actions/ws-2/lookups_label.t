use utf8;
use strict;
use Test::More;
use XML::SemanticDiff;
use Catalyst::Test 'MusicBrainz::Server';
use MusicBrainz::Server::Test qw( xml_ok );
use MusicBrainz::Server::Test qw( xml_ok schema_validator );
use Test::WWW::Mechanize::Catalyst;

my $c = MusicBrainz::Server::Test->create_test_context;
my $v2 = schema_validator;
my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MusicBrainz::Server');
my $diff = XML::SemanticDiff->new;

$mech->get_ok('/ws/2/label/b4edce40-090f-4956-b82a-5d9d285da40b', 'basic label lookup');
&$v2 ($mech->content, "Validate basic label lookup");

my $expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <label type="original production" id="b4edce40-090f-4956-b82a-5d9d285da40b">
        <name>Planet Mu</name><sort-name>Planet Mu</sort-name>
        <country>GB</country>
        <life-span><begin>1995</begin></life-span>
    </label>
</metadata>';

is ($diff->compare ($mech->content, $expected), 0, 'result ok');

$mech->get_ok('/ws/2/label/b4edce40-090f-4956-b82a-5d9d285da40b?inc=aliases', 'label lookup, inc=aliases');
&$v2 ($mech->content, "Validate lookup, inc=aliases");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <label type="original production" id="b4edce40-090f-4956-b82a-5d9d285da40b">
        <name>Planet Mu</name><sort-name>Planet Mu</sort-name>
        <country>GB</country>
        <life-span><begin>1995</begin></life-span>
        <alias-list count="1"><alias>Planet µ</alias></alias-list>
    </label>
</metadata>';

is ($diff->compare ($mech->content, $expected), 0, 'result ok');

$mech->get_ok('/ws/2/label/b4edce40-090f-4956-b82a-5d9d285da40b?inc=releases+media', 'label lookup with releases, inc=media');
&$v2 ($mech->content, "Validate lookup with releases, inc=media");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <label type="original production" id="b4edce40-090f-4956-b82a-5d9d285da40b">
        <name>Planet Mu</name><sort-name>Planet Mu</sort-name>
        <country>GB</country>
        <life-span><begin>1995</begin></life-span>
        <release-list count="2">
            <release id="adcf7b48-086e-48ee-b420-1001f88d672f">
                <title>My Demons</title><status>official</status>
                <text-representation>
                    <language>eng</language><script>Latn</script>
                </text-representation>
                <date>2007-01-29</date><country>GB</country><barcode>600116817020</barcode>
                <medium-list count="1">
                    <medium>
                        <position>1</position><format>cd</format><track-list count="12" />
                    </medium>
                </medium-list>
            </release>
            <release id="3b3d130a-87a8-4a47-b9fb-920f2530d134">
                <title>Repercussions</title><status>official</status>
                <text-representation>
                    <language>eng</language><script>Latn</script>
                </text-representation>
                <date>2008-11-17</date><country>GB</country><barcode>600116822123</barcode>
                <medium-list count="2">
                    <medium>
                        <position>1</position><format>cd</format><track-list count="9" />
                    </medium>
                    <medium>
                        <title>Chestplate Singles</title>
                        <position>2</position><format>cd</format><track-list count="9" />
                    </medium>
                </medium-list>
            </release>
        </release-list>
    </label>
</metadata>';

is ($diff->compare ($mech->content, $expected), 0, 'result ok');

done_testing;
