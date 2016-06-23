#!/usr/bin/perl

# Given a KAF file:
#
# - group terms into paragraphs/sentences
# - put several elements under corresponding <term> elements
# - calculate last id numbers of elements

use strict;
use XML::LibXML;
use Getopt::Std;

# Array of [ element_name, id_prefix, id_attribute_name  ]

my @idCounters = (
		  ["wf", "w", "wid"],
		  ["term", "t", "tid"],
		  ["chunk", "c", "cid"],
		  ["event", "e", "eid"],
		  ["role", "r", "rid"],
		  );

my %opts;

getopt('', \%opts);

my $pretty = $opts{'p'} ? 1 : 0;

die "USAGE: $0 [-p] input.kaf output.kaf\n\t-p\tpretty printing.\n" unless @ARGV == 2;

my ($infile, $outfile) = @ARGV;

open(my $fh, $infile) || die "Can't open $infile:$!\n";
binmode $fh; # clear IO layers

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);
my $tree;

$tree = $parser->parse_fh($fh);

# copy root-level elem (renamed to KAF2) and kaf_header
my $KAF2_ELEM = &create_kaf2_hdr($tree); # global var

# move elements into new format
&move_elements($tree);

# Update indices

my $idcounters_elem = $tree->createElement("idCounters");
$KAF2_ELEM->addChild($idcounters_elem);

foreach my $idc (@idCounters) {
  my $idcount_elem = &create_counter_elem($tree, @{ $idc } );
  $idcounters_elem->addChild($idcount_elem);
}

open(my $ofh, ">$outfile") or die "Can't open $outfile:$!\n";
binmode $ofh; # clear IO layers


$tree->toFH($ofh, $pretty);

#
# Create <KAF2> elem and copy header there
# Note: just rename <KAF> and that's it

sub create_kaf2_hdr {
  my $tree = shift;

  my ($kaf_elem) = $tree->getDocumentElement->findnodes("/KAF");
  $kaf_elem->setNodeName("KAF2");
  return $kaf_elem;

}

#
# move <wf> and <term> elements into sentences
# properly creating new <para> and <sentence> elements.
#
# also, move <deps>, <chunks> etc into appropiate sentences
#

sub move_elements {

  my ($tree) = @_;

  my %w2sent; # { wid -> sent_elem }
  my %widnext; # { wid -> wid }

  &move_wf($tree, \%w2sent, \%widnext);

  my %t2telem; #{ tid -> term_elem }

  %t2telem = &move_terms($tree, \%w2sent, \%widnext);

  undef %w2sent; # free memory

  &tag_chunk_terms($tree, \%t2telem);
  &remove_elems($tree, "//chunk");
  &remove_elems($tree, "//dep");
  &move_locations($tree, \%t2telem);
  &move_dates($tree, \%t2telem);

}

# move <wf> elements into <sentence> elements
# side-effect:
#   create appropiate <para> and <sentence> elements in doc
#   create hash {wid => sentence_elements} and return it

sub move_wf {

  my ($tree, $w2sent, $widnext) = @_;

  my %text_elems; # { sentid -> text_element }
  my $previd;

  foreach my $wf_elem ($tree->getDocumentElement->findnodes("//wf")) {
    my $wid = $wf_elem->getAttribute("wid");
    $widnext->{$previd} = $wid if defined $previd;
    $previd = $wid;
    my $sent_elem = &find_or_create_se($tree, $wf_elem->getAttribute("sent"), $wf_elem->getAttribute("para"));
    my $sentid = $sent_elem->getAttribute("num");

    # update hash
    $w2sent->{$wid} = $sent_elem;

    # put <wf> under new <sent> elem

    # create <text> elem if not already there

    my $text_elem = $text_elems{$sentid};
    if (!defined($text_elem)) {
      $text_elem = $tree->createElement("text");
      $sent_elem->addChild($text_elem);
      $text_elems{$sentid} = $text_elem;
    }

    $wf_elem->unbindNode();
    $text_elem->addChild($wf_elem);
  }
}


#
# Move terms element into sentences
#
# create hash {tid => term_element} and return it

sub move_terms {

  my ($tree, $href, $widnext) = @_;

  my %t2telem; # { tid => term_elem }

  my %terms_elems; # { sentid => terms_elem }
  my $prev_wid;

  # move <term> elements to corresponding <sent> elems

  foreach my $term_elem ($tree->getDocumentElement->findnodes("//term")) {
    my $tid = $term_elem->getAttribute("tid");
    my $tgt_elem = $term_elem->find("./span[1]/target[1]")->get_node(1);
    if (!defined ($tgt_elem)) {
      warn "W:No target in term " . $term_elem->getAttribute("tid")."\n";
      next;
    }
    my $wid = $tgt_elem->getAttribute("id");
    my $sent_elem = $href->{$wid};

    if (!defined ($sent_elem)) {
      warn "W: term " . $term_elem->getAttribute("tid")." spans to undefined <wf> ($wid) \n";
      next;
    }

    my $sentid = $sent_elem->getAttribute("num");

    # create <terms> elem if not already there

    my $terms_elem = $terms_elems{$sentid};
    if (!defined($terms_elem)) {
      $terms_elem = $tree->createElement("terms");
      $sent_elem->addChild($terms_elem);
      $terms_elems{$sentid} = $terms_elem;
    }

    # Insert <pm> ?

    if ($prev_wid && $widnext->{$prev_wid} ne $wid) {
      my $pm_elem = $tree->createElement("pm");
      $terms_elem->addChild($pm_elem);
    }
    $prev_wid = $wid;

    # put <term> under <terms>

    $term_elem->unbindNode();
    $terms_elem->addChild($term_elem);

    # update hash

    $t2telem{$tid} = $term_elem;

  }

  return %t2telem;
}

sub tag_chunk_terms {

  my ($tree, $href) = @_;

  foreach my $celem ($tree->getDocumentElement->findnodes("//chunk")) {
    my $head_tid = $celem->getAttribute("head");
    my $cid = $celem->getAttribute("cid");
    next unless $cid;
    next unless $head_tid;
    my $telem_head = $href->{$head_tid};
    next unless $telem_head;
    my $old_chead = $telem_head->getAttribute("chead");
    $old_chead .= "," if $old_chead;
    $telem_head->setAttribute("chead", $old_chead.$cid);
    foreach my $tgt_elem ($celem->findnodes(".//target")) {
      my $tgt_tid = $tgt_elem->getAttribute("tid");
      next unless $tgt_tid;
      next if $tgt_tid eq $head_tid;
      my $telem_part = $href->{$tgt_tid};
      next unless $telem_part;
      my $old_cpart = $telem_part->getAttribute("cpart");
      $old_cpart .= "," if $old_cpart;
      $telem_part->setAttribute("cpart", $old_cpart.$cid);
    }
  }
}

sub remove_elems {
  my ($tree, $ename) =@_;
  foreach my $celem ($tree->getDocumentElement->findnodes("$ename")) {
    $celem->parentNode->removeChild($celem);
  }
}

{

  my %sent_elems; # { sentid -> sent_element }
  my %para_elems; # { paraid -> para_elem }

  sub find_or_create_se {

    my $tree = shift;
    my $sentid = $_[0] ? $_[0] : "1";
    shift;
    my $paraid = $_[0] ? $_[0] : "1";

    my $k = "$sentid-$paraid";
    my $sent_elem = $sent_elems{$k};
    return $sent_elem if defined($sent_elem);

    # is the paragraph new ? if so, create a new <para> elem

    my $para_elem = $para_elems{$paraid};

    if(!defined($para_elem)) {
      # create <para> as child of <KAF2>
      $para_elem = $tree->createElement("para");
      $para_elem->setAttribute("num", $paraid);
      $KAF2_ELEM->addChild($para_elem);
      $para_elems{$paraid} = $para_elem;
    }

    # Create <sent> under $para_elem

    $sent_elem = $tree->createElement("sentence");
    $sent_elem->setAttribute("num", $sentid);
    $para_elem->addChild($sent_elem);

    # update hash

    $sent_elems{$k} = $sent_elem;

    return $sent_elem;
}

}

############################# Id counter


sub idnumber {

  my ($id, $pre) = @_;

  return 0 unless $id =~ /^$pre(\d+)/;
  return $1;

}

sub create_counter_elem {

  my ($tree, $elem_name, $prefix, $id_attr_name) = @_;

  my $counter_elem = $tree->createElement("idCount");
  $counter_elem->setAttribute("elem", $elem_name);
  $counter_elem->setAttribute("attr", $id_attr_name);
  $counter_elem->setAttribute("pre", $prefix);

  my $max = 0;

  foreach my $elem ($tree->findnodes("//$elem_name")) {
    my $idnum = &idnumber($elem->getAttribute($id_attr_name), $prefix);
    $max = $idnum if $idnum > $max;
  }
  $counter_elem->setAttribute("max", $max);
  return $counter_elem;
}

################### move elements

sub move_deps {

  my ($tree, $href) = @_;

  #&move_elems2($tree, $href, "dep", "from", "deps");

  &move_elems($tree, $href, "dep", './@from');
}


sub move_locations {

  my ($tree, $href) = @_;

  &move_elems($tree, $href, "location", 'kafReferences/kafReference/span/@tid');

  # Remove location xrefs

  foreach my $elem ($tree->getDocumentElement->findnodes("//location/externalReferences")) {
    $elem->unbindNode();
  }

}

sub move_dates {

  my ($tree, $href) = @_;

  &move_elems($tree, $href, "date", 'kafReferences/kafReference/span/@tid');

  foreach my $elem ($tree->getDocumentElement->findnodes("//date/externalReferences")) {
    $elem->unbindNode();
  }

}

sub move_elems {

  my $tree = shift;
  my $href = shift; # { tid => term_elem }
  my $elem_name = shift;
  my $xpath_tids = shift;

  foreach my $elem ($tree->getDocumentElement->findnodes("//$elem_name")) {

    my %aux_tgt_ids = map { $_->to_literal => 1 } $elem->find($xpath_tids)->get_nodelist();
    my @tgt_terms;
    foreach my $term_id (keys %aux_tgt_ids) {
      my $aux = $href->{$term_id};
      next unless defined $aux;
      push (@tgt_terms, $aux);
    }

    # put first under parent
    # next copy under parent

    next unless @tgt_terms;
    my $term_elem = shift @tgt_terms;
    $elem->unbindNode();
    $term_elem->addChild($elem);
    foreach $term_elem (@tgt_terms) {
      my $new_elem = $elem->cloneNode(1);
      $new_elem->unbindNode();
      $term_elem->addChild($new_elem);
    }
  }
}
