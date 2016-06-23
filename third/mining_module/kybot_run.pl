#!/usr/bin/perl

use Sleepycat::DbXml 'simple';
use strict;
use XML::LibXML;
use Data::Dumper;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin";
use File::Temp qw/ tempfile tempdir /;
use File::Basename;

require KybotLib;
require Harmonizer;

binmode STDOUT;

#
# usage
#

sub usage {

  print STDERR "USAGE: $0 [ --dry-run ] [ --profile-from-disk ] [ --container-name cont_name ] [ --kybot-container-name cont_name ] kybot_profile1 kybot_profile2 ...\n";
  print STDERR "\t--container-name name of the document container. If ommited, use default container defined in kyoto.conf.pl\n";
  print STDERR "\t--dry-run display results on the screen (default: yes). Do not touch the documents.\n";
  print STDERR "\t--set-ent (default: no). Adds locations and temporal entities to the output (same as setting both --set-loc and --set-date).\n";
  print STDERR "\t--set-loc (default: no). Adds location entities to the output.\n";
  print STDERR "\t--set-date (default: no). Adds temporal entities to the output.\n";
  print STDERR "\t--profile-from-disk read the kybot profile from disk instead of the database (default: yes). Implies --dry-run.\n";
  print STDERR "\t--profile-from-db read the kybot profile from the database (default: no).\n";
  print STDERR "\t--kybot-container-name name of the kybot container. If ommited, use default kybot container defined in kyoto.conf.pl\n";
  exit 1;
}

#
# set default values
#

require "kyoto.conf.pl";
our $KYOTO_HOME;
our $DBXML_ENV_PATH;
our $DBXML_DEFAULT_CONTAINER_NAME;
our $DBXML_KYBOT_DEFAULT_CONTAINER_NAME;
my $container_name = $DBXML_DEFAULT_CONTAINER_NAME;
my $kybot_container_name = $DBXML_KYBOT_DEFAULT_CONTAINER_NAME;

#
# parse parameters
#

my %args = ();
my ($arg_help, $arg_dry_run, $arg_profile_from_disk, $arg_profile_from_db, $arg_container_name, $arg_kybot_container_name, $arg_debug, 
    $arg_set_date, $arg_set_loc, $arg_set_ent);
GetOptions(
	   'help'       => \$arg_help,
	   'dry-run'    => \$arg_dry_run,
	   'profile-from-disk' => \$arg_profile_from_disk,
	   'profile-from-db' => \$arg_profile_from_db,
	   'container-name=s' => \$arg_container_name,
	   'kybot-container-name=s' => \$arg_kybot_container_name,
	   'debug' => \$arg_debug,
	   'set-loc' => \$arg_set_loc,
	   'set-date' => \$arg_set_date,
	   'set-ent' => \$arg_set_ent
	  );

if ($arg_help) {
  &usage();
}

if($arg_set_ent) {
  $arg_set_loc = 1;
  $arg_set_date = 1;
}

my @profiles = @ARGV;

die "ERROR: no profiles!\n" unless @profiles;

if ($arg_container_name ne "") {
  $container_name = $arg_container_name;
}

if ($arg_kybot_container_name ne "") {
  $kybot_container_name = $arg_kybot_container_name;
}

KybotLib::rmEnvFiles("${KYOTO_HOME}/${DBXML_ENV_PATH}");

#
# open dbxml manager
#

my $mgr;
my $env;

eval {

  $env = new DbEnv;
  $env->open($KYOTO_HOME."/".$DBXML_ENV_PATH,Db::DB_CREATE|Db::DB_INIT_LOCK|Db::DB_INIT_LOG|Db::DB_INIT_MPOOL|Db::DB_INIT_TXN, 0);
  $mgr = new XmlManager($env, 0);

};

if (my $e = catch XmlException) {
  die $e->what();
}

if (!$arg_profile_from_db) {
  $arg_profile_from_disk = 1;
  $arg_dry_run = 1;
}

if ($arg_profile_from_disk && !$arg_dry_run) {
  die "ERROR: You must use '--dry-run' option with '--profile-from-disk'\n";
}

my $xmlParser = XML::LibXML->new(); # global variable (XML parser)
$xmlParser->keep_blanks(0);

my @res_array;

foreach my $profile_name (@profiles) {
  if ($arg_profile_from_disk) {
    unless (-f $profile_name) {
      print STDERR "Warning: Cannot open $profile_name. Skiping.\n";
      next;
    }
    my $tree;
    eval {
      open(my $fh, "$profile_name") || die;
      binmode $fh;
      $tree = $xmlParser->parse_fh($fh);
    };
    unless ($tree) {
      print STDERR "Warning: Cannot parse $profile_name. Skiping.\n";
      next;
    }
    &exec_profile($mgr, $tree, \@res_array);
  } else {
    my $profile = &get_profile_db($mgr, $kybot_container_name, $profile_name);
    my $tree;
    $tree = $xmlParser->parse_string($profile);
    &exec_profile($mgr, $tree, \@res_array);
  }
}

my $result_tree = &build_result_tree(\@res_array);

if ($arg_dry_run) {

  my $bresult_tree = XML::LibXML::Document->new();
  my $bresult_elem = $bresult_tree->createElement("kybotOut");
  $bresult_tree->setDocumentElement($bresult_elem);

  foreach my $bdoc ($result_tree->getDocumentElement->getChildrenByTagName("doc")) {
    my $bdoc_elem = $bresult_tree->createElement("doc");
    $bdoc_elem->setAttribute("name", ($bdoc->getAttribute("name")));
    $bdoc_elem->setAttribute("shortname", $bdoc->getAttribute("shortname"));

    foreach my $bnodes ($bdoc->getChildrenByTagName("events")) {
      my @bchildren = $bnodes->childNodes();
      my $bevent = 0;
      my $brole = 0;

      foreach my $child (@bchildren) {
	if ($child->nodeName eq "event") {
	  $bevent++;
	  $child->setAttribute("eid","e$bevent");
	}
	if ($child->nodeName eq "role") {
	  $brole++;
	  $child->setAttribute("event","e$bevent");
	  $child->setAttribute("rid","r$brole");
	}
	# if not event or role, just append to output
	$bdoc_elem->appendChild($child);
      }
    }
    $bresult_elem->addChild($bdoc_elem);
  }

  my $harm_tree = &harmonize_bresult($bresult_tree);

  my $ftmp;# = new File::Temp();
  if (!$arg_set_loc && !$arg_set_date) {
    $harm_tree->toFH(\*STDOUT, 1);
  } else {
    my $setent_opts;
    $setent_opts .= " -d" unless $arg_set_date;
    $setent_opts .= " -l" unless $arg_set_loc;

    $ftmp = new File::Temp();
    $harm_tree->toFH($ftmp, 1);
    $ftmp->close();
    system "perl $KYOTO_HOME/set_entities.pl $setent_opts $ftmp $container_name $KYOTO_HOME";
  }
}
else {
    &update_db($mgr, $container_name, $result_tree);
}

sub harmonize_bresult {
  my ($bresult_tree) = @_;

  my $harm = new Harmonizer;
  $harm->harmonize_tree($bresult_tree);
  return $harm->tree();

}


sub exec_profile {

  my ($mgr, $tree, $result_array) = @_;

  my $xquery = &build_xquery_from_profile($tree);
  print STDERR "$xquery\n" if $arg_debug;
  &exec_query($mgr, $container_name, $xquery, $result_array);

}


sub get_profile_db {

  my ($mgr, $container_name, $profile_name) = @_;

  my $container;
  my $profile;

  $container = KybotLib::openContainer($mgr, $container_name);
  die "Kybot container \'$container_name\' does not exist.\n" unless defined $container;

  eval {
    $profile = $container->getDocument($profile_name);
  };

  if (my $e = catch XmlException) {
    die $e->what();
  }
  return $profile;
}

##### parsing

#
# build xquery for kybot-profile
#

sub add_functions { # insert xquery function declarations at the begining of the xquery.
  my $xquery = shift;

  #my $same_sentence_funct =
  #  "declare function local:same_sentence (\$t as element()) as element()+
#{\n\$t/parent::node()/*[not (\@tid = \$t/\@tid)]\n };\n";

 

  my $index_of_node_function = "declare namespace functx = \"http://www.functx.com\";\n
declare function functx:index-of-node ( \$nodes as node()* ,\n \$nodeToFind as node() )  as xs:integer* {      
  for \$seq in (1 to count(\$nodes))
  return \$seq[\$nodes[\$seq] is \$nodeToFind]
 } ;\n";
  



my $not_in_between_function = "declare function local:notInBetweenF(\$x as item()*, \$arg1 as item()*, \$arg2 as item()*) as node()* {
if (count(\$arg2) = 0) then (\$arg1[1])
else
   if (count(\$arg1) = 0) then ()
   else
     if (functx:index-of-node(\$x, \$arg1[1])  <= functx:index-of-node(\$x,\$arg2[1])) then  (\$arg1[1])
     else ()
}\n;

declare function local:notInBetweenP(\$x as item()*, \$arg1 as item()*, \$arg2 as item()*) as node()* {
if (count(\$arg2) = 0) then (\$arg1[last()])
else
   if (count(\$arg1) = 0) then ()
   else
     if (functx:index-of-node(\$x, \$arg1[last()])  >= functx:index-of-node(\$x,\$arg2[last()])) then  (\$arg1[last()])
     else ()
}\n;";




 return ("$index_of_node_function$not_in_between_function$xquery");
}

sub check_dependencies {
    
    my $xquery = shift;
    my @splittedxq = split(/\n/, $xquery);
    
    my %defined;
    my %defined2;
    my %required;
    
    my $counter = 0;

    for (my $i = 0; $i<=$#splittedxq; $i++) { 
	if ($splittedxq[$i] =~ /^for / ||  $splittedxq[$i] =~ /^let /) { 
	    $counter = 0;
	    while ($splittedxq[$i]=~ m/\$([a-zA-Z0-9\.\-]+)/g) {
		if ($counter == 0) {
		    if ($i-1>=0) {
			$defined{$i} = " $1 ".$defined{$i-1};
			$defined2{$1} = $i;
		    }
		    else { 
			$defined{$i} = " $1 ";
			$defined{$2} = $i;
		    }
		    $counter = 1;
		}
		else {
		    $required{$i}.= " $1 ";
		    $counter++;
		    my $req = $1;
		    if (!($defined{$i} =~ m/ $req /)) {
			# errorea dago $1 aldagaiarekin
			print STDERR "Unknown variable: \$$1\n";
			print STDERR "Please, check variable definitions and relations (root)\n";
			exit(1);
		    }
		}
		#$splittedxq[$i]= s/\$[a-zA-Z0-9\.\-]+//;
	    }
	}
    }
    return $xquery;
}
#    # check dependencies
#    my $lag;
#    my @correct;
#    my @result;
#    my $index=0;
#    my @beklag;
#    for ($lag = 0; $lag <= $counter; $lag++) {
#	if ($required{$lag} =~ /(\S+)/) { # hemen bat bakarrik izan beharrean mila izan daitezke....
#	    #my $req = $1;
#	    if ($defined{$lag}=~ / $required{$lag}/) {
#		#ez dago arazorik
#		$result[$index] = $splittedxq[$lag];
#		$index++;
#	    
#		for (my $kk=0; $kk<=$#beklag; $kk++) {
#		    my $elem = $beklag[$kk];
#		    if ($elem >= 0) {
#			if ($defined{$elem}=~ /$required{$lag}/) {
#			    #ez dago arazorik
#			    $result[$index] = $splittedxq[$lag];
#			    $index++;
#			    $beklag[$kk] = -1;
#			}
#		    }
#		}
#	    }
#	    else {
#		# arazoa dago dependentziekin
#		push(@beklag, $lag);
#	    }
#	}
#    }
#}


sub add_counters {

  my $xquery = shift;
  my @splittedxq = split(/\n/, $xquery);
  my $i;
  my $lindex = 0;

  for ($i = 0; $i<=$#splittedxq;$i++) {
    if ($splittedxq[$i] =~ /^for /) {
      if ($lindex > 0) {
	$splittedxq[$i] =~ s/^(for \S+)/$1 at \$count$lindex/;
	$lindex++;
      } else {
	$lindex++;
      }
      # same sentence
      #if ($lindex == 2) { # 2. for-ean gehitu same-sentence osagaia (horretarako ezabatu following-sibling eta antzekoak)
      #   $splittedxq[$i] =~ s/^(for \S+\s+at\s+\$count\S+\s+\in)\s(\$[^\/]+)\S+(\[[^\]]+\])$/$1 local:same_sentence($2)$3/;
      #}
    }
  }
  $xquery = join ("\n",@splittedxq,"\n");
  return $xquery;
}


sub add_generic_variables { #generic kybots, generic variables
    my $xquery = shift;
    my $generic_variables = shift;
    my %hash = %$generic_variables;
    
    my $refvariable;
    my $refattribute;
        
    my @splittedxq;
    my @splittedxq2;
    my $t = -1;
    my $i;
    my $lindex = 0;
    
    my $lag;

    foreach my $elem (keys(%hash)) {
	if ($elem =~ /^(\S+)\.(\S+)/) {
	    $refvariable = $1;
	    $refattribute = $2;
	}
	
	@splittedxq = split(/\n/, $xquery);
	
	for ($i = 0; $i<=$#splittedxq;$i++) {
	    if ($splittedxq[$i] =~ /^for\s+\$$refvariable /) {
		$t++;
		$splittedxq2[$t] = $splittedxq[$i];
		
		if ($splittedxq[$i] =~ /(externalRef\[[^\]]+\])/) {
		    $lag = $1;
		    #add: generic value
		    $t++;
		    $splittedxq2[$t] = "let \$".$elem." := substring(\$".$refvariable."//".$lag."/\@".$refattribute.",1)";
		    #let $C := substring($B//externalRef[(@reftype="DOLCE-Lite.owl#participant-in")]/@reference,1)
		}
	    }
	    else {
		$t++;
		$splittedxq2[$t] = $splittedxq[$i];
	    }
	}
	$t = -1;
	$xquery = join ("\n",@splittedxq2,"\n");
	@splittedxq2 = ();
	@splittedxq = ();
    }

    return $xquery;

}    


sub check_external_refs { ## synsets ##

    my $xquery = shift;
    my $external_hash = shift;
    my @splittedxq = split(/\n/, $xquery);
    
    for (my $i = 0; $i<=$#splittedxq;$i++) {
	if ($splittedxq[$i] =~ /^for\s+\$(\S+) .*\.\/externalReferences(\/\/externalRef\[[^\]]+\])/) {
	    
	    $external_hash->{$1}=".".$2;
	}
    }
}


sub add_generic_relations { #generic kybots, generic variables
    my $xquery = shift;
    my $generic_relations = shift;
    my %hash = %$generic_relations;
    
    my $refvariable;
    my $refattribute;
    
    my @splittedxq;
    my @splittedxq2;
    my $t = -1;
    my $i;
    my $lindex = 0;
    
    my $lag;

    my $notdeclared = "FALSE";
    
    foreach my $elem (keys(%hash)) {

	if ($elem eq "0") { # perl bug-a??
	    next;
	}

	$refattribute = $hash{$elem};
	if ($elem =~ /^(\S+)\.ref/) {
	    $notdeclared = "TRUE";
	    $elem = $1;
	}
	$refvariable = $elem;
	
	
	
	@splittedxq = split(/\n/, $xquery);
	
	for ($i = 0; $i<=$#splittedxq;$i++) {
	    if ($splittedxq[$i] =~ /^for\s+\$$refvariable /) {
		if ($notdeclared eq "TRUE") {
		    $t++;
		    $splittedxq2[$t] = $splittedxq[$i];
		    $t++; #add let Y.refe := ...
		    $splittedxq2[$t] = $refattribute;
		}
		else { 		    
		    
		    if ($splittedxq[$i] =~ /externalRef\[/) { 
			if ($refattribute =~ /externalRef\[([^\]]+)\]/) {
			    my $auxadd = $1;
			    $splittedxq[$i] =~ s/externalRef\[([^\]]+)\]/exteralRef\[$1 and $auxadd\]/;
			    $t++;
			    $splittedxq2[$t] = $splittedxq[$i];
			}
		    }
		    else { 
			if ($splittedxq[$i] =~ /\][\)]*$/) { 
			    $splittedxq[$i] =~ s/\]([\)]*)$/and $refattribute\]$1/;
			    $t++;
			    $splittedxq2[$t] = $splittedxq[$i];
			}
			#else !!
		    }
			
		}
	    }
	    else {
		$t++;
		$splittedxq2[$t] = $splittedxq[$i];
	    }
	}
	$t = -1;
	$xquery = join ("\n",@splittedxq2,"\n");
	@splittedxq2 = ();
	@splittedxq = ();
	$notdeclared = "FALSE";
    }

    return $xquery;

}    

sub build_xquery_from_profile {

  my ($tree) = @_;

  my $xmlroot = $tree->getDocumentElement;
  my %varhash;
  my %vartype;

  #generic kybots
  my %generic_variables = ();

  #generic kybots (2º mode)
  my %generic_relations = ();
  
  # synsets
  my %external_hash = ();
      


  &parse_variables($xmlroot, \%varhash, \%vartype, \%generic_variables);

  my ($rootpivot, $rootexp1, $rootexp2, $var_pool, $var_opt, $last_var) = &parse_relations($xmlroot, \%varhash, \%vartype, \%generic_relations);

  # reconstruct %Parsed

  my $parsed = &parse_pool($rootpivot, $rootexp1, $rootexp2, $var_pool);

  my $xquery = &print_xquery_for($parsed);

  
  #$xquery = &add_counters($xquery);
  
  $xquery = &add_generic_variables($xquery,\%generic_variables);

  $xquery = &add_generic_relations($xquery,\%generic_relations);

  &check_external_refs($xquery,\%external_hash); # generate ext_hash to obtain synset information

  $xquery = &check_dependencies($xquery);

  $xquery = &add_counters($xquery);
  
  if (scalar (@{ $var_opt }) ) {
    push @{ $var_opt }, $last_var;
    $xquery .= 'for $AUX in $'.join(' | $',@{ $var_opt })."\n";
    #print 'for $AUX in $'.join(' | $',@var_opt)."\n";
  }
  $xquery.= &get_xquery_return2($xquery);
  $xquery.= &get_xquery_return($xmlroot, $rootpivot,\%external_hash);

  #add else()
  if ($xquery =~ /if \(\$count/) {
    $xquery .= "else()\n";
  }

  $xquery = &add_functions($xquery);

  return $xquery;

}

sub parse_pool {

  my ($varname, $varexp1, $varexp2, $pool) = @_;

  my $elem = {name => $varname, expr1 => $varexp1, expr2 => $varexp2, dep => []};
  return $elem unless defined $pool->{$varname};
  foreach my $depvar (@{ $pool->{$varname} }) {
    push @{ $elem->{dep} }, &parse_pool($depvar->{name}, $depvar->{expr1}, $depvar->{expr2}, $pool);
  }
  return $elem;
}

sub parse_variables {
    
    my ($xmlroot, $varhash, $vartype, $generic_variables) = @_;
    
    my %vh = ();
    
    foreach my $var ($xmlroot->findnodes('/Kybot/variables/var')) {
	
	my @attributes = $var->attributes();
	my $varname="";
	my $type="";
	my $path="";
	
	my $cattributes = 0; # count number of attri. != name ^ !=type
	
	foreach my $attr (@attributes) {
	    my $attr_name = "@".$attr->getName();
	    
	    if ($attr_name eq '@name') {
		$varname = $var->findvalue($attr_name);
	    } 
	    elsif ($attr_name eq '@type') {
		$type = $var->findvalue($attr_name);
	    } 
	    else {
		my @values = split (/ \| /,$var->findvalue($attr_name));
		
		$attr_name=~s/sense$/reference/;
		
		for (my $i=0;$i<=$#values;$i++) {
		    my $not_pre="";
		    my $not_pos="";
		    
		    $cattributes++;
		    
		    if ($values[$i]=~/^! /) {
			$not_pre="not(";
			$not_pos=")";
			$values[$i]=~s/^! //;
		    }
		    if ($values[$i]=~/^\*/) {
			$values[$i]=~s/^\*//;
			$values[$i]=$not_pre.'ends-with('.$attr_name.',"'.$values[$i].'")'.$not_pos;
		    } 
		    elsif ($values[$i]=~/\*$/) {
			$values[$i]=~s/\*$//;
			$values[$i]=$not_pre.'starts-with('.$attr_name.',"'.$values[$i].'")'.$not_pos;
		    } 
		    else {
			$values[$i]=$not_pre.$attr_name.'="'.$values[$i].'"'.$not_pos;
		    }
		    if ( ($attr_name eq "\@reference") || ($attr_name eq "\@reftype") ||($attr_name eq "\@status") ) {
			if ($values[$i] =~ /^$attr_name=\"VAR\"/) {
			    if ($attr_name =~ /\@(\S+)/) {
				$generic_variables->{"$varname.$1"} = "VAR";
				$values[$i] = "";
			    }
			}
			elsif ($values[$i] =~ /^$attr_name=\"([^\#]+\.[^\#]+)\"/) { # generic kybots: varibale being filled.
			    $values[$i]="./externalReferences//externalRef[".$attr_name."=\$".$1."]";
			}
			    
			else { #VAR bada, generikoa da
			    $values[$i]="./externalReferences//externalRef[".$values[$i]."]";
			}
		    }
		}
		
		if ($path eq "") {
		    foreach my $null_values (@values) {
			if ($null_values =~ /\S/) {
			    if ($path =~ /\S/) {
				$path .= " or ".$null_values;
			    } 
			    else {
				$path = "(".$null_values;
			    }
			}
		    }
		    if ($path ne "") {
			$path .= ")";
		    }
		}
		    
		# $path = '('.join(" or " ,@values).')';

	    
		else {
		    my $auxpath;
		    foreach my $null_values (@values) {
			if ($null_values =~ /\S/) {
			    if ($auxpath =~ /\S/) {
				$auxpath .= " or ".$null_values;
			    } 
			    else {
				$auxpath = "(".$null_values;
			    }
			}
		    }
		    if ($auxpath ne "") {
			$auxpath .= ")";
			$path = $path.' and '.$auxpath;
		    }
		    
		    #$path = $path.' and ('.join(" or " ,@values).')';
		}
		while (1) {
		while (1) {
		    $path =~ s/(\(\.\/externalReferences\/\/externalRef\[)([^\]]+)\]\) and \(\.\/externalReferences\/\/externalRef\[([^\]]+)\]\)/$1($2) and ($3)])/;
		    $path =~ s/(\(\.\/externalReferences\/\/externalRef\[)([^\]]+)\]\) and ([\s\S]+) and \(\.\/externalReferences\/\/externalRef\[([^\]]+)\]\)/$3 and $1($2) and ($4)])/;
		    if (!($path =~ /(externalRef\[[^\]]+)\]\) and \(\.\/externalReferences\/\/externalRef\[([^\]]+\]\))/)) {
			if (!($path =~ /(\(\.\/externalReferences\/\/)(externalRef\[[^\]]+)\]\) and ([\s\S]+) and \(\.\/externalReferences\/\/externalRef\[([^\]]+\]\))/)) {
			    last;
			}
		    }
		}
		while (1) {
		    $path =~ s/(\(\.\/externalReferences\/\/externalRef\[[^\]]+)\] or \.\/externalReferences\/\/externalRef\[([^\]]+)\]/$1 or $2]/;
		    if (!($path =~ /\(\.\/externalReferences\/\/externalRef\[[^\]]+\] or \.\/externalReferences\/\/externalRef\[[^\]]+\]/ )) {
			last;
		    }
                }
                if ((!($path =~ /\(\.\/externalReferences\/\/externalRef\[[^\]]+\] or \.\/externalReferences\/\/externalRef\[[^\]]+\]/ )) and (!($path =~ /(externalRef\[[^\]]+)\]\) and \(\.\/externalReferences\/\/externalRef\[([^\]]+\]\))/)) and (!($path =~ /(\(\.\/externalReferences\/\/)(externalRef\[[^\]]+)\]\) and ([\s\S]+) and \(\.\/externalReferences\/\/externalRef\[([^\]]+\]\))/))) {last;}
              }
            }
	}
	
	#  die "ERROR: Malformed variable.\n" unless ($varname ne "" && $varvalue ne "");
	
	## subclass-type

	$path =~ s/(\/\/externalRef\[[^\]]*\@reftype=\"SubClassOf)-type\"/\/externalRef\[\@reftype=\"sc_domainOf\" or \@reftype=\"sc_hasCoRole\" or \@reftype=\"sc_equivalentOf\" or \@reftype=\"sc_subclassOf\"\]$1\"/;
	


	if ($cattributes == 1) { # negacion general... solo para externalRefs
	    if ($path =~ /(\(\.\/externalReferences\/\/externalRef\[)not(\(.*)/) {
		$path = "count$1$2=0";
	    }
	}
	
	if (exists($vh{$varname})) { # multiple variable declaration
	    my $mpath = $varhash->{$varname};
	    $mpath =~ s/^\[(.*)\]$/\[$1 and $path\]/;
	    $varhash->{$varname} = $mpath;
	}
	else{    
	    if ($path =~ /\S+/) {
		$vartype->{$varname} = $type;
		$varhash->{$varname} = '['.$path.']';
	    
		$vh{$varname} = "OK"; # for multiple variable declaration 2010-IV-23
	    }
	}
    }
}


sub parse_relations {

    my ($xmlroot, $varhash, $vartype, $generic_relations) = @_;
    
    my $Parsed = {}; # { name => "varname", expr => "expresion", dep => [ $parsed1, $parsed2, ...] }
    
    my @root = $xmlroot->findnodes('/Kybot/relations/root');
    
    die "ERROR: 0 or >1 root elem\n" unless @root == 1;
    
    my $rootpivot = $root[0]->findvalue('@span');
    die "root pivot not found\n" unless defined $varhash->{$rootpivot};
    my $rootexp1 = 'for $';
    my $rootexp2 = ' in collection()//'.$vartype->{$rootpivot}.$varhash->{$rootpivot};
    my %var_pool;			# key is pivot var!
    
    my @var_opt=();
    my $last_var="";

    foreach my $var ($xmlroot->findnodes('/Kybot/relations/rel')) {
	
	my $span = $var->findvalue('@span');
	my $pivot = $var->findvalue('@pivot');
	my $direction = $var->findvalue('@direction');
	# my $dist = $var->findvalue('@dist');
	my $immediate = $var->findvalue('@immediate');
	my $opt = $var->findvalue('@opt');

	my $inBetween = $var->findvalue('@notInBetween');
	
	## generic kybots (2010-VI-21)
	## my $pred = $var->findvalue('@pred');
	## my $filler = $var->findvalue('@filler');

	die "ERROR: Malformed relation elem.\n" unless ($span ne "" && $pivot ne "" && $direction ne "");
	die "ERROR: Variable used without declaring it first: ".$pivot."\n" unless defined $varhash->{$pivot};
	
	my $velem;
	#  my $expr_aux = '$'.$pivot."/".$direction."-sibling::".$vartype->{$span}."[".$dist."]".$varhash->{$span};
	
	my $expr_aux;


	# check "inBetween" constraint
	if ($inBetween =~ /\S+/) {
	    if ($direction eq "preceding") {		
		$expr_aux = "reverse("."local:notInBetweenP(" . '$'.$pivot."/".$direction."-sibling::".$vartype->{$span}.",".'$'.$pivot."/".$direction."-sibling::".$vartype->{$span}.$varhash->{$span}.",".'$'.$pivot."/".$direction."-sibling::".$vartype->{$span}.$varhash->{$inBetween}."))";
	    }
	    else {
		$expr_aux = "("."local:notInBetweenF(" . '$'.$pivot."/".$direction."-sibling::".$vartype->{$span}.",".'$'.$pivot."/".$direction."-sibling::".$vartype->{$span}.$varhash->{$span}.",".'$'.$pivot."/".$direction."-sibling::".$vartype->{$span}.$varhash->{$inBetween}."))";
	    }		
	}
	else {

	    # check search direction
	    if ($direction eq "preceding") {
		$expr_aux = "reverse(".'$'.$pivot."/".$direction."-sibling::";
	    }
	    else {
		$expr_aux ="(". '$'.$pivot."/".$direction."-sibling::";
	    }
	    
	    if ($immediate eq "true") {
		$expr_aux .= "*[1]";
	    } 
	    else {
		$expr_aux .= $vartype->{$span};
	    }
	    $expr_aux = $expr_aux.$varhash->{$span}.")";
	}
	
	foreach my $vopt (@var_opt) { 
	    # never done?
	    #$expr_aux = $expr_aux.' | $'.$vopt."/".$direction."-sibling::".$vartype->{$span}."[".$dist."]".$varhash->{$span};
	    # check search direction
	    if ($direction eq "preceding") {
		$expr_aux = $expr_aux.' | reverse($'.$vopt."/".$direction."-sibling::".$vartype->{$span};
	    }
	    else {
		$expr_aux = $expr_aux.' | ($'.$vopt."/".$direction."-sibling::".$vartype->{$span};
	    }
	    if ($immediate eq "true") {
		$expr_aux = $expr_aux."[1]";
	    }
	    $expr_aux = $expr_aux.$varhash->{$span}.")";
	}
	
	if ($opt eq "true") {
	    $velem = { name => $span, expr1 => 'let $',  expr2 =>  ' := '.$expr_aux};
	    $last_var = $span;
	    push @var_opt, $pivot;
	} 
	else {
	    $velem = { name => $span, expr1 => 'for $',  expr2 =>  ' in '.$expr_aux};
	    @var_opt=();
	}
	push @{ $var_pool{$pivot} }, $velem;
    }
    
    # generic kybots -> 2. modua: erlazioak relations atalean azaltzen dira...

    foreach my $var ($xmlroot->findnodes('/Kybot/relations/predicate')) {
	my $pname = $var->findvalue('@name');
	my $pevent = $var->findvalue('@event');
	my $pfiller = $var->findvalue('@filler');

	$generic_relations->{$pevent} = "(./externalReferences//externalRef[\@reftype=\"".$pname."\"])";
	$generic_relations->{"$pevent.reference"} = "let \$".$pevent.".reference:=substring((\$".$pevent."/externalReferences//externalRef[\@reftype=\"".$pname."\"])[1]/\@reference,1)";
	$generic_relations->{$pfiller} = "(./externalReferences//externalRef[\@reftype=\"SubClassOf\" and \@reference=\$".$pevent.".reference])"; 
    }
    
    return ($rootpivot, $rootexp1, $rootexp2, \%var_pool, \@var_opt, $last_var);
}

sub print_xquery_for {

  my ($parsed) = @_;

  my $xquery = $parsed->{expr1}.$parsed->{name}.$parsed->{expr2}."\n";
  #print $parsed->{expr1}.$parsed->{name}.$parsed->{expr2}."\n";
  my $deps = $parsed->{dep};
  return unless defined $deps;
  foreach my $dep (@{ $deps }) {
    $xquery.= &print_xquery_for($dep);
  }
  return $xquery;
}

sub get_xquery_return {

  my ($xmlroot, $rootpivot, $external_hash) = @_;

  my $kybot_id= $xmlroot->getAttribute("id");


  # the return element is the last element of the profile

  my ($last_elem) = $xmlroot->findnodes('/Kybot/*[last()]');
  $last_elem->setAttribute("doc", "{document-uri(root(\$$rootpivot))}");
  &attr_variable($last_elem);
  #return "return\n".$last_elem->toString(1)."\n"."else()\n";
  
  ## add synset xpath...
  foreach my $elem ($last_elem->childNodes()) {
      if ($elem->getAttribute("target") =~ /\$([^\/]+)/) {
	  my $var_name = $1;
	  #external ref-ak zehazten badira atributen deklarazioan...
	  if ($external_hash->{$var_name} =~ /\S+/) {
	      $elem->setAttribute("synset", "{string((\$$var_name/externalReferences/externalRef[".$external_hash->{$var_name}."])[1]/\@reference)}");#)[1]/../../\@reference)}");
	      $elem->setAttribute("rank", "{string((\$$var_name/externalReferences/externalRef[".$external_hash->{$var_name}."])[1]/\@confidence)}");
	      #$elem->setAttribute("synset", "{string((\$$1/externalReferences/externalRef".$external_hash->{$1}.")[1]/../../\@reference)}");#)[1]/../../\@reference)}");
	  }
	  else{
	      $elem->setAttribute("synset", "{string((\$$var_name/externalReferences/externalRef)[1]/\@reference)}");
	      $elem->setAttribute("rank", "{string((\$$var_name/externalReferences/externalRef)[1]/\@confidence)}");
	  }
      }
      $elem->setAttribute("profile_id",$kybot_id);
  }
  
  my $lag = $last_elem->toString(1)."\n";
  $lag =~ s/\&quot;/\"/g;
  return $lag;
  #return $last_elem->toString(1)."\n";
  #     print $xquery;
}

sub get_xquery_return2 {

  my $xquery = shift;
  my $countkop = ($xquery =~ s/ at \$count/ at \$count/g);
  my $i;
  my $restriction = "";
  for ($i=1; $i<=$countkop; $i++) {
    if ($i == 1) {
      $restriction .= "if (\$count$i=1 ";
    } else {
      $restriction .= "and \$count$i=1 ";
    }
  }
  if ($countkop > 0) {
    return "return\n".$restriction.") then\n";
  } else {
    return "return\n".$restriction;
  }
}

sub attr_variable {

  my $main_elem = shift;

  foreach my $attr_elem ($main_elem->attributes()) {
    my $v = $attr_elem->getValue();
    my $vname = $attr_elem->getName();
    #if ($vname eq "synset") {
    #if ($v =~ /^\s*(\$[^\/]+)/) {
    #$v = $1."/externalReferences/externalRef[1]/\@reference";
#}
#    }
    if ($v =~ /^\s*\$/) {
      $v = "{$v}";
      $attr_elem->setValue($v);
    }
  }

  foreach my $elem ($main_elem->childNodes) {
    &attr_variable($elem);
  }
}

########################################################################################################
## XQuery execution

sub update_db {

  my($mgr, $container_name, $res_tree) = @_;

  my $container = KybotLib::openContainer($mgr, $container_name);
  die "Container does not exist.\n" unless defined $container;

  my $qcontext;
  my $query_exp;
  my $update_results;

  eval {
    $qcontext = $mgr->createQueryContext();
    $qcontext->setDefaultCollection($container->getName());
  };

  if (my $e = catch XmlException) {
    die $e->what();
  }

  foreach my $doc_elem ($res_tree->getDocumentElement()->childNodes) {
    my $docname = $doc_elem->getAttribute("name");
    my $docname_short = $doc_elem->getAttribute("shortname");

    foreach my $sub_elem ($doc_elem->childNodes) {
      my $update_xquery = 'insert node '.$sub_elem->asString().' into doc("'.$docname.'")/KAF2[1]';

      eval {
	$query_exp = $mgr->prepare($update_xquery, $qcontext);
	$update_results = $query_exp->execute($qcontext);
      };

      if (my $e = catch XmlException) {
	die $e->what();
      }
    }
  }

  # my $ucontext;
  # my $modify;
  # my $queryexp;
  # my $document;
  # my $doc_value;
  # my $nres = new XmlValue();

  # eval {
  # 	$ucontext = $mgr->createUpdateContext();
  # 	$modify = $mgr->createModify();
  # 	$queryexp = $mgr->prepare("/*[1]/$rootName",$qcontext);
  # 	$modify->addAppendStep($queryexp, XmlModify::Element , "", $content);
  # 	$modify->execute($nres, $qcontext, $ucontext);

  # };

}

sub check_and_insert_element {

  my ($mgr, $container, $docname, $elem_name) = @_;

  #Check if fact element exists in the document
  my $fquery = 'doc("'.$docname.'")//'.$elem_name;

  my $fquery_exp;
  my $fresults;
  my $fqcontext;

  eval {
    $fqcontext = $mgr->createQueryContext();
    $fqcontext->setDefaultCollection($container->getName());
    $fquery_exp = $mgr->prepare($fquery, $fqcontext);
    $fresults = $fquery_exp->execute($fqcontext);
  };

  if (my $e = catch XmlException) {
    die $e->what();
  }

  #If facts element does not exist then create it

  return 0 if defined $fresults && $fresults->size();

  my $fcontent ="<$elem_name></$elem_name>";

  my $fucontext;
  my $fmodify;
  my $fqueryexp;
  my $nresults = new XmlValue();
#  my $modelem = new XmlModify::Element;
  my $i;
  eval {
    $fucontext = $mgr->createUpdateContext();
    $fmodify   = $mgr->createModify();
    $fqueryexp = $mgr->prepare("/*[1]",$fqcontext);
    #$fmodify->addAppendStep($fqueryexp, $modelem , "$elem_name", "");
    $fmodify->execute($nresults, $fqcontext, $fucontext);
  };

  if (my $e = catch XmlException) {
    die $e->what();
  }

  die $i;

  return 1;

  my $document;
  my $doc_value;
  eval {
    $document = $container->getDocument($docname);
    $doc_value = new XmlValue($document);

  };

  if (my $e = catch XmlException) {
    die $e->what();
  }
  return 1;
}

sub exec_query {

  my($mgr, $container_name, $xquery, $result_array) = @_;

  my $container = KybotLib::openContainer($mgr, $container_name);
  die "Container does not exist.\n" unless defined $container;

  my $qcontext;
  my $query_exp;
  my $results;

  eval {
    $qcontext = $mgr->createQueryContext();
    $qcontext->setDefaultCollection($container->getName());
    $query_exp = $mgr->prepare($xquery, $qcontext);
    $results = $query_exp->execute($qcontext);
  };

  if (my $e = catch XmlException) {
    die $e->what();
  }

  my $value = new XmlValue();

  while ($results->next($value)) {
    push @{ $result_array } , $value->asString();
  }
}

sub build_result_tree {

  my ($res_array) = @_;

  my $result_tree = XML::LibXML::Document->new();
  my $result_elem = $result_tree->createElement("kybotOut");
  $result_tree->setDocumentElement($result_elem);

  my %out_doc; # { docname -> doc_elem }

  foreach my $oline (@{ $res_array} ) {

    my ($docname, $docname_short) = &parse_docname($oline);
    my $ol_tree = $xmlParser->parse_string($oline);
    die "Can not parse $oline\n" unless $ol_tree;

    my $doc_elem = $out_doc{$docname_short};

    if (!defined($doc_elem)) {
      # create a new document element
      $doc_elem = $result_tree->createElement("doc");
      $doc_elem->setAttribute("name", $docname);
      $doc_elem->setAttribute("shortname", $docname_short);
      $result_elem->addChild($doc_elem);
      $out_doc{$docname_short} = $doc_elem;
    }

    # insert $ol_tree into $doc_elem
    my $ol_doc_elem = $ol_tree->documentElement();
    my $parent = &doctree_parent($doc_elem, $ol_doc_elem);

    foreach my $ol_elem ($ol_doc_elem->findnodes("/*/*")) {
      $result_tree->adoptNode($ol_elem);
      $parent->addChild($ol_elem);
    }
  }
  return $result_tree;
}

sub doctree_parent {

  my ($doc_elem, $ol_doc_elem) = @_;

  my $ol_rstr = $ol_doc_elem->nodeName;

  foreach my $subelem ($doc_elem->childNodes) {
    if ($ol_rstr eq $subelem->nodeName) {
      return $subelem;
    }
  }

  # ol_doc_elem is not in doc_elem. Copy it.
  my $new_elem = $ol_doc_elem->cloneNode(0);
  $new_elem->removeAttribute("doc");
  $doc_elem->addChild($new_elem);
  return $new_elem;

}

sub parse_docname {

  my $str = shift;

  # <events><event id="research-type" doc="dbxml:///uLZOjvZnA6.dbxml/1118.kaf"><role src="t3388" value="biodiversity"/></event></events>

  return undef unless $str =~ /\sdoc=\"([^\"]+)\"/;
  my $docname = $1;
  my @fdoc = split(/\//, $docname);
  my $docname_short = pop @fdoc;
  return ($docname, $docname_short);
}
