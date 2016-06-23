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

    print "USAGE: $0 [ --container-name cont_name ] [--force] kybot [kybot2 kybot3 ...]\n";
    print "\t--container-name name of the container. If ommited, use default container defined in kyoto.conf.pl\n";
    print "\t--force Create a new container if not there.\n";
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
my ($arg_help, $arg_container_name, $arg_force, $arg_validate);
GetOptions(
	   'help' => \$arg_help,
	   'container-name=s' => \$arg_container_name,
	   'validate' => \$arg_validate,
	   'force' => \$arg_force
	   );

if ($arg_help) { &usage(); }
if (@ARGV eq 0) { &usage(); }
if ($arg_container_name ne "")  { $container_name = $arg_container_name; }

my $env = new DbEnv;
$env->open($KYOTO_HOME."/".$DBXML_ENV_PATH,Db::DB_CREATE|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_MPOOL|Db::DB_INIT_TXN, 0);
my $mgr = new XmlManager($env,0);

my $container = KybotLib::openContainer($mgr, $container_name);
if (!defined($container)) {
    die "Container does not exist. Use --force for creating a new container.\n" unless $arg_force;
    $container = KybotLib::createSimpleContainer($mgr, $container_name);
}

foreach my $docname (@ARGV) {

    if (-f $docname) {

	my $docname_short = $docname;
	my @splitted = split(/\//, $docname);
	if (@splitted > 1) { $docname_short = $splitted[$#splitted]; }

        # See wether $docname is already in the DB

        my $doc_already = 1;

	eval {
	  $container->getDocument($docname_short);
	};

	if (my $e = catch XmlException) {
	  $doc_already = 0;
	}

	if ($doc_already) {
	  print STDERR "Kybot profile $docname_short already in the DB. Skiping.\n";
	  next;
	}


	eval {

	    my $ucontext = $mgr->createUpdateContext();
	    my $xmlinput = $mgr->createLocalFileInputStream($docname);
	    $container->putDocument($docname_short, $xmlinput, $ucontext);

	};
	if (my $e = catch XmlException) {
	    die $e->what();
	}

    } else { die "Can't read $docname !\n"}

}
