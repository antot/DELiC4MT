#!/usr/bin/perl -w
#
# lingcheckp_sig.pl
# checks for statistically significance between two Linguistic Checkpoint runs
#
# Copyright (c) 2010-11,
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
# 20110322 avoid division by 0 error when doing $fsa[0] / $fsa[1]
# 20110311 created

use FindBin;
use lib "$FindBin::Bin/";
require "stat_sig.pl";


my $usage = "usage: lingcheckp_sig.pl output_system_a output_system_b [times_iter [ratio_iter]]\n";
my $times_iter = 5;
my $ratio_iter = 0.3;

if ($#ARGV < 1){
	print $usage;
	exit;
}

my $fia = $ARGV[0];
my $fib = $ARGV[1];
if ($#ARGV > 1){ $times_iter = $ARGV[2]; }
if ($#ARGV > 2){ $ratio_iter = $ARGV[3]; }


print STDERR "\nlingcheckp_sig::main Calculating statistical significance between outputs $fia and $fib\n";

open fi_a, $fia or die "lingcheckp_sig::main Couldn't open file: $!";
open fi_b, $fib or die "lingcheckp_sig::main Couldn't open file: $!";

my ($la, $lb, $fa, $fb);
my (@fsa, @fsb, @vs, @vsc);
my $c_lines = 0;

while (1){
	$la = <fi_a>;
	$lb = <fi_b>;
	while ($la && $la !~ m/^matching n-grams/) { $la = <fi_a>; }
	while ($lb && $lb !~ m/^matching n-grams/) { $lb = <fi_b>; }

	if( (!$la && $lb) || ($la && !$lb) ){
		print STDERR "lingcheckp_sig::main Error. Input files do not have the same number of lines\n";
		exit 1;
	}
	if (!$la && !$lb) { last; }

	$c_lines++;
	chomp($la);
	chomp($lb);

	@fsa = split(/=/, $la);
	@fsa = split(/\//, pop (@fsa));
	if ($fsa[1] == 0) {
		$fa = 0;
	} else {
		$fa = $fsa[0] / $fsa[1];
	}
#	print "$fa\n";
#	exit;

	@fsb = split(/=/, $lb);
	@fsb = split(/\//, pop (@fsb));
	if ($fsb[1] == 0) {
		$fb = 0;
	} else {
		$fb = $fsb[0] / $fsb[1];
	}

#	print STDERR "$fa\t$fb\n";
	push(@vs, $fa . "#" . $fb);
}
close fi_a;
close fi_b;

#print "$c_lines $#vs+1\n";

bootstrap (\@vs, $times_iter, $ratio_iter);

