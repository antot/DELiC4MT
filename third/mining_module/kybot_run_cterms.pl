#!/usr/bin/perl

use strict;
use warnings;
use XML::LibXML;
use Getopt::Long;
use Sleepycat::DbXml 'simple';

require KybotLib;

binmode STDOUT;

sub usage {

  print "USAGE: $0 [ --container-name cont_name ]\n";
  print "\t--container-name name of the container. If ommited, use default container defined in kyoto.conf.pl\n";
  print "\t--verbose.\n";
  exit 0;

}

require "kyoto.conf.pl";
our $KYOTO_HOME;
our $DBXML_ENV_PATH;
our $DBXML_DEFAULT_CONTAINER_NAME;
our $DBXML_KYBOT_DEFAULT_CONTAINER_NAME;
my $container_name = $DBXML_DEFAULT_CONTAINER_NAME;

#
# parse parameters
#

my %args = ();
my ($arg_help, $arg_container_name, $arg_verbose);
GetOptions(
	   'help'             => \$arg_help,
	   'verbose'          => \$arg_verbose,
	   'container-name=s' => \$arg_container_name
	  );

if ($arg_help) {
  &usage();
}

$container_name = $arg_container_name if $arg_container_name;
$container_name.=".dbxml" unless $container_name =~ /\.dbxml$/;
$container_name = "$DBXML_ENV_PATH/$container_name" unless -f $container_name;

#
# open dbxml manager
#

#my $env = new DbEnv;
#$env->open($KYOTO_HOME."/".$DBXML_ENV_PATH,Db::DB_CREATE|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_MPOOL|Db::DB_INIT_TXN, 0);
#my $mgr = new XmlManager($env, 0);
my $mgr = new XmlManager();

my $container = KybotLib::openContainer($mgr, $container_name);
die "Container does not exist.\n" unless defined $container;

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

my $odoc = XML::LibXML::Document->new('1.0',"UTF-8");
my $oelem = $odoc->createElement("kybotOut");
$odoc->setDocumentElement($oelem);

my %delems; # docname -> doc_elem

my $bevent = 0;
my $brole = 0;

my $value = new XmlValue;

my $result = &get_db_terms('collection()//term[.//externalRef[@reftype="sc_participantOf"]]');

while ($result->next($value)) {
  my $odoc_elem = &get_delem($odoc, $value->asDocument()->getName(), \%delems);
  my $tree = $parser->parse_string($value);
  my $term = $tree->getDocumentElement();
  &macro1($term, $odoc_elem);
}

$result = &get_db_terms('collection()//term[.//externalRef[@reftype="sc_hasRole" or @reftype="sc_hasCoRole"]]');

while ($result->next($value)) {
  my $odoc_elem = &get_delem($odoc, $value->asDocument()->getName(), \%delems);
  my $tree = $parser->parse_string($value);
  my $term = $tree->getDocumentElement();
  &macro2($term, $odoc_elem);
}

foreach my $d_elem (sort(values %delems)) {
  next unless $d_elem->hasChildNodes();
  $oelem->addChild($d_elem);
}

print $odoc->toFH(\*STDOUT, 1);


# "migratory fish"

# endurant term+sc_participantOf:a_perdurant+sc_playRole:a_role+sc_CoParticipant:a_co_participant+sc_playCoRole:a_co_role
#
# Primary search: a_perdurant
#
# <event lemma=a_perdurant target=term synset=term_synset rank_term_rank/>
# <role lemma=term_lemma target=term synset=term_synset rank_term_rank  rtype=a_role />
# <role lemma=a_co_participant target=term synset=term_synset rank_term_rank  rtype=a_co_role />
#
#
#  ERRORS:
#
#  no output in benchmark for
#        - sc_CoParticipant
#        - sc_playCoRole

sub macro1 {

  my ($term, $oelem) = @_;

  my $lemma = $term->getAttribute("lemma");
  my $tgt = $term->getAttribute("tid");

  my ($a_perdurant) = &get_xref($term, "sc_participantOf");
  my @a_role = &get_xref($term, "sc_playRole");
  my @a_coparticipant = &get_xref($term, "sc_CoParticipant");
  my @a_co_role = &get_xref($term, "sc_playCoRole");

  my $is_corole = scalar(@a_coparticipant) && scalar(@a_co_role);
  return unless (scalar(@a_role) || $is_corole);

  my $ev_elem = $odoc->createElement("event");
  $bevent++;
  $ev_elem->setAttribute("eid","e$bevent");
  $ev_elem->setAttribute("lemma", $a_perdurant);
  $ev_elem->setAttribute("target", $tgt);
  $oelem->addChild($ev_elem);

  foreach my $a_role (@a_role) {
    my $r_elem = $odoc->createElement("role");
    $brole++;
    $r_elem->setAttribute("rid","r$brole");
    $r_elem->setAttribute("event","e$bevent");
    $r_elem->setAttribute("lemma", $lemma);
    $r_elem->setAttribute("target", $tgt);
    $r_elem->setAttribute("rtype", $a_role);
    $oelem->addChild($r_elem);
  }

  # if ($is_corole) {
  #   foreach my $a_role (@a_co_role) {
  #     my $r_elem = $odoc->createElement("role");
  #     $r_elem->setAttribute("lemma", $lemma);
  #     $r_elem->setAttribute("target", $tgt);
  #     $r_elem->setAttribute("rtype", $a_role);
  #     $oelem->addChild($ev_elem);
  #   }
  # }
}



# "crab explotation"

# perdurant term+sc_hasParticipant:a_participant+sc_hasRole:a_role+sc_hasCoParticipant:a_co_participant+sc_hasCoRole:a_co_role
# ->
#
#  Primary search: a_role OR a_co_role
#
# <event lemma=term_lemma target=term synset=term_synset rank_term_rank/>
# <role lemma=a_participant target=term synset=term_synset rank_term_rank  rtype=a_role />
# <role lemma=a_co_participant target=term synset=term_synset rank_term_rank  rtype=a_co_role />

sub macro2 {

  my ($term, $oelem) = @_;

  my $lemma = $term->getAttribute("lemma");
  my $tgt = $term->getAttribute("tid");

  my @a_participant = &get_xref($term, "sc_hasParticipant");
  my @a_role = &get_xref($term, "sc_hasRole");
  my @a_coparticipant = &get_xref($term, "sc_hasCoParticipant");
  my @a_co_role = &get_xref($term, "sc_playCoRole");

  #my $is_corole = scalar(@a_coparticipant) && scalar(@a_co_role);
  return unless @a_participant;

  my $ev_elem = $odoc->createElement("event");
  $bevent++;
  $ev_elem->setAttribute("eid","e$bevent");
  $ev_elem->setAttribute("lemma", $lemma);
  $ev_elem->setAttribute("target", $tgt);
  $oelem->addChild($ev_elem);

  for (my $i = 0; $i < @a_participant; $i++) {
    next unless $a_role[$i];
    my $r_elem = $odoc->createElement("role");
    $brole++;
    $r_elem->setAttribute("rid","r$brole");
    $r_elem->setAttribute("event","e$bevent");
    $r_elem->setAttribute("lemma", $a_participant[$i]);
    $r_elem->setAttribute("target", $tgt);
    $r_elem->setAttribute("rtype", $a_role[$i]);
    $oelem->addChild($r_elem);
  }

  for (my $i = 0; $i < @a_coparticipant; $i++) {
    next unless $a_co_role[$i];
    $brole++;
    my $r_elem = $odoc->createElement("role");
    $r_elem->setAttribute("rid","r$brole");
    $r_elem->setAttribute("event","e$bevent");
    $r_elem->setAttribute("lemma", $a_coparticipant[$i]);
    $r_elem->setAttribute("target", $tgt);
    $r_elem->setAttribute("rtype", $a_co_role[$i]);
    $oelem->addChild($r_elem);
  }
}

sub get_xref {

  my ($root, $sc_rtype, $rtype) = @_;

  my $xref_xpath = 'descendant::externalRef[@reftype="'.$sc_rtype.'"]';

  my @Res;

  foreach my $elem ($root->findnodes($xref_xpath)) {
    push @Res, $elem->getAttribute("reference");
  }
  return @Res;

}

sub open_kafdoc {

  my ($doc_shortname) = @_;

  my $unlink_doc = 0;
  if (!(-e $doc_shortname)) {
    #jaitsi dbtik uneko dokumentua locationak irakurtzeko
    system "perl $KYOTO_HOME/doc_dump.pl --container-name $container_name --internal-format $doc_shortname";
    $unlink_doc = 1;
  }

  my $doctree;
  $doctree = $parser->parse_file($doc_shortname);
  unlink($doc_shortname) if $unlink_doc;
  return $doctree;
}

sub get_db_terms {

  my ($xpath) = @_;

  my $root_ctx;
  my $qexp;
  my $result;

  eval {
    $root_ctx = $mgr->createQueryContext();
    $root_ctx->setDefaultCollection($container->getName());
    $qexp = $mgr->prepare($xpath, $root_ctx);
    $result = $qexp->execute($root_ctx, 0);
  };
  if (my $e = catch XmlException) {
    die $e->what();
  }
  return $result;
}

sub get_delem {

  my ($odoc, $docname, $href) = @_;

  my $doc_elem = $href->{$docname};
  return $doc_elem if defined($doc_elem);

  $doc_elem = $odoc->createElement("doc");
  $doc_elem->setAttribute("shortname","$docname");
  $href->{$docname} = $doc_elem;
  return $doc_elem;

}
