#!/usr/bin/perl

use Sleepycat::DbXml 'simple';
use strict;
use XML::LibXML;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";
use File::Temp qw/ tempfile tempdir /;
use File::Basename;

require KybotLib;

require "kyoto.conf.pl";
our $KYOTO_HOME;
our $DBXML_ENV_PATH;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

#
# usage
#

sub usage {

  my $str = shift;

  print "ERROR: $str\n" if $str;

  print "USAGE: $0 --profiles profile1 profile2 ... --kaf-files kaf1 kaf2 ... --target-dir target_dir \n";
  print "\t--help this help\n";
  print "\t--profiles list of kybot profiles to run\n";
  print "\t--pr-outfiles list of kybot output XML docs to be integrated in the KAFs\n";
  print "\t--kaf-files list of KAF files\n";
  print "\t--target-dir output directory\n";
  exit 1;
}

my %args = ();
my ($arg_help, @arg_profiles, @arg_pr_outfiles, @arg_kaf_files, $target_dir);
GetOptions(
	   'help'           => \$arg_help,
	   'profiles=s{,}'  => \@arg_profiles,
	   'pr-outfiles=s{,}'  => \@arg_pr_outfiles,
	   'kaf-files=s{,}' => \@arg_kaf_files,
	   'target-dir=s'   => \$target_dir
	  );

usage("No KAF files") unless @arg_kaf_files;
usage("No target directory $target_dir") unless -d $target_dir;

my @kaf_files;

foreach my $kf (@arg_kaf_files) {
  unless (-f $kf) {
    print STDERR "$kf ... not found\n";
    next;
  }
  push @kaf_files, $kf;
}

die "ERROR: no KAF files\n" unless @kaf_files;

my @profiles;

foreach my $pr (@arg_profiles) {
  unless (-f $pr) {
    print STDERR "$pr ... not found\n";
    next;
  }
  push @profiles, $pr;
}

my @pr_outfiles;

foreach my $pr (@arg_pr_outfiles) {
  unless (-f $pr) {
    print STDERR "$pr ... not found\n";
    next;
  }
  push @pr_outfiles, $pr;
}

die "--profiles and --pr-outfiles parameters are incompatible!" if @profiles && @pr_outfiles;

my @prof_results;

if(! @pr_outfiles) {
  die "ERROR: no Kybot profiles\n" unless @profiles;
  @prof_results = &exec_profiles(\@kaf_files, \@profiles);
} else {
  @prof_results = &read_prout(\@pr_outfiles);
}

print STDERR "Writing output to directory $target_dir\n";

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

my $otree = $parser->parse_string(join("\n", @prof_results));

my %delems;

foreach my $doc_elem ($otree->getDocumentElement()->getChildrenByTagName("doc")) {
  $delems{$doc_elem->getAttribute("shortname")} = $doc_elem;
}

foreach my $kafdoc (@kaf_files) {

  my $kaf_docname = basename($kafdoc);
  my $out_elem = $delems{$kaf_docname};
  next unless defined $out_elem;

  my $tree = $parser->parse_file($kafdoc);

  my ($KAF_elem) = $tree->getDocumentElement()->findnodes("/*[1]");

  foreach my $out_sub_elem ($out_elem->childNodes) {
    $out_sub_elem->unbindNode();
    $KAF_elem->addChild($out_sub_elem);
  }

  open(my $ofh, ">$target_dir/$kaf_docname") or die "Can't open $target_dir/$kaf_docname:$!\n";
  binmode($ofh, ":utf8");
  print $ofh $tree->toString(1);
}


sub exec_profiles {

  my ($kaf_files, $profiles) = @_;

  # create a temporal container for holding KAF files
  my $ftmp = new File::Temp(DIR => $DBXML_ENV_PATH, SUFFIX => ".dbxml");
  $ftmp->close();

  my $container_name = basename($ftmp->filename, '.dbxml');

  # $profile_name = "profile_proba2.xml"; # probarako profilea

  # Load KAF files into temporal container

  my $load_cmd = "perl $KYOTO_HOME/doc_load.pl --container-name $container_name --force --no-validation ".join(" ", @{ $kaf_files });
  unlink $ftmp;
  system($load_cmd);

  # Exec profiles
  print STDERR "Executing Kybots\n";
  my $kr_cmd = "perl $KYOTO_HOME/kybot_run.pl --container-name $container_name --dry-run --profile-from-disk --set-ent ".join(" ", @{ $profiles })." |";

  open(my $kr_out, $kr_cmd)
    or die "Can not execute kybot_run.pl: $!\n";
  binmode($kr_out, ':utf8');

  my @prof_results;

  while(<$kr_out>) {
    chomp;
    push @prof_results, $_;
  }
  $kr_out->close();
  return @prof_results;
}

sub read_prout {

  my ($prout_files) = @_;

  my @out;
  foreach my $f (@{ $prout_files }) {
    open(my $fh, $f) || die "Can't open $f:$!\n";
    binmode($fh, ":utf8");
    while(<$fh>) {
      chomp;
      push @out, $_;
    }
  }
  return @out;
}
