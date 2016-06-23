#!/usr/bin/perl

use strict;
use Sleepycat::DbXml 'simple';
use File::Temp;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";
use XML::LibXML;

require KybotLib;

#
# usage
#

sub usage {

    print "USAGE: $0 [ --container-name cont_name ] [ --internal-format ] [ --target-dir target_directory ] doc [doc2 doc3 ...]\n";
    print "\t--container-name name of the container. If ommited, use default container defined in kyoto.conf.pl\n";
    print "\t--internal-format Dump the document as-is, i.e., without aplying any transformation.\n";
    print "\t--target-dir Directory for leaving the documents.\n";
    print "\t--alldocs Dump all docs of container.\n";
    exit 0;

}

#
# set default values
#

require "kyoto.conf.pl";
our $KYOTO_HOME;
our $DBXML_ENV_PATH;
our $DBXML_DEFAULT_CONTAINER_NAME;
our $SAXON_EXEC;
our $KAF2TOKAF_XSL;
my $container_name = $DBXML_DEFAULT_CONTAINER_NAME;

#
# parse parameters
#

my %args = ();
my ($arg_help, $arg_container_name, $arg_internal_format, $arg_target_dir, $arg_alldocs);
GetOptions(
	   'help'             => \$arg_help,
	   'container-name=s' => \$arg_container_name,
	   'internal-format' => \$arg_internal_format,
	   'target-dir=s' => \$arg_target_dir,
	   'alldocs' => \$arg_alldocs
	   );

if ($arg_help) { &usage(); }
if (!$arg_alldocs && (@ARGV == 0)) { &usage(); }
if ($arg_container_name ne "")  { $container_name = $arg_container_name; }

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

my $env = new DbEnv;
$env->open($KYOTO_HOME."/".$DBXML_ENV_PATH,Db::DB_CREATE|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_MPOOL|Db::DB_INIT_TXN, 0);
my $mgr = new XmlManager($env,0);

my $container = KybotLib::openContainer($mgr, $container_name);
die "Container does not exist.\n" unless defined $container;

&populate_kdocs(\@ARGV, $container_name) if ($arg_alldocs);

foreach my $docname (@ARGV) {

    my $xmldoc;

    eval {
	$xmldoc = $container->getDocument($docname);
    };
    if (my $e = catch XmlException) {
	die $e->what();
    }

    if ($arg_internal_format) {

 	if (-d $arg_target_dir) { $docname = $arg_target_dir."/".$docname; }

	my $tree;
	$tree = $parser->parse_string($xmldoc);

	open OUT, ">$docname";
	print OUT $tree->toString(1);
	close OUT;

    }
    else {

#
# convert from kaf2 to kaf
#
	my $ftmp = new File::Temp();
	die "Can't create temporal file:$!\n" unless $ftmp;
	binmode ($ftmp, ':utf8');
	print $ftmp $xmldoc;
	print $ftmp "\n";
	$ftmp->close();

	if (-d $arg_target_dir) { $docname = $arg_target_dir."/".$docname; }
	open OUT, ">$docname";

	open(my $sx_fh, "$SAXON_EXEC -xsl:$KAF2TOKAF_XSL -s:$ftmp |");

	while(my $l = <$sx_fh>) {
	    print OUT $l;
	}

	close OUT;

    }

}

sub populate_kdocs {

  my ($aref, $container) = @_;

  open(my $fh, "./container_ls.pl --container-name $container |") or die "Can't execute ./container_ls.pl\n";
  while(<$fh>) {
    chomp;
    push @{ $aref }, $_;
  }
}
