#!/usr/bin/perl -w
#
# treetagger_preserving_tokens_and_lines.pl
# input is tokenised plain text one sentence per line corpus, calls treetagger sentence by sentence
# done combining tokenize4treetagger.pl and treetagger_preserving_lines.pl
# requires to create tree-tagger-notok-$lang files for each tree-tagger-$lang file commenting the lines that tokenises the input
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
# CHANGELOG
# ---------
# 20160526 use only UTF-8 tree-tagger commands
# 20121123 add support for bulgarian (now supports EN, DE, NL, BG)
# 20111114 escape character \ (treetagger drops it)
# 20110215 eos_tag depends on input language
# 20110210 created
# ---------
#

# 20111109 iconv with translit instead of ignore (was dropping characters)
# 20111108 check whether command processes utf-8
sub analyse{
	$_[0] =~ s/<[^>]*>//gs;
	print STDERR "::analyse analysing <$_[0]>\n";
	my $text_safe = escape_str($_[0]);
	my $analysis = "";

#	print STDERR "::analyse without encoding conversion\n";
	$analysis = `echo "$text_safe" | $_[1]`;

#	#print "$text_safe\n";
#	if($_[1] =~ m/utf8/){
#		print STDERR "::analyse postagging without encoding conversion\n";
#		$analysis = `echo "$text_safe" | $_[1]`;
#	} else {
#		print STDERR "::analyse postagging with encoding conversion\n";
#		#$analysis = `echo "$text_safe" | iconv -f utf-8 -t iso-8859-1//IGNORE -c | $_[1] | iconv -f iso-8859-1 -t utf-8`;
#		$analysis = `echo "$text_safe" | iconv -f utf-8 -t iso-8859-1//TRANSLIT | $_[1] | iconv -f iso-8859-1 -t utf-8//TRANSLIT`;
#	}
	#print STDERR "::analyse analysis <$analysis>\n";
	return $analysis;
}

sub escape_str{
	$ret = $_[0];
	$ret =~ s/\\/\\\\/g;
	$ret =~ s/\"/\\\"/g;
	$ret =~ s/\`/\\\`/g;
	return $ret;
}



my $lang = $ARGV[0];



#check command exists
#my $command = "tree-tagger-notok-$lang-utf8";
#my $test_command=`which $command`;
#if (length($test_command) == 0) {
#	$command = "tree-tagger-notok-$lang";
#	$test_command=`which $command`;
#	if (length($test_command) == 0) {
#		print STDERR "::main cannot find a suitable postagger command\n";
#		exit -1;
#	}
#}

$command = "tree-tagger-notok-$lang";
$test_command=`which $command`;
if (length($test_command) == 0) {
	print STDERR "::main cannot find a suitable postagger command\n";
	exit -1;
}


print STDERR "::main postagger command = $command\n";
#exit;



$eos_tag = "SENT";
if($lang eq "dutch" || $lang eq "german"){
	$eos_tag = "\$\.";
}
if($lang eq "bulgarian"){
	$eos_tag = "PT_SENT";
}

while (defined($line = <STDIN>)) {
	chomp($line);

	my @line_fields = split(/ /, $line);
	$line_fields[$#line_fields] = $line_fields[$#line_fields] . "\t" . $eos_tag;
	my $tagger_input;
	for my $f (@line_fields){
		$tagger_input .= $f . "\n";
	}


	my $analysis = analyse($tagger_input, $command);
#	$analysis =~ s/\t$eos_tag\t/\tOTHER\t/g; # overwrite any EOS tag #TODO should be done with variable but does not work, check why!
	$analysis =~ s/\tSENT\t/\tOTHER\t/g; # overwrite any EOS tag
	$analysis =~ s/\t\$\.\t/\tOTHER\t/g; # overwrite any EOS tag
	$analysis =~ s/\tPT_SENT\t/\tOTHER\t/g; # overwrite any EOS tag
	
	my @lines = split(/\n/, $analysis);
#	$lines[$#lines] =~ s/\t[^\t]*\t/\tSENT\t/; # change last tag to EOS
	$lines[$#lines] =~ s/\t[^\t]*\t/\t$eos_tag\t/; # change last tag to EOS

	for my $f (@lines){
		print $f . "\n";
	}
}
