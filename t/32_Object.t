#!/usr/bin/perl -w
# Object retrieval tests (for objects and relations) for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 32_Object.t,v 1.1 2001/04/21 20:48:48 perlbug Exp $
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
use Perlbug::Base;
my $o_pb   = Perlbug::Base->new;
my $o_test = Perlbug::TestBed->new($o_pb);
my @objects= $o_pb->things;

# Tests
# -----------------------------------------------------------------------------

$test = 1;
my $i_errs = 0;
my @failed = ();
foreach my $obj (@objects) {
	my $i_err = 0;
	my $o_obj = $o_pb->object($obj);
	my $ref = ref($o_obj);
	my $match = 'Perlbug::Object::'.ucfirst($obj);
	if ($ref !~ /^$match$/) {
		$i_err++;
		output("$obj failed to retrieve correct($match) ref($ref) object($o_obj)");
	}
	if ($i_err != 0) {
		$i_errs++;
		push(@failed, $obj);
	}
		
}
if ($i_errs == 0) {
	ok($test);
} else {
	ok(0);
	output("$i_errs objects failed(@failed)");
}

$test = 2;
$i_errs = 0;
@failed = ();
my $i_rels = 0;
foreach my $obj (@objects) {
	my $i_err = 0;
	my $o_obj = $o_pb->object($obj);
	foreach my $rel ($o_obj->rels) {
		my $o_rel = $o_pb->object($rel);
		my $ref = ref($o_rel);
		my $match = 'Perlbug::Object::'.ucfirst($rel);
		if ($ref !~ /^$match$/) {
			$i_err++;
			output("$obj rel($rel) failed to retrieve correct($match) ref($ref) relation($o_rel)");
		}
		if ($i_err != 0) {
			$i_errs++;
			push(@failed, "$obj:$rel");
		}
	}	
}
if ($i_errs == 0) {
	ok($test);
} else {
	ok(0);
	output("$i_errs objects failed $i_rels relations(@failed)");
}

# Done
# -----------------------------------------------------------------------------
#
