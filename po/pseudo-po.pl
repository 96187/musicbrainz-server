#!/usr/bin/perl
# cat pseudo.po | perl -C pseudo-po.pl > en-aq.po

use strict;
use utf8;
use warnings;

while (<>) {
    s/(?=\{)(.*?)(?=[:|}])/unac($1)/ge;
    print;
}

sub unac {
    $_ = shift;
    tr/ȧƀƈḓḗƒɠħīĵķŀḿƞǿƥɋřşŧŭṽẇẋẏḖƤ/a-yEP/;
    return $_;
}

