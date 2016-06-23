#!/usr/bin/perl

use Sleepycat::DbXml 'simple';
use strict;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";
use FindBin;
use lib "$FindBin::Bin";

require KybotLib;

#
# usage
#

sub usage {

    print "USAGE: $0 [ --container-name cont_name ] [ --docs | --kybots ]\n";
    print "\t--container-name name of the container. If ommited, use default container defined in kyoto.conf.pl\n";
    print "\t--docs List documents\n";
    print "\t--kybots List kybots\n";
    exit 0;

}

#
# set default values
#

require "kyoto.conf.pl";
our $KYOTO_HOME;
our $DBXML_ENV_PATH;
our $DBXML_DEFAULT_CONTAINER_NAME;
our $DBXML_KYBOT_DEFAULT_CONTAINER_NAME;
my $container_name = $DBXML_DEFAULT_CONTAINER_NAME;
my $kybot_container_name = $DBXML_KYBOT_DEFAULT_CONTAINER_NAME;

#
# parse parameters
#

my %args = ();
my ($arg_help, $arg_container_name, $arg_docs, $arg_kybots);
GetOptions(
	   'help'             => \$arg_help,
	   'container-name=s' => \$arg_container_name,
	   'docs'             => \$arg_docs,
           'kybots'           => \$arg_kybots
	   );

if ($arg_help) { &usage(); };
if ($arg_docs && $arg_kybots) { $arg_docs = undef; $arg_kybots = undef; }
$container_name = $kybot_container_name if $arg_kybots;
$container_name = $arg_container_name if $arg_container_name ne "";

#
# open dbxml manager
#

my $env = new DbEnv;
$env->open($KYOTO_HOME."/".$DBXML_ENV_PATH,Db::DB_CREATE|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_MPOOL|Db::DB_INIT_TXN, 0);
my $mgr = new XmlManager($env, 0);

my $container = KybotLib::openContainer($mgr, $container_name);
die "Container does not exist.\n" unless defined $container;

my $root_ctx;
my $qexp;
my $result;
eval {
  $root_ctx = $mgr->createQueryContext();
  $root_ctx->setDefaultCollection($container->getName());

  if ($arg_docs) { $qexp = $mgr->prepare('for $doc in collection() where $doc return <Doc name="{document-uri($doc)}" />', $root_ctx); }
  elsif ($arg_kybots) { $qexp = $mgr->prepare('for $doc in collection() where $doc return <Doc name="{document-uri($doc)}" />', $root_ctx); }
  else { $qexp = $mgr->prepare('for $doc in collection() return <Doc name="{document-uri($doc)}" />', $root_ctx); }
  $result = $qexp->execute($root_ctx, 0);
};
if (my $e = catch XmlException) {
  die $e->what();
}

my $value = new XmlValue;
while ($result->next($value)) {
  my $v = $value->asString();
  if ($v =~ /\/+[^\/]+\/([^\"]+)\"/) {
      print $1;
  } else {
    print $v;
  }
  print "\n";
}
