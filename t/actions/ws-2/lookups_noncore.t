use utf8;
use strict;
use Test::More;
use XML::SemanticDiff;
use Catalyst::Test 'MusicBrainz::Server';
use MusicBrainz::Server::Test qw( xml_ok v2_schema_validator );
use Test::WWW::Mechanize::Catalyst;

my $c = MusicBrainz::Server::Test->create_test_context;
my $v2 = v2_schema_validator;
my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MusicBrainz::Server');
my $diff = XML::SemanticDiff->new;

$mech->get_ok('/ws/2/discid/T.epJ9O5SoDjPqAJuOJfAI9O8Nk-?inc=artist-credits', 'discid lookup with artist-credits');
&$v2 ($mech->content, "Validate discid lookup with artist-credits");

my $expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <disc id="T.epJ9O5SoDjPqAJuOJfAI9O8Nk-">
        <sectors>256486</sectors>
        <release-list count="1">
            <release id="757a1723-3769-4298-89cd-48d31177852a">
                <title>LOVE &amp; HONESTY</title><status>pseudo-release</status>
                <text-representation>
                    <language>jpn</language><script>Latn</script>
                </text-representation>
                <artist-credit>
                    <name-credit>
                        <artist id="a16d1433-ba89-4f72-a47b-a370add0bb55">
                            <name>BoA</name>
                        </artist>
                    </name-credit>
                </artist-credit>
                <date>2004-01-15</date><country>JP</country>
            </release>
        </release-list>
    </disc>
</metadata>';

is ($diff->compare ($mech->content, $expected), 0, 'result ok');

$mech->get_ok('/ws/2/puid/138f0487-85eb-5fe9-355d-9b94a60ff1dc', 'basic puid lookup');
&$v2 ($mech->content, "Validate basic puid lookup");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <puid id="138f0487-85eb-5fe9-355d-9b94a60ff1dc">
        <recording-list count="2">
            <recording id="44704dda-b877-4551-a2a8-c1f764476e65">
                <title>On My Bus</title><length>267560</length>
            </recording>
            <recording id="6e89c516-b0b6-4735-a758-38e31855dcb6">
                <title>Plock</title><length>237133</length>
            </recording>
        </recording-list>
    </puid>
</metadata>';

is ($diff->compare ($mech->content, $expected), 0, 'result ok');

$mech->get_ok('/ws/2/isrc/JPA600102460?inc=releases', 'isrc lookup with releases');
&$v2 ($mech->content, "Validate isrc lookup with releases");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <isrc-list count="1">
        <isrc id="JPA600102460">
            <recording-list count="1">
                <recording id="487cac92-eed5-4efa-8563-c9a818079b9a">
                    <title>HELLO! また会おうね (7人祭 version)</title><length>213106</length>
                    <release-list count="2">
                        <release id="b3b7e934-445b-4c68-a097-730c6a6d47e6">
                            <title>Summer Reggae! Rainbow</title><status>pseudo-release</status>
                            <text-representation>
                                <language>jpn</language><script>Latn</script>
                            </text-representation>
                            <date>2001-07-04</date><country>JP</country><barcode>4942463511227</barcode>
                        </release>
                        <release id="0385f276-5f4f-4c81-a7a4-6bd7b8d85a7e">
                            <title>サマーれげぇ!レインボー</title><status>official</status>
                            <text-representation>
                                <language>jpn</language><script>Jpan</script>
                            </text-representation>
                            <date>2001-07-04</date><country>JP</country><barcode>4942463511227</barcode>
                        </release>
                    </release-list>
                </recording>
            </recording-list>
        </isrc>
    </isrc-list>
</metadata>';

is ($diff->compare ($mech->content, $expected), 0, 'result ok');

done_testing;
