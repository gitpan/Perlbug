#!/usr/bin/perl -w
# Object Relation tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 34_Object.t,v 1.1 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN { 
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed; 
	plan('tests' => 9); 
}
use strict;
use lib qw(../);
use Carp;
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
my @rels = $o_obj->relations('to');
if (grep(/^message$/, @rels)) {
	ok($test);
} else {
	ok(0);
	output("relations('to') failed to retrieve message(@rels)");
}

# 5
# relation
$test++; 
my $o_rel = $o_obj->relation('patch');
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
my @o_rids = $o_obj->relation('patch')->ids($o_obj);
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
	output("rel_ids(@rids) don't match relation_ids(@o_rids)");
}

