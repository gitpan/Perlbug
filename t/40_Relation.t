#!/usr/bin/perl -w
# Relations line tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 40_Relations.t,v 1.3 2001/09/18 13:37:50 richardf Exp $
#
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Relation;
use Perlbug::Test;
plan('tests' => 3);
my $o_rel  = '';
my $o_test = '';

# Tests
# -----------------------------------------------------------------------------

# 1
# callable? 
$test++; 
$err = 0;
$o_rel = Perlbug::Relation->new('bug', 'patch', 'to');
my $o_base = $o_rel->base;
if (ref($o_rel)) {	
	$o_test = Perlbug::Test->new($o_base);
	ok($test);
} else {
	output("rel object ($o_rel) not retrieved");
	ok(0);
}

$test++;
my $BUGID = $o_test->bugid;
my $o_bug = $o_base->object('bug')->read($BUGID);
my @rels  = qw(message note patch test);
my $i_related = 0;
foreach my $rel (@rels) {
	my $o_obj = $o_base->object($rel);
	my $testids = "sourceaddr = '".$o_test->from."'";
	my ($rid) = $o_obj->ids($testids);
	$i_related += my $i_stored = $o_bug->rel($rel)->store([$rid])->STORED;
}
if ($i_related == scalar(@rels)) {
	ok($test);
	output("bug($BUGID) related($i_related) relations: ".join(', ', @rels).")");
} else {
	ok(0);
	output("failed to relate(@rels) -> related($i_related)");
}

$test++;
my $i_errs = 0;
my $i_rels = 0;
foreach my $obj ($o_base->objects()) {
	my @failed   = ();
	my $i_relerr = 0;
	my $o_obj = $o_base->object($obj);
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
