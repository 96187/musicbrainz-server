#!/usr/bin/perl
# find root/ -type f -iname '*.tt' | perl ~/find_untranslatable_strings.pl | less

use strict;
use utf8;
use warnings;

while (<>) {
	chomp;
	my $file = $_;
	my $text;

	next if /edit\/conditions.tt/;
	next if /email\/subscriptions.tt/;
	next if /scripts\/text_strings.tt/;

	open FILE, $file;
	while (my $l = <FILE>) {
		chomp($l);
		$text .= $l;
	}
	close FILE;

	$text = strip($text);
	if ($text) {
		print "$file\n";
		print "$text\n\n";
	}
}

sub strip {
	my $text = shift;

	$text =~ s/[\r\n]//g;
	$text =~ s/\[%.*?%\]//g;
	$text =~ s/<script.*?<\/script>//g;
	$text =~ s/<style.*?<\/style>//g;

	my @tags = qw(h1 h2 h3 table tr th td tbody thead tfoot title strong p div select ul li a strong span legend form fieldset code input img ol dt dd dl abbr br em textarea label option button meta link sup iframe html head body pre);
	my $tags = join "|", @tags;

	$text =~ s/<($tags)( +[a-z:-]+="[^"]*"| [a-z:-]+='[^']*')* *\/?>//g;
	$text =~ s/<\/?($tags)>//g;

	$text =~ s/\s\s\s+/  /g;
	$text =~ s/^\s+$//;

	return "$text" if $text;
}
