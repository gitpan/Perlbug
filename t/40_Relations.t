#!/usr/bin/perl -w
# Relations line tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 40_Relations.t,v 1.2 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 2);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Relation;
my $o_rel  = '';
my $o_test = '';

# Tests
# -----------------------------------------------------------------------------

# 1
# callable? 
$test++; 
$err = 0;
$o_rel = Perlbug::Relation->new('bug', 'patch', 'to');
if (ref($o_rel)) {	
	$o_test = Perlbug::TestBed->new($o_rel);
	ok($test);
} else {
	output("rel object ($o_rel) not retrieved");
	ok(0);
}

$test++;
my $i_errs = 0;
my $i_rels = 0;
my $o_pb = $o_rel->base;
foreach my $obj ($o_pb->things()) {
# foreach my $obj (qw(test version)) {
	my @failed   = ();
	my $i_relerr = 0;
	my $o_obj = $o_pb->object($obj);
	foreach my $rel ($o_obj->rels) {
		my $o_rel = $o_obj->rel($rel);
		if ($o_rel->check() != 1) {
			$i_relerr++;
			$i_rels++; 
			push(@failed, $rel);
		}
	}
	if ($i_relerr != 0) {
		$i_errs++;
		output("object($obj) failed $i_relerr relations(@failed)");
	}
}
if ($i_errs == 0) {
	ok($test);
} else {
	ok(0);
	output("$i_errs objects failed $i_rels relations");
}

# Done
# -----------------------------------------------------------------------------
#
