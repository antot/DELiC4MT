#!/usr/bin/perl

use strict;
use XML::LibXML;
use Getopt::Std;
use File::Temp qw/ tempdir /;

binmode STDOUT;

# global variables for the heuristics:
#
#
my $SENT_DIST = 3; # maximum distance of sentences when searching for entities around a term
my $FALLBACK = 1;  # Default fallback method when no entity found:
                   #
                   # 1 -> most frequent entity in document
                   # 2 -> first mention of entity in document

my %opts;

getopt('', \%opts);

my $opt_noloc = $opts{'l'};
my $opt_nodate = $opts{'d'};

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

die "$0 kybot_output.xml container kyoto_home_dir [tempdir]\n" unless @ARGV == 3;

my $kybot_out = shift;		# eventoak
my $domain = shift;		# datu basea
my $kyoto_home = shift;		#kyoto_home

my $ODIR = -d $ARGV[0] ? $ARGV[0] : tempdir( CLEANUP => 1);

my $tree;

open(my $fh, $kybot_out) || die "Can't open $kybot_out:$!\n";
binmode $fh;

$tree = $parser->parse_fh($fh);

if($opt_noloc && $opt_nodate) {
  $tree->toFH(\*STDOUT, 1)."\n";
  exit 0;
}

foreach my $doc_elem ($tree->getDocumentElement->findnodes("//doc")) {
  my $doc_shortname = $doc_elem->getAttribute("shortname");

  my %term_sent; # term_id => sent_id
  my %term_idx;	 #term_id -> index (position)

  my $doctree = &open_kafdoc($doc_shortname);
  &parse_doc_terms($doctree, \%term_sent, \%term_idx);

  # A list with all locations in the document.
  #     - Each element is a hash
  #
  # [ { id => str, elem => element, tids => { tid => 1 }, sids => {sid => ttgt_id } }, ... ]
  #
  #     - The list is ordered according to mentions: first item is the first mentioned location, etc.
  #

  my @Locs;

  @Locs = &parse_doc_entities("/KAF2/locations/location", "lid", "./geoInfo/place | ./geoInfo/country", $doctree, \%term_sent, \%term_idx) unless $opt_noloc;

  my %term_loc; # term_id => loc_idx
  my %sent_loc; # sent_id => loc_idx

  my $mfe_locs = &ent_stats(\@Locs, \%term_loc, \%sent_loc);

  # Same structure as @Locs
  my @Dates;

  @Dates = &parse_doc_entities("/KAF2/dates/date", "did", "./dateInfo", $doctree, \%term_sent, \%term_idx) unless $opt_nodate;

  my %term_date; # term_id => date_idx
  my %sent_date; # sent_id => date_idx

  my $mfe_dates = &ent_stats(\@Dates, \%term_date, \%sent_date);

  foreach my $event_role ($doc_elem->childNodes) {
    my $target = $event_role->getAttribute("target");
    &add_ent($event_role, \@Locs, $target, \%term_sent, \%term_loc, \%sent_loc, $mfe_locs) if ((scalar @Locs) and !$opt_noloc);
    &add_ent($event_role, \@Dates, $target, \%term_sent, \%term_date, \%sent_date, $mfe_dates) if ((scalar @Dates) and !$opt_nodate);
  }
}

$tree->toFH(\*STDOUT, 1)."\n";

sub add_ent {

  my ($event_role, $Locs, $target, $term_sent, $term_ent, $sent_ent, $mfe) = @_;

  my ($place_elem, $place_tgtid) = &get_winner($Locs, $target, $term_sent, $term_ent, $sent_ent, $mfe);
  my $new_place = $place_elem->cloneNode(1);
  # Add new target to place
  my $span_elem = $tree->createElement("span");
  $span_elem->setAttribute("id", $place_tgtid);
  $new_place->addChild($span_elem);
  $event_role->addChild($new_place);
}

##
## The real heuristic !

sub get_winner {

  my ($Ents, $tgt_id, $term_sent, $term_ent, $sent_ent, $mfe) = @_;

  # See if there is an entity with with this target
  my ($h1_elem, $h1_ttgt) = &ent_same_target($Ents, $tgt_id, $term_ent);
  return ($h1_elem, $h1_ttgt) if defined($h1_elem);

  # See if there is an entity on the same sentence
  my ($h2_elem, $h2_ttgt) = &ent_same_sentence($Ents, $tgt_id, $term_sent, $sent_ent);
  return ($h2_elem, $h2_ttgt) if defined $h2_elem;

  my $fallback_elem;
  my $fallback_ttgt;
  # Return most frequent entity
  if ($FALLBACK == 2) {
    # first mention
    ($fallback_elem, $fallback_ttgt) = &first_ent($Ents);
  } else {
    # most frequent
    ($fallback_elem, $fallback_ttgt) = &mfe_ent($Ents, $mfe);
  }
  return ($fallback_elem, $fallback_ttgt);
}

sub ent_same_target {

  my ($Ent, $tgt_id, $term_ent) = @_;

  my $ent_idx = $term_ent->{$tgt_id};
  return undef unless defined $ent_idx;

  return ($Ent->[$ent_idx]->{'elem'}, $tgt_id);

}

sub ent_same_sentence {

  my ($Ent, $tgt_id, $term_sent, $sent_ent) = @_;

  my $term_sid = $term_sent->{$tgt_id};
  my @Sid = ($term_sid);
  for(my $i = 1; $i <= $SENT_DIST; ++$i) {
    push @Sid, $term_sid + $i;
    push @Sid, $term_sid - $i;
  }
  foreach my $sid (@Sid) {
    my $ent_idx = $sent_ent->{$sid};
    next unless defined($ent_idx);
    return $Ent->[$ent_idx]->{'elem'}, $Ent->[$ent_idx]->{'sids'}->{$sid};
  }
  return undef;

}

sub mfe_ent {
  my ($Ent, $mfe_idx) = @_;
  my ($ttgt_id) = keys(%{ $Ent->[$mfe_idx]->{'tids'} });
  return $Ent->[$mfe_idx]->{'elem'}, $ttgt_id;
}

sub first_ent {
  my ($Ent) = @_;
  my ($ttgt_id) = keys(%{ $Ent->[0]->{'tids'} });
  return $Ent->[0]->{'elem'}, $ttgt_id;
}

sub ent_stats {

  my ($Ents, $term_ent, $sent_ent) = @_;

  my $mfe_i = -1;
  my $mfe_c = 0;

  my $i = 0;
  foreach my $ent (@{ $Ents }) {
    my @tids = keys(%{ $ent->{'tids'} });
    if (scalar(@tids) > $mfe_c) {
      $mfe_i = $i;
      $mfe_c = scalar(@tids);
    }
    foreach my $tid (@tids) {
      $term_ent->{$tid} = $i;
    }
    foreach my $sid (keys(%{ $ent->{'sids'} })) {
      $sent_ent->{$sid} = $i;
    }
    $i++;
  }
  return $mfe_i;
}

sub open_kafdoc {

  my ($doc_shortname) = @_;


  my $unlink_doc = 0;
  my $cmd = "perl $kyoto_home/doc_dump.pl --container-name $domain --internal-format --target-dir $ODIR $doc_shortname";

  my $kafdoc = "$ODIR/$doc_shortname";

  if (!(-e $kafdoc)) {
    #jaitsi dbtik uneko dokumentua locationak irakurtzeko
    system $cmd;
    $unlink_doc = 1;
  }
  my $doctree;
  $doctree = $parser->parse_file("$kafdoc");
  unlink($kafdoc) if $unlink_doc;
  return $doctree;
}


sub parse_doc_terms {
  my ($tree, $term_sent, $term_idx) = @_;

  my $tindex = 0;
  foreach my $sents ($tree->getDocumentElement->findnodes("/KAF2/para/sentence")) {
    my $sent_id = $sents->getAttribute("num");
    foreach my $terms ($sents->childNodes()) {
      if ($terms->nodeName eq "terms") {
	foreach my $term ($terms->childNodes()) {
	  my $term_id = $term->getAttribute("tid");
	  $term_sent->{$term_id} = $sent_id;
	  $term_idx->{$term_id} = $tindex++;
	}
      }
    }
  }
}

# $ent_xpath = "/KAF2/locations/location" or "/KAF2/dates/date"
# $ent_idattr = "lid" or "did"
# $ent_oelem = "./geoInfo/place | ./geoInfo/country" or "./dateInfo"

sub parse_doc_entities {

  my ($ent_xpath, $ent_idattr, $ent_oxpath, $tree, $term_sent, $term_idx) = @_;

  my @Ent;

  foreach my $ent_elem ($tree->getDocumentElement->findnodes($ent_xpath)) {
    my %ent = ('tid_midx' => 999999);
    $ent{'id'} = $ent_elem->getAttribute($ent_idattr);
    foreach my $span ($ent_elem->getElementsByTagName("span")) {
      my $span_id = $span->getAttribute("id");
      $ent{'tids'}->{$span_id} = 1;
      $ent{'tid_midx'} = $term_idx->{$span_id} if $term_idx->{$span_id} < $ent{'tid_midx'};
      $ent{'sids'}->{ $term_sent->{$span_id} } = $span_id;
    }
    foreach my $oelem ($ent_elem->findnodes($ent_oxpath)) {
      $ent{'elem'} = $oelem;
    }
    push @Ent, \%ent;
  }

  # sort entities according to term_idx

  return sort {
    $a->{'tid_midx'} <=> $b->{'tid_midx'};
  } @Ent;
}
