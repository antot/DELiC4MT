package Harmonizer;

use strict;
use XML::LibXML;

my $EID;
my $RID;

sub new_doc {

  my %h = ( 'events' => [],
	    'roles' => [],
	    'eid2ev' => {},
	    'rid2rl' => {},
	    'tgt2eid' => {},
	    'eid2rid' => {},
	    'eid' => 1,
	    'rid' => 1);
  return \%h;
}

sub new {

  my $that = shift;
  my $class = ref($that) || $that;

  my $parser = XML::LibXML->new();
  $parser->keep_blanks(0);

  my $self = { 'docs' => {}, 'parser' => $parser };
  bless $self, $class;
  return $self;
}

sub tree {

  my ($this) = @_;

  my $odoc = XML::LibXML::Document->new('1.0',"UTF-8");
  my $oelem = $odoc->createElement("kybotOut");
  $odoc->setDocumentElement($oelem);

  while (my ($sname, $h) = each %{ $this->{'docs'} }) {
    my $doc_elem = $odoc->createElement("doc");
    $doc_elem->setAttribute("shortname", $sname);
    $oelem->addChild($doc_elem);
    for (my $i = 0, my $n = scalar @{ $h->{'events'} }; $i < $n; ++$i) {
      my $elem_item = $h->{'events'}->[$i];
      $elem_item->{'elem'}->setAttribute("profile_id", join(",", keys %{ $elem_item->{'prof'} }));
      $doc_elem->addChild($elem_item->{'elem'});
      foreach my $role_item (@{ $h->{'roles'}->[$i] }) {
	$role_item->{'elem'}->setAttribute("profile_id", join(",", keys %{ $role_item->{'prof'} }));
	$doc_elem->addChild($role_item->{'elem'});
      }
    }
  }
  return $odoc;
}

sub toString {

  my ($this, $fh, $pretty) = @_;

  $fh = \*STDOUT unless defined $fh;
  binmode $fh;
  $this->tree()->toFH($fh, $pretty);
}

sub harmonize_file {

  my ($this, $doc) = @_;

  open(my $fh, $doc) || die "Can't open $doc:$!\n";
  binmode $fh;
  my $tree = $this->{'parser'}->parse_fh($fh);
  $this->harmonize_tree($tree);

}

sub harmonize_tree {

  my ($this, $prof_tree) = @_;

  foreach my $doc_elem ($prof_tree->getDocumentElement->findnodes("//doc")) {
    my $sname = $doc_elem->getAttribute("shortname");
    my $doc_struct = $this->{'docs'}->{$sname};
    unless ($doc_struct) {
      $doc_struct = &new_doc();
      $this->{'docs'}->{$sname} = $doc_struct;
    }
    &harmonize_doc($doc_elem, $doc_struct);
  }
}

sub harmonize_doc {

  my ($doc_elem, $doc_struct) = @_;

  my $events = $doc_struct->{'events'}; # array of event structs (see new_event func, %h variable)
  my $roles = $doc_struct->{'roles'}; # array of role structs (see new_role func, %h variable)
  my $eid2ev = $doc_struct->{'eid2ev'}; # { event_id (global) => event index }
  my $rid2rl = $doc_struct->{'rid2rl'}; # { role_id (global) => [target event index, role index] }
  my $tgt2eid = $doc_struct->{'tgt2eid'}; # event target tid to array of event (global) id
  my $eid2rid = $doc_struct->{'eid2rid'}; # event (global) id to array of role (global) id

  my %eid_doc2glb;		# event docId to event global_id

  # Now the roles

  $EID = $doc_struct->{'eid'};
  $RID = $doc_struct->{'rid'};

  foreach my $elem ($doc_elem->childNodes()) {
    &harmonize_event($elem, \%eid_doc2glb, $tgt2eid, $events, $eid2ev) if ($elem->nodeName eq "event");
    &harmonize_role($elem, $eid2rid, \%eid_doc2glb,  $roles, $rid2rl) if ($elem->nodeName eq "role");
  }
  $doc_struct->{'eid'} = $EID;
  $doc_struct->{'rid'} = $RID;
}

sub harmonize_event {

  my ($event_elem, $eid_doc2glb, $tgt2eid, $events, $eid2ev) = @_;

  my $doc_eid = $event_elem->getAttribute("eid");
  my $ev_tgt = $event_elem->getAttribute("target");
  my $ev_lemma = $event_elem->getAttribute("lemma");
  my $ev_synset = $event_elem->getAttribute("synset");
  my $ev_prof = $event_elem->getAttribute("profile_id");

  my $tgt_eids = $tgt2eid->{$ev_tgt};

  unless ($tgt_eids) {

    # no event referring to same target

    my ($global_eid, $h) = &new_event($ev_lemma, $ev_synset, $ev_prof, $event_elem);
    $eid_doc2glb->{$doc_eid} = $global_eid;
    $tgt2eid->{$ev_tgt} = [ $global_eid ];
    $eid2ev->{$global_eid} = scalar(@{ $events });
    push @{ $events }, $h;
    next;
  }

  # There are events referring to same target
  # check if lemma and synset are equal

  my $new_event = 1;

  foreach my $tgt_eid (@{ $tgt_eids }) {
    my $i = $eid2ev->{$tgt_eid};
    my $tgt_event = $events->[ $i ];
    next unless $ev_lemma eq $tgt_event->{lemma};
    next unless $ev_synset eq $tgt_event->{synset};
    # Same event
    $new_event = 0;
    $events->[ $i ]->{prof}->{$ev_prof} = 1;
    $eid_doc2glb->{$doc_eid} = $tgt_eid;
    last;
  }

  if ($new_event) {
    # Event doesn't match with previous
    my ($global_eid, $h) = &new_event($ev_lemma, $ev_synset, $ev_prof, $event_elem);
    $eid_doc2glb->{$doc_eid} = $global_eid;
    push @{ $tgt2eid->{$ev_tgt} }, $global_eid;
    $eid2ev->{$global_eid} = scalar(@{ $events });
    push @{ $events }, $h;
  }
}

sub harmonize_role {

  my ($role_elem, $eid2rid, $eid_doc2glb, $roles, $rid2rl) = @_;

  my $ev_docid = $role_elem->getAttribute("event");
  my $role_tgt = $role_elem->getAttribute("target");
  my $role_lemma = $role_elem->getAttribute("lemma");
  my $role_synset = $role_elem->getAttribute("synset");
  my $role_rtype = $role_elem->getAttribute("rtype");
  my $role_prof = $role_elem->getAttribute("profile_id");

  my $ev_eid = $eid_doc2glb->{$ev_docid};
  my $ev_idx = substr($ev_eid, 1) - 1;

  my $ev_rids = $eid2rid->{$ev_eid};

  unless ($ev_rids) {

    # no role referring to same event

    my ($global_rid, $h) = &new_role($role_tgt, $role_lemma, $role_synset, $role_rtype, $role_prof, $ev_eid, $role_elem);
    $eid2rid->{$ev_eid} = [ $global_rid ];
    push @{ $roles->[$ev_idx] }, $h;
    $rid2rl->{$global_rid} = [$ev_idx, scalar @{ $roles->[$ev_idx] } - 1];
    next;
  }

  # There are roles referring to same target
  # check if tgt, lemma, synset, rtype are equal

  my $new_role = 1;

  foreach my $ev_rid (@{ $ev_rids }) {
    my $ij = $rid2rl->{$ev_rid};
    my $prev_role = $roles->[ $ij->[0] ]->[ $ij->[1] ];
    next unless $role_tgt eq $prev_role->{tgt};
    next unless $role_lemma eq $prev_role->{lemma};
    next unless $role_synset eq $prev_role->{synset};
    next unless $role_rtype eq $prev_role->{rtype};

    # Same role
    $new_role = 0;
    $roles->[ $ij->[0] ]->[ $ij->[1] ]->{prof}->{$role_prof} = 1;
    last;
  }

  if ($new_role) {
    # Role doesn't match with previous

    my ($global_rid, $h) = &new_role($role_tgt, $role_lemma, $role_synset, $role_rtype, $role_prof, $ev_eid, $role_elem);
    push @{ $eid2rid->{$ev_eid} }, $global_rid;
    push @{ $roles->[$ev_idx] }, $h;
    $rid2rl->{$global_rid} = [$ev_idx, scalar @{ $roles->[$ev_idx] } - 1];
  }
}


sub new_event {

  my ($ev_lemma, $ev_synset, $ev_prof, $event_elem) = @_;

  my $global_eid = "e".$EID;
  $EID++;

  my %h;
  $h{type} = 1;
  $h{lemma} = $ev_lemma;
  $h{synset} = $ev_synset;
  $h{prof}->{$ev_prof} = 1;

  $event_elem->setAttribute("eid", $global_eid);

  $h{elem} = $event_elem;

  return ($global_eid, \%h);

}

sub new_role {

  my ($role_tgt, $role_lemma, $role_synset, $role_rtype, $role_prof, $eid, $role_elem) = @_;

  my $global_rid = "r".$RID;
  $RID++;

  my %h;
  $h{type} = 2;
  $h{tgt} = $role_tgt;
  $h{lemma} = $role_lemma;
  $h{synset} = $role_synset;
  $h{rtype} = $role_rtype;
  $h{prof}->{$role_prof} = 1;

  $role_elem->setAttribute("rid", $global_rid);
  $role_elem->setAttribute("event", $eid);

  $h{elem} = $role_elem;

  return ($global_rid, \%h);

}

1;
