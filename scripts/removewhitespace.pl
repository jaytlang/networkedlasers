#!/usr/bin/perl

use strict;
use warnings;

# Prior to upstreaming a commit, run this script
# to remove all trailing whitespace from any *.java files

my $tmpfname = "/tmp/fixedwhitespace.java";
my @files = `find . -name "*.sv"`;

foreach my $src (@files){
	chomp $src;
	print $src."\n";

	open my $RFH, '<', $src or die "Can't open $src: $!";
	open my $WFH, '>', $tmpfname or die "Can't open $tmpfname for writing: $!";
	while(<$RFH>){
		s/\h+$//;
		print $WFH $_;
	}

	close $WFH; close $RFH;
	rename $tmpfname, $src;
}

unlink $tmpfname;
