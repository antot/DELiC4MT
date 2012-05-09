#!/usr/bin/perl -w
#
# filter_checkpoints.pl
# filters out checkpoint instances based on PoS constraints from the TL
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
# 20111213 created


#inputs:

#- kybot out file:
#...
#<event eid="e1" target="t1_24" lemma="sinodo" pos="NOM" synset="" rank="" profile_id="kybot_n_a_it"/>
#<role rid="r1" event="e1" target="t1_25" lemma="patriarcale" pos="ADJ" rtype="follows" synset="" rank="" profile_id="kybot_n_a_it"/>
#...

#- alignment file:
#0-0 1-1 2-2 3-3 4-4 5-5 6-6 6-7 7-8 9-9 10-10 11-11 12-12 13-13 14-14 15-15 16-16 17-17 18-18 19-19 20-20 20-21 23-22 22-23 21-24 26-24 24-25 25-26 27-27 28-28 29-29 30-30 31-31 32-32 33-33 34-34 35-34

#- kaf file for tl:
#...
#<wf wid="w1_26" sent="1" para="1">Patriarchal</wf>
#<wf wid="w1_27" sent="1" para="1">Synod</wf>
#...
#<term tid="t1_23" type="open" lemma="of" pos="IN">
#      <span>
#        <target id="w1_23"/>
#      </span>
#    </term>
#    <term tid="t1_24" type="open" lemma="the" pos="DT">
#      <span>
#        <target id="w1_24"/>
#      </span>
#    </term>
#    <term tid="t1_26" type="open" lemma="Patriarchal" pos="NP">
#      <span>
#        <target id="w1_26"/>
#      </span>
#    </term>
#    <term tid="t1_27" type="open" lemma="Synod" pos="NP">
#      <span>
#        <target id="w1_27"/>
#      </span>
#    </term>
#...

#- conditions:
#NOM* = N*
#ADJ* = JJ*

#alignments:
#23-22 24-25 (24-23 25-26)
#sinodo patriarcale -> of Patriarchal
#sinodo -> of (ADJ = IN) !!!!!
#patriarcale -> Patriarchal (NOM = NP) OK

#contraints not fulfilled, checkpoint deleted

use strict;
use XML::LibXML;
#use File::Slurp;
use File::Slurp::Unicode;


# t1_2 -> 0
sub get_sentence_number_from_tid
{
	my $id = shift;
	my $sn;
	($sn) = $id =~ /^.{1}(.*?)_/s;
	$sn--;
	return $sn;
}

# t1_2 -> 1
sub get_wid_from_tid
{
	my $id = shift;
	my $wid;
	(undef, $wid) = split(/_/, $id);
	$wid--;
	return $wid;
}

# 0, 1 -> t1_2
sub get_tid_from_wid_sid{
	my $wid = shift;
	my $sid= shift;

	$wid++;
	$sid++;
	return "t" . $sid . "_" . $wid;
}

# checks constraints on pos. Returns 0 (false) if pos_sl == constr_sl && pos_tl != constr_tl
sub check_constraints{
	my $pos_sl = shift;
	my $pos_tl = shift;
	my $constr = shift;

	my $ret = 1;

	my @constrs = split(/;/, $constr);
	foreach my $c (@constrs){
		(my $c_sl, my $c_tl) = split(/=/, $c);
		print STDERR "\t::check_constraints $pos_sl == $c_sl && $pos_tl != $c_tl?\n";
		if ($pos_sl =~ m/^$c_sl/ && $pos_tl !~ m/^$c_tl/){
#			print STDERR "filter_checkpoints::check_constraints $pos_sl = $c_sl, $pos_tl != $c_tl\n";
			print STDERR "\t\tFailed\n";
			$ret = 0;
		}
	}

	return $ret;
}

my $usage = "perl filter_checkpoints.pl [options]\n\
options: -kybot_out file, -alignment file, -kaf_tl file, -constraints 'NOM*=N*;ADJ*=JJ*'\n";

my ($ko_f, $a_f, $kaf_f, $constr);
undef $ko_f;
undef $a_f;
undef $kaf_f;
undef $constr;


foreach my $argnum (0 .. $#ARGV) 
{
	if($ARGV[$argnum] eq "--help"){
		print $usage;
		exit;
	} elsif($ARGV[$argnum] eq "-kybot_out"){
		$ko_f = $ARGV[++$argnum];
	} elsif($ARGV[$argnum] eq "-alignment"){
		$a_f = $ARGV[++$argnum];
	} elsif($ARGV[$argnum] eq "-kaf_tl"){
		$kaf_f = $ARGV[++$argnum];
	} elsif($ARGV[$argnum] eq "-constraints"){
		$constr = $ARGV[++$argnum];
	}
}


unless(defined $ko_f && defined $a_f && defined $kaf_f && defined $constr){
	print STDERR "Error. Some mandatory variables are not defined\n";
	print STDERR "$usage";
	exit 1;
}

print STDERR "params:\n\t$ko_f\n\t$a_f\n\t$kaf_f\n\t$constr\n";

my @algs_l = read_file( $a_f ) ;

my $ko_parser = XML::LibXML->new();
my $ko_d    = $ko_parser->parse_file($ko_f) or die;
my $kaf_parser = XML::LibXML->new();
my $kaf_d    = $kaf_parser->parse_file($kaf_f) or die;


my $nl_e = $ko_d->findnodes("//*[name()='event']");
unless ($nl_e->size() > 0){
	print STDERR "filter_checkpoints::main Error no events found in kybot output file $ko_f\n";
	exit 1;
}

my $c_checkp_total = 0;
my $c_checkp_filter = 0;
my @nodes_to_delete = ();

foreach my $n_e ($nl_e->get_nodelist) {
	my @nodes_read = ();
	push( @nodes_read, $n_e );
	my @pos_sl = ();
	my @tid_sl = ();
	my @wid_sl = ();
	push( @pos_sl, $n_e->getAttribute("pos") );
	push( @tid_sl, $n_e->getAttribute("target") );
	push( @wid_sl, get_wid_from_tid( $n_e->getAttribute("target") ) );
	
	my $e_id = $n_e->getAttribute("eid");
	my $nl_r = $ko_d->findnodes("//*[name()='role' and \@event = '$e_id']");
	if ($nl_r->size() == 0){
		#print STDERR "filter_checkpoints::main Warning event $e_id has no role elements\n";
	} else {
		foreach my $n_r ($nl_r->get_nodelist) {
			push( @nodes_read, $n_r );
			push( @pos_sl, $n_r->getAttribute("pos") );
			push( @tid_sl, $n_r->getAttribute("target") );
			push( @wid_sl, get_wid_from_tid( $n_r->getAttribute("target") ) );
		}
	}


	my $sent_id = get_sentence_number_from_tid($tid_sl[0]);
#	print STDERR "sent id $sent_id from target " . $tid_sl[0] . "\n";
#	if($sent_id > 0) { exit; }

	print STDERR "filter_checkpoints::main wids_sl @wid_sl\ttids_sl @tid_sl\tpos_sl @pos_sl\n";
	my @algs = split(/ /, $algs_l[$sent_id]);
	my $c=0;
	my $failed=0;
	foreach my $alg (@algs){
		(my $alg_sl, my $alg_tl) = split(/-/, $alg);
		my( $index )= grep { $wid_sl[$_] eq $alg_sl } 0..$#wid_sl;
		if (defined $index) { # alignment found in checkpoint sl
			print STDERR "\t wid_sl $alg_sl, wid_tl $alg_tl, index in checkpoint $index\n";
			my $tid = get_tid_from_wid_sid($alg_tl, $sent_id);
#			print "$tid\n";
			my $nl_t = $kaf_d->findnodes("//*[name()='term' and \@tid = '$tid']");
			unless ($nl_t->size() > 0){
				print STDERR "filter_checkpoints::main Error no term found with tid $tid in kaf file $kaf_f\n";
				exit 1;
			}
			my $n_t = $nl_t->get_node(1);
			my $pos_tl = $n_t->getAttribute("pos");
#			print "$pos_tl\n";
			my $ret_check = check_constraints($pos_sl[$index], $pos_tl, $constr);
			if($ret_check == 0){
				$failed = 1;
			}

		}
		$c++;
	}

	if ($failed==1){
		$c_checkp_filter++;
		foreach my $node_read (@nodes_read){
			push( @nodes_to_delete, $node_read );
		}
	}
	$c_checkp_total++;
}

print STDERR "filter_checkpoints::main filtered checkpoints / total checkpoints = $c_checkp_filter / $c_checkp_total\n";


# delete filtered nodes and print XML file
my $nl_d = $ko_d->findnodes("//*[name()='doc']");
unless ($nl_d->size() > 0){
	print STDERR "filter_checkpoints::main Error no doc found in kybot output file $ko_f\n";
	exit;
}
my $n_d = $nl_d->get_node(1);
foreach my $ntd (@nodes_to_delete){
	$n_d->removeChild($ntd);
}
print ($ko_d->toString(1));





