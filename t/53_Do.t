#!/usr/bin/perl -w
# Do retrieval by non-id means tests for Perlbug: do (c l o q r s)
# Richard Foley RFI perlbug@rfi.net
# $Id: 53_Do.t,v 1.2 2000/08/08 10:09:22 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 10);
}
use strict;
use Data::Dumper;
use lib qw(../);
my $test = 0;
my $context = 'not defined';


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_perlbug = Perlbug::Base->new;

# Tests
# -----------------------------------------------------------------------------

my %tgt = ( # 
	'c'		=> 'unknow clo', 			# category
	'l'		=> '',						# logs
	'o'		=> '', 						# overview
    'q'		=> 'SELECT * FROM tm_id', 	# sql query
	'r'		=> 'not much data',  		# retrieve by body
	's'		=> 'realclean',				# subject
);

# 1..6
foreach my $tgt (sort keys %tgt) {
	$test++;
	my $context = "do$tgt";
	my $args = $tgt{$tgt};
	if (1 == 1) {
		my $i_ok = $o_perlbug->$context($args); 
		if ($i_ok >= 1) {	
			ok($test);
		} else {
			notok($test);
			output("$context($args) failed($i_ok)");
		}
	}
}

my %xtgt = ( # 
	'c'		=> 'u_n_ k_n - o n o_w [ hE-RE ]', 
	#'l'		=> 'x',
	#'o'		=> 'x', # 
    'q'		=> 'S_ELE -CT * FRO M tx m_id_x',
	'r'		=> 'this is extremelttlitlty un_lik-ly 2B theirs asdl- now() ss', 
	's'		=> 'delete equally likl ey to f_IND any upper(tnhi at all nghasdfvmn)',
);

# 7..10
foreach my $xtgt (sort keys %xtgt) {
	$test++;
	my $context = "do$xtgt";
	my $xargs = $xtgt{$xtgt};
	if (1 == 1) {
		my $i_ok = $o_perlbug->$context($xargs); 
		if ($i_ok == 0) {	
			ok($test);
		} else {
			notok($test);
			output("$context($xargs) failed($i_ok)");
		}
	}
}

# Done
# -----------------------------------------------------------------------------
# .
