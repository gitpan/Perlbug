#!/usr/bin/perl -w
# Object Relation tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 41_Relation.t,v 1.1 2001/12/01 15:24:43 richardf Exp $
#
use strict;
use lib qw(../);
use Data::Dumper;
use Perlbug::Test; 
plan('tests' => 11); 
my $test = 0;
my $oid = '19870502.007';

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
use Perlbug::Object::Bug;
my $o_obj = Perlbug::Object::Bug->new->read($oid);

# Tests
# -----------------------------------------------------------------------------

# 1
# read
$test++; 
my @ids = $o_obj->rel_ids('message');
if (@ids >= 1) {
	ok($test);
} else {
	ok(0);
	output("rel_ids('message') failed(@ids)");
}


# 2
# rel_types 
$test++; 
my @types = $o_obj->rel_types;
if (grep(/^(float|from|to)$/, @types)) {
	ok($test);
} else {
	ok(0);
	output("failed to retrieve valid rel_types(@types)");
}

# 3
# isarel 
$test++; 
my $isarel = $o_obj->isarel('message', 'to');
if ($isarel) {
	ok($test);
} else {
	ok(0);
	output("isarel('message', 'to') failed($isarel)");
}

# 4
# relations 
$test++; 
my @rels = $o_obj->rels('to');
if (grep(/^message$/, @rels)) {
	ok($test);
} else {
	ok(0);
	output("relations('to') failed to retrieve message(@rels)");
}

# 5
# relation
$test++; 
my $o_rel = $o_obj->rel('patch');
if (ref($o_rel)) {
	ok($test);
} else {
	ok(0);
	output("relation('patch') failed to return an object handler($o_rel)");
}

# 6
# rel
$test++; 
my $x_rel = $o_obj->rel('patch')->base->object('bug')->rel('user')->base->object('group');
if (ref($x_rel)) {
	ok($test);
} else {
	ok(0);
	output("rel('patch')->rel('version')->rel('bug') failed to return an object handler($x_rel)");
}

# 7
# rel_ids 
$test++; 
my @rids = $o_obj->rel_ids('patch');
if (@rids >= 1) {
	ok($test);
} else {
	ok(0);
	output("rel_ids('patch') failed to return any ids(@rids)");
}

# 8
# (r)ids 
$test++; 
my @o_rids = $o_obj->rel('patch')->ids($o_obj);
if (@o_rids >= 1) {
	ok($test);
} else {
	ok(0);
	output("relation('patch')->ids(o_obj) failed to return any ids(@o_rids)");
}

# 9
# (r)ids 
$test++; 
if (@rids == @o_rids) { # num should be alpha comp against list
	ok($test);
} else {
	ok(0);
	output("rel_ids(@rids) doesn't match relation_ids(@o_rids)");
}

# 10
# relate()
my %rellies = (
	'group'	=> {
		'names'	=> [('x-test-group_'.int(rand(99)))],
	},
	'osname'	=> {
		'names'	=> [('x-test-osname_'.int(rand(99)), 'x-test-osname_'.rand(99))],
	},
	'status'	=> {
		'names'	=> [('x-test-status_'.int(rand(99)))],
	},
);
$test++; 
my $i_relatable = scalar(keys %rellies);
my $i_related   = $o_obj->relate(\%rellies);
if ($i_related == $i_relatable) {
	ok($test);
} else {
	ok(0);
	output("related($i_related) doesn't match relatable($i_relatable)");
	ouput(Dumper(\%rellies)) if $Perlbug::DEBUG;
}

# 11
# clean up
my $i_del = 0;
my $o_gr = $o_obj->object('osname');
my $o_os = $o_obj->object('osname');
my $o_st = $o_obj->object('status');
$i_del += $o_gr->delete([$o_gr->ids("name LIKE 'x-test-%'")])->DELETED;
$i_del += $o_os->delete([$o_os->ids("name LIKE 'x-test-%'")])->DELETED;
$i_del += $o_st->delete([$o_st->ids("name LIKE 'x-test-%'")])->DELETED;
if ($i_del == $i_related) {
	ok($test);
} else {
	ok(0);
	output("deleted($i_del) doesn't match related($i_related)");
}
# done

