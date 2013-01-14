#!/usr/bin/perl

for my $file (@ARGV) {
	open FILE, $file or die;
	my @lines = grep /\{/, split /\n\n/, join "", grep !/^#/, <FILE>;
	close FILE;

	for my $line (@lines) {
		$line =~ s/\n//g;

		if ($line =~ /msgid "(.*)"msgstr(?:\[0\])? "(.*)"/s) {
			$o = $1; $t = $2;
			$t =~ s/"msgstr\[[0-9]\] "//g;
			next if $t eq "";
			next if $o eq "Please {login} to edit the disc IDs for this release.";

			while ($o =~ /\{([^}:|]+)/g) {
				print STDERR "Error in $file: $line\n" unless $t =~ /\{$1[}:|]/;
			}
		} else { print "Regex failed in $file for $line\n"; }
	}

}

1;
