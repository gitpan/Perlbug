#!/usr/bin/perl -w
# Object Utility tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 33_Object.t,v 1.1 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN { 
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed; 
	plan('tests' => 11); 
}
use strict;
use lib qw(../);
use Carp;
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Object::Bug;
my $o_obj = Perlbug::Object::Bug->new();

# Tests
# -----------------------------------------------------------------------------

# 1
# object?
$test++; 
if (ref($o_obj)) {	
	ok($test);
} else {
	ok(0);
	output("Can't retrieve object($o_obj)");
}

# 2
# exists?
$test++; 
my $exists = $o_obj->exists;
if ($exists == 0) {
	ok($test);
} else {
	ok(0);
	output("non-valid bugid() should NOT exist($exists)");
}

# 3
# read
$test++; 
my $oid = '19870502.007';
$exists = $o_obj->read($oid)->exists;
if ($exists == 1) {
	ok($test);
} else {
	ok(0);
	output("valid bugid($oid) SHOULD exist($exists)");
}

# 4
# get attributes
$test++; 
my $key = $o_obj->attr('objectid'); 
if ($key eq $oid) {	
	ok($test);
} else {
	ok(0);
	output("get attr(objectid=$oid) failed -> '$key'");
}

# 5
# data 
my $created = $o_obj->data('created');
$test++; 
if ($created =~ /^\d+/) {
	ok($test);
} else {
	ok(0);
	output("get data(created=some_date) NOT ok -> '$created'");
}

# 6
# fields 
$test++; 
my @fields = $o_obj->data_fields;
if (grep(/^created$/, @fields)) {
	ok($test);
} else {
	ok(0);
	output("no 'created' data field found(@fields)");
}

# 7
# ids 
$test++; 
my $table = $o_obj->attr('table');
my ($i_all) = my @all = $o_obj->base->get_list("SELECT COUNT(*) FROM $table"); # !
my $i_ids   = my @ids = $o_obj->ids();
if ($i_all == $i_ids && $i_ids >= 1) {
	ok($test);
} else {
	ok(0);
	output("all($i_all) should numerically match ids($i_ids)!");
}

# 8
# ids+
my $pri = $o_obj->primary_key;
my ($bid) = $o_obj->ids("WHERE $pri = '$oid'");
$test++; 
if ($bid eq $oid) {
	ok($test);
} else {
	ok(0);
	output("retrieved $pri($bid) NOT matches objectid($oid)!");
}

# 9
# _gen_field_handler - migrated
my ($subject) = $o_obj->data('subject');
$test++; 
if ($subject =~ /\w+/) {
	ok($test);
} else {
	ok(0);
	output("field_handler failure: subject($subject)");
}

# 10 
# ref
my $href = $o_obj->_oref('attribute');
$test++; 
if (ref($href) eq 'HASH') {
	ok($test);
} else {
	ok(0);
	output("oref failed to retrieve attributes href($href)!");
}

# 11 
# base 
my $o_base = $o_obj->base;
$test++; 
if (ref($o_base) && $o_base->isabase) {
	ok($test);
} else {
	ok(0);
	output("failed to retrieve base($o_base)!");
}

