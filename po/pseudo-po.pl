#!/usr/bin/perl
# for i in server relationships attributes statistics instruments instrument_descriptions countries scripts languages; do cat $i.pseudo.po | perl -C pseudo-po.pl > $i.en_AQ.po; done

use strict;
use utf8;
use warnings;

while (<>) {
	s/\\ƞ/\\n/g;
	s/\\ŧ/\\t/g;
	s/(?=\{)(.*?)(?=[:|}])/unac($1)/ge;
	print;
}

sub unac {
	$_ = shift;
	tr/ȧƀƈḓḗƒɠħīĵķŀḿƞǿƥɋřşŧŭṽẇẋẏḖƤ/a-yEP/;
	return $_;
}

