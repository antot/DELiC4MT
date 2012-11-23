#!/usr/bin/perl -w
#
# treetagger2kaf.pl
# converts treetagger PoS output to KAF
#
# Copyright (c) 2011,
# Antonio Toral, Dublin City University
# atoral@computing.dcu.ie
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
#
# The Free Software Foundation, Inc., 
# 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307, USA.
#
#
# -------------------------------------------------------------
#
# ---------
# CHANGELOG
# 20121123 add support for bulgarian (now supports EN, DE, NL, BG)
# 20110215 preserve eos terms
# 20110215 add $. as a possible eos tag
# 20110210 created
# ---------
# TODO
# 

use strict;
use XML::LibXML;


my $usage = "perl treetagger2kaf.pl [options]\n\
options: --relative-identifiers|-ri\n";

my $opt_rids=0;

foreach my $argnum (0 .. $#ARGV) 
{
	if($ARGV[$argnum] eq "--help"){
		print $usage;
		exit;
	} elsif($ARGV[$argnum] eq "--relative-identifiers" || $ARGV[$argnum] eq "-ri"){
		$opt_rids=1;
	}
}

my $doc = XML::LibXML::Document->new( "1.0", "UTF-8" );
my $e_kaf = $doc->createElement("KAF");
my $e_text = $doc->createElement("text");
my $e_terms = $doc->createElement("terms");

$doc->setDocumentElement($e_kaf);
$e_kaf->appendChild($e_text);
$e_kaf->appendChild($e_terms);

my $line;
my $line_num = 0;
my $c_tok = 1;
my $c_sent = 1;
my $t_id = 0;
while (defined($line = <STDIN>)) {
	$line_num++;
	chomp($line);

	my @line_fields = split(/\t/, $line);
	my $line_numfields = @line_fields;
	my $f_word = $line_fields[0];
	my $f_pos = $line_fields[1];
	my $f_lemma = $line_fields[2];

	if($f_lemma eq "<unknown>" || $f_lemma eq "\@card\@") { $f_lemma = $f_word; }

# moved to the end of the loop, to preserve wf/terms for eos words
#	if($f_pos eq "SENT" || $f_pos eq "\$\."){
#		$c_sent++;
#		if($opt_rids){ $c_tok = 1; }
#		next;
#	}

	if($opt_rids){
		$t_id = $c_sent . "_" . $c_tok;
	} else {
		$t_id = $c_tok;
	}

	my $e_wf = $doc->createElement("wf");
	$e_wf->setAttribute("wid", "w$t_id");
	$e_wf->setAttribute("sent", $c_sent);
	$e_wf->setAttribute("para", "1");
	$e_wf->appendText($f_word);

	my $e_term = $doc->createElement("term");
	$e_term->setAttribute("tid", "t$t_id");
	$e_term->setAttribute("type", "open");
	$e_term->setAttribute("lemma", $f_lemma);
	$e_term->setAttribute("pos", $f_pos);
	
	my $e_span = $doc->createElement("span");
	my $e_target = $doc->createElement("target");
	$e_target->setAttribute("id", "w$t_id");

	$e_span->appendChild($e_target);
	$e_term->appendChild($e_span);
	$e_terms->appendChild($e_term);
	$e_text->appendChild($e_wf);

	$c_tok++;

	if($f_pos eq "SENT" || $f_pos eq "\$\." || $f_pos eq "PT_SENT"){
		$c_sent++;
		if($opt_rids){ $c_tok = 1; }
		next;
	}
}


print ($doc->toString(1));

