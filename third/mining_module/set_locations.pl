

use strict;
use XML::LibXML;
use Getopt::Long;


my $kybot_out = shift; # eventoak
my $domain = shift; # datu basea
my $kyoto_home = shift; #kyoto_home


my $parser = XML::LibXML->new();
$parser->keep_blanks(0);
my $tree;
$tree = $parser->parse_file($kybot_out);


my %term_sent; #term->sent
my %sent_loc;  #sent->loc
my %lid_place; #lid->place
my %lid_term;  #lid-> entity term 


foreach my $doc_elem ($tree->getDocumentElement->findnodes("//doc")) {
    my $doc_shortname = $doc_elem->getAttribute("shortname"); 

    if (!(-e $doc_shortname)) {
	#jaitsi dbtik uneko dokumentua locationak irakurtzeko
	system "perl $kyoto_home/doc_dump.pl --container-name $domain --internal-format $doc_shortname";
    }	
    # parseatu jaitsitako kaf fitxategia
    my $parser2 = XML::LibXML->new();
    $parser2->keep_blanks(0);
    my $tree2;
    $tree2 = $parser2->parse_file($doc_shortname);
    
    foreach my $sents ($tree2->getDocumentElement->findnodes("/KAF2/para/sentence")) {
	my $sent_id = $sents->getAttribute("num");
	#foreach my $term ($sents->find("/terms/term")->get_node(1)) {
	#    next unless defined $term;
	foreach my $terms ($sents->childNodes()) {
	    if ($terms->nodeName eq "terms") {
		foreach my $term ($terms->childNodes()) {
		    my $term_id = $term->getAttribute("tid");
		    $term_sent{$term_id} = $sent_id;
		}
	    }
	}
    }
    
    foreach my $location ($tree2->getDocumentElement->findnodes("/KAF2/locations/location")) {
	my $lid = $location->getAttribute("lid");
	foreach my $loc_child ($location->childNodes()) {
	    if ($loc_child->nodeName eq "geoInfo") {
		foreach my $place ($loc_child->childNodes()) {
		    $lid_place{$lid} = $place; 
		}
	    }
	    elsif ($loc_child->nodeName eq "kafReferences") {
		foreach my $kafref ($loc_child->childNodes()) {
		    foreach my $span ($kafref->childNodes()) {
			my $span_id = $span->getAttribute("id");
			$sent_loc{$term_sent{$span_id}} = $lid; 
			$lid_term{$lid}{$term_sent{$span_id}} = $span;
		    }
		}
	    }
	}
    }    
    
    foreach my $event_role ($doc_elem->childNodes) {
	my $target = $event_role->getAttribute("target");
	if (exists($sent_loc{$term_sent{$target}})) { 
	    my $target_location = ($lid_place{$sent_loc{$term_sent{$target}}})->cloneNode(1);#->toString();
	    my $span_clone = ($lid_term{$sent_loc{$term_sent{$target}}}{$term_sent{$target}})->cloneNode(1);
	    $target_location->addChild($span_clone);
	    $event_role->addChild($target_location);
	}
    }
}

my $treelag = $tree->toString(1)."\n";

print $treelag;




