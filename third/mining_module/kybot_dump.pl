#!/usr/bin/perl

use strict;
use Sleepycat::DbXml 'simple';
use File::Temp;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";

require KybotLib;

#
# usage
#

sub usage {

    print "USAGE: $0 [ --container-name cont_name ] [ --target-dir target_directory ] kybot [kybot2 kybot3 ...]\n";
    print "\t--container-name name of the kybot container. If ommited, use default kybot container defined in kyoto.conf.pl\n";
    print "\t--target-dir Directory for leaving the documents.\n";

    exit 0;

}

#
# set default values
#

require "kyoto.conf.pl";
our $KYOTO_HOME;
our $DBXML_ENV_PATH;
our $DBXML_DEFAULT_CONTAINER_NAME;
my $container_name = $DBXML_DEFAULT_CONTAINER_NAME;

#
# parse parameters
#

my %args = ();
my ($arg_help, $arg_container_name, $arg_target_dir);
GetOptions(
	   'help'             => \$arg_help,
	   'container-name=s' => \$arg_container_name,
	   'target-dir=s'     => \$arg_target_dir
	   );

if ($arg_help) { &usage() }
if (@ARGV eq 0) { &usage() }
if ($arg_container_name ne "")  { $container_name = $arg_container_name; }


my $docname=$ARGV[0];

my $env = new DbEnv;
$env->open($KYOTO_HOME."/".$DBXML_ENV_PATH,Db::DB_CREATE|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_MPOOL|Db::DB_INIT_TXN, 0);
my $mgr = new XmlManager($env,0);

my $container = KybotLib::openContainer($mgr, $container_name);
die "Container does not exist.\n" unless defined $container;

foreach $docname (@ARGV) {

    my $xmldoc;

    eval {
	$xmldoc = $container->getDocument($docname);
    };
    if (my $e = catch XmlException) {
	die $e->what();
    }

    if (-d $arg_target_dir) { $docname = $arg_target_dir."/".$docname; }

    open OUT, ">$docname";
    print OUT $xmldoc;
    close OUT;

}
