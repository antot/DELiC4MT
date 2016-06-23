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

BEGIN {

  if ($ENV{"KYOTO_MM_DIR"}) {
    push @INC, $ENV{"KYOTO_MM_DIR"};
    chdir $ENV{"KYOTO_MM_DIR"};
  }
}

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
  print "\t--pr-dir Directory where kybot profiles are\n";
  print "\t--mm-dir Working directory. Program moves to mm_dir before doing anything else.\n";
  exit 1;
}

my %args = ();
my ($arg_help, $arg_kdir, $arg_pwd);
GetOptions(
	   'help'      => \$arg_help,
	   'pr-dir=s'  => \$arg_kdir,
	   'mm-dir=s'  => \$arg_pwd);

if (defined($arg_pwd)) {
  &usage("Invalid working directory") unless -d $arg_pwd;
  chdir($arg_pwd);
}

&usage("No Kybot dir") unless $arg_kdir;

opendir(D, "$arg_kdir") || usage("Can't open $arg_kdir: $!\n");
my @profiles = grep { /\.xml/ && -f "$arg_kdir/$_" } readdir(D);
@profiles = map { "$arg_kdir/$_" } @profiles;
closedir(D);

&usage("No kybot profiles") unless @profiles;

KybotLib::rmEnvFiles("${KYOTO_HOME}/${DBXML_ENV_PATH}");

my $fh = File::Temp->new();
die "Can't create temporal file:$!\n" unless $fh;
binmode ($fh, ':utf8');

while(<STDIN>) {
  print $fh $_;
}

$fh->close();

my @kaf_files = ($fh->filename);

my @prof_results = &exec_profiles(\@kaf_files, \@profiles);

print STDOUT join("\n", @prof_results);

exit 0;

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
  #print STDERR "Executing Kybots\n";
  my $kr_cmd = "perl $KYOTO_HOME/kybot_run.pl --container-name $container_name --dry-run --profile-from-disk ".join(" ", @{ $profiles })." |";

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
