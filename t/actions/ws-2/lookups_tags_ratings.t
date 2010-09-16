use utf8;
use strict;
use Test::More;
use XML::SemanticDiff;
use Catalyst::Test 'MusicBrainz::Server';
use MusicBrainz::Server::Test qw( xml_ok schema_validator );
use Test::WWW::Mechanize::Catalyst;

my $c = MusicBrainz::Server::Test->create_test_context;
my $v2 = schema_validator;
my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MusicBrainz::Server');
my $diff = XML::SemanticDiff->new;

$mech->get_ok('/ws/2/artist/a16d1433-ba89-4f72-a47b-a370add0bb55?inc=tags+ratings', 'artist lookup with tags and ratings');
&$v2 ($mech->content, "Validate artist lookup with tags and ratings");

my $expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <artist type="person" id="a16d1433-ba89-4f72-a47b-a370add0bb55">
        <name>BoA</name><sort-name>BoA</sort-name>
        <life-span>
            <begin>1986-11-05</begin>
        </life-span>
        <tag-list>
            <tag count="1"><name>c-pop</name></tag>
            <tag count="1"><name>japanese</name></tag>
            <tag count="1"><name>jpop</name></tag>
            <tag count="1"><name>j-pop</name></tag>
            <tag count="1"><name>kpop</name></tag>
            <tag count="1"><name>k-pop</name></tag>
            <tag count="1"><name>pop</name></tag>
        </tag-list>
        <rating votes-count="3">4.35</rating>
    </artist>
</metadata>';

is ($diff->compare ($expected, $mech->content), 0, 'result ok');

$mech->get_ok('/ws/2/recording/eb818aa4-d472-4d2b-b1a9-7fe5f1c7d26e?inc=tags+ratings', 'recording lookup with tags and ratings');
&$v2 ($mech->content, "Validate recording lookup with tags and ratings");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <recording id="eb818aa4-d472-4d2b-b1a9-7fe5f1c7d26e">
        <title>サマーれげぇ!レインボー (instrumental)</title><length>292800</length>
        <tag-list>
            <tag count="1">
                <name>instrumental version</name>
            </tag>
        </tag-list>
    </recording>
</metadata>';

is ($diff->compare ($expected, $mech->content), 0, 'result ok');

$mech->get_ok('/ws/2/label/b4edce40-090f-4956-b82a-5d9d285da40b?inc=tags+ratings', 'label lookup with tags and ratings');
&$v2 ($mech->content, "Validate label lookup with tags and ratings");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <label type="original production" id="b4edce40-090f-4956-b82a-5d9d285da40b">
        <name>Planet Mu</name><sort-name>Planet Mu</sort-name><country>GB</country>
        <life-span>
            <begin>1995</begin>
        </life-span>
        <tag-list>
            <tag count="1"><name>british</name></tag>
            <tag count="1"><name>english</name></tag>
            <tag count="1"><name>uk</name></tag>
        </tag-list>
    </label>
</metadata>';

is ($diff->compare ($expected, $mech->content), 0, 'result ok');

$mech->get_ok('/ws/2/release-group/22b54315-6e51-350b-bb34-e6e16f7688bd?inc=tags+ratings', 'release group lookup with tags and ratings');
&$v2 ($mech->content, "Validate release group lookup with tags and ratings");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <release-group type="album" id="22b54315-6e51-350b-bb34-e6e16f7688bd">
        <title>My Demons</title>
        <tag-list>
            <tag count="2">
                <name>dubstep</name>
            </tag>
            <tag count="1">
                <name>electronic</name>
            </tag>
            <tag count="1">
                <name>grime</name>
            </tag>
        </tag-list>
    </release-group>
</metadata>';

is ($diff->compare ($expected, $mech->content), 0, 'result ok');


$mech->get_ok('/ws/2/artist/a16d1433-ba89-4f72-a47b-a370add0bb55?inc=release-groups+tags+ratings', 'artist lookup with release-groups, tags and ratings');
&$v2 ($mech->content, "Validate artist lookup with release-groups, tags and ratings");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <artist type="person" id="a16d1433-ba89-4f72-a47b-a370add0bb55">
        <name>BoA</name><sort-name>BoA</sort-name>
        <life-span>
            <begin>1986-11-05</begin>
        </life-span>
        <release-group-list count="1">
            <release-group type="album" id="23f421e7-431e-3e1d-bcbf-b91f5f7c5e2c">
            <title>LOVE &amp; HONESTY</title>
                <tag-list>
                    <tag count="1"><name>format-dvd-video</name></tag>
                </tag-list>
            </release-group>
        </release-group-list>
        <tag-list>
            <tag count="1"><name>c-pop</name></tag>
            <tag count="1"><name>japanese</name></tag>
            <tag count="1"><name>jpop</name></tag>
            <tag count="1"><name>j-pop</name></tag>
            <tag count="1"><name>kpop</name></tag>
            <tag count="1"><name>k-pop</name></tag>
            <tag count="1"><name>pop</name></tag>
        </tag-list>
        <rating votes-count="3">4.35</rating>
    </artist>
</metadata>';

is ($diff->compare ($expected, $mech->content), 0, 'result ok');


$mech->get_ok('/ws/2/release/adcf7b48-086e-48ee-b420-1001f88d672f?inc=release-groups+tags+ratings', 'release lookup with release-groups, tags and ratings');
&$v2 ($mech->content, "Validate release lookup with release-groups, tags and ratings");

$expected = '<?xml version="1.0" encoding="UTF-8"?>
<metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
    <release id="adcf7b48-086e-48ee-b420-1001f88d672f">
        <title>My Demons</title><status>official</status>
        <text-representation>
            <language>eng</language><script>Latn</script>
        </text-representation>
        <release-group type="album" id="22b54315-6e51-350b-bb34-e6e16f7688bd">
            <title>My Demons</title>
            <tag-list>
                <tag count="2"><name>dubstep</name></tag>
                <tag count="1"><name>electronic</name></tag>
                <tag count="1"><name>grime</name></tag>
            </tag-list>
        </release-group>
        <date>2007-01-29</date><country>GB</country><barcode>600116817020</barcode>
    </release>
</metadata>';

is ($diff->compare ($mech->content, $expected), 0, 'result ok');


done_testing;
