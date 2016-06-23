#!/usr/bin/perl

use strict;
use Getopt::Long;

require Harmonizer;

binmode STDOUT;

sub usage {

  print "usage: $0 [-p primary_doc.xml] doc1.xml doc2.xml ...\n";
  print "\t--pdoc use primary_doc.xml as starting point (for event id's etc)\n";
  print "\t-h display usage\n";
  exit 0;
}

my ($arg_pdoc, $arg_help);

GetOptions(
	   'help'             => \$arg_help,
	   'pdoc=s' => \$arg_pdoc
	  );

if ($arg_help) {
  &usage();
}
if (@ARGV eq 0) {
  &usage();
}

my $harm = new Harmonizer;

foreach my $doc (@ARGV) {
  $harm->harmonize_file($doc);
}

$harm->toString(\*STDOUT, 1);
