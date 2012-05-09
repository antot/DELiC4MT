#!/usr/bin/perl -w
#
# stat_sig.pl
# checks for statistically significance between two system runs
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
# 20110311 created


# code from http://community.livejournal.com/perl/101830.html
sub fisher_yates_shuffle {
    my $array = shift;
    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}


sub is_a_better_b {
	my $array = shift;
	my $i_a = 0;
	my $i_b = 0;
	foreach my $e (@$array){
		my @fs = split(/#/, $e);
		my $a = $fs[0];
		my $b = $fs[1];
		$i_a += $a;
		$i_b += $b;
	}
#	print STDERR "ter_sig::is_a_better_b a=$i_a b=$i_b\n";
	if ($i_a > $i_b) { return 1; }
	return 0;
}

sub bootstrap {
	my ($vs_ref, $times_iter, $ratio_iter) = @_;
	# De-reference the array list
	my (@vs) = @$vs_ref;
#	print ("$#vs\n");
	my $lines = $#vs + 1;
	my $iters = $lines*$times_iter;
	my $elems = $lines*$ratio_iter;
	my $a_better = 0;
	#$iters=5;
	print STDERR "stat_sig::bootstrap Num results: $lines, times iterations: $times_iter, num elements per iteration: $ratio_iter\n";
	print STDERR "stat_sig::bootstrap Randomised bootstrapping $iters iterations with $elems elements\n";
	@vsc = @vs;
	for ($i = 0; $i < $iters; $i++) {
		@vs = @vsc;
		fisher_yates_shuffle(\@vs);
		my @ivs = @vs[0..$elems-1];
#		print STDERR "ter_sig::main iteration $i vector size $#ivs+1\n";
		my $res = is_a_better_b(\@ivs);
		if ($res) { $a_better++; }
	}

	my $ratio = ($a_better / $iters)*100;
	print STDERR "stat_sig::bootstrap System a better than b in $a_better iterations out of $iters, i.e. $ratio%\n";
}

1;



