#!/usr/bin/perl -w
# Do retrieval by non-id means tests for Perlbug: do (g l o q r s)
# Richard Foley RFI perlbug@rfi.net
# $Id: 53_Do.t,v 1.4 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 8);
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

my $table = 'pb_thing';
my %tgt = ( # 
	'g'		=> 3,
	# 'l'	=> '',				# logs
	# 'o'	=> '', 				# overview (takes too long)
	'q'		=> "SELECT * FROM $table", 	# sql query
	'r'		=> 'not much data',  		# retrieve by body - bit of a wild stab...
	's'		=> 'realclean',			# subject - ditto
);

# 1..7
foreach my $tgt (sort keys %tgt) {
	$test++;
	my $context = "do$tgt";
	my $args = $tgt{$tgt};
	if (1 == 1) {
		my $res = $o_perlbug->$context($args); 
		if ($res =~ /\w+/) {	
			ok($test);
		} else {
			ok(0);
			output("$context($args) failed($res)");
		}
	}
}

my %xtgt = ( # 
	'c'		=> 'u_n_ k_n - o n o_w [ hE-RE ]', 
        'q'		=> 'S_ELE -CT \* FRO M tx m_id_x',
	'r'		=> 'this 41 is ext-rem_elt_tlitlty un_lik-ly 2B theirs asdl- now() ss', 
	's'		=> 'no tVeRy-eq\ually likl ey to f_IND any upper(tnhi at all nghasd\\fvmn)',
);

# 8..11
foreach my $xtgt (sort keys %xtgt) {
	$test++;
	my $context = "do$xtgt";
	my $xargs = $xtgt{$xtgt};
	if (1 == 1) {
		my $res = $o_perlbug->$context($xargs); 
		if ($res =~ /\w+/) {	
			ok($test);
		} else {
			ok(0);
			output("$context($xargs) failed($res)");
		}
	}
}

# Done
# -----------------------------------------------------------------------------
# .
