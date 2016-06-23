#!/usr/bin/perl

use strict;
use Sleepycat::DbXml 'simple';
use File::Temp qw/ tempfile tempdir /;
use File::Basename;
use Getopt::Long;
use XML::LibXML;
use FindBin;
use lib "$FindBin::Bin";

require KybotLib;

#
# usage
#

sub usage {

    print "USAGE: $0 [--container-name cont_name] [--force] [--internal-format] [--no-validation] doc [doc2 doc3 ...]\n";
    print "\t--container-name name of the container. If ommited, use default container defined in kyoto.conf.pl\n";
    print "\t--force Create a new container if not there.\n";
    print "\t--internal-format Store the document as-is, i.e., without aplying any transformation.\n";
    print "\t--no-validation Don't validate the doc against the KAF dtd.\n";
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
our $KAFTOKAF2_XSL;
our $KAF_DTD;
my $container_name = $DBXML_DEFAULT_CONTAINER_NAME;

#
# parse parameters
#

my %args = ();
my ($arg_help, $arg_container_name, $arg_force, $arg_internal_format, $arg_validation, $arg_no_validation, $arg_verbose);

$arg_no_validation = 1; # Don't validate by default

GetOptions(
	   'help'             => \$arg_help,
	   'container-name=s' => \$arg_container_name,
	   'force'            => \$arg_force,
	   'internal-format' => \$arg_internal_format,
	   'no-validation' => \$arg_no_validation,
	   'validation' => \$arg_validation,
	   'verbose' => \$arg_verbose
	   );

if ($arg_help) { &usage(); }
if (@ARGV eq 0) { &usage(); }
if ($arg_container_name ne "")  { $container_name = $arg_container_name; }

$arg_no_validation = 0 if $arg_validation;

KybotLib::rmEnvFiles("${KYOTO_HOME}/${DBXML_ENV_PATH}");

my $env = new DbEnv;
$env->open($KYOTO_HOME."/".$DBXML_ENV_PATH,Db::DB_CREATE|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_MPOOL|Db::DB_INIT_TXN, 0);
my $mgr = new XmlManager($env,0);

my $container = KybotLib::openContainer($mgr, $container_name);
if (!defined($container)) {
    #die "Container does not exist. Use --force for creating a new container.\n" unless $arg_force;
    $container = KybotLib::createDocContainer($mgr, $container_name);
}

foreach my $docname (@ARGV) {

    if (-f $docname) {

	print STDERR "Loading $docname\n" if $arg_verbose;
	my $docname_short = basename($docname);

        # See wether $docname is already in the DB

        my $doc_already = 1;

	eval {
	  $container->getDocument($docname_short);
	};

	if (my $e = catch XmlException) {
	  $doc_already = 0;
	}

	if ($doc_already) {
	  print STDERR "Document $docname_short already in the DB. Skiping.\n";
	  next;
	}

	if ($arg_internal_format) {
	  &load_doc($mgr, $container, $docname, $docname_short);
	} else {

	    #
            # validate document?
	    #

	    if (!$arg_no_validation) {

		my $dtd = XML::LibXML::Dtd->new("", $KAF_DTD);
		my $tmpdoc = XML::LibXML->new->parse_file($docname);
		if (!$tmpdoc->is_valid($dtd)) {
		    die "$docname is not a valid KAF document.\n";
		}
	    }

	    my $ftmp = new File::Temp();
	    $ftmp->close();
	    system("perl $KYOTO_HOME/kaf_to_kaf2.pl -p $docname $ftmp");
	    &load_doc($mgr, $container, $ftmp->filename, $docname_short);
	}

    } else { die "Can't read $docname !\n"}

}

sub load_doc {

  my ($mgr, $container, $docname, $theName) = @_;

  open (my $fh, $docname) || die "Can't open $docname:$!\n";
  binmode($fh, ':utf8');

  my $xmlString  = "";
  while(<$fh>) {
    $xmlString .= $_;
  }
  $fh->close();

  eval {

    #  declare an xml document 
    my $xmlDoc = $mgr->createDocument();

    #  Set the xml document's content to be the xmlString we just obtained.
    $xmlDoc->setContent( $xmlString );

    #  Get the document name. this strips off any path information.
    #print STDERR "$docname $theName\n";

    # Set the document name
    $xmlDoc->setName( $theName );

    #  place that document into the container
    $container->putDocument($xmlDoc);

  };
  if (my $e = catch XmlException) {
    die $e->what();
  }

}
