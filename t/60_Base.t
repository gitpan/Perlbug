#!/usr/bin/perl -w
# Base tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 60_Base.t,v 1.3 2000/08/02 08:20:44 perlbug Exp $
#
# TODO: clean_up tests
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 7);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_base = ''; 

# Tests
# -----------------------------------------------------------------------------
my $admin 	= '';
my $status 	= '';

# 1
# callable? 
$test++; 
if ($o_base = Perlbug::Base->new()) {	
	$o_base->current('isatest', 1);
	ok($test);
} else {
	notok($test);
	output("base object ($o_base) not retrieved");
}

# 2
# admin should be leer?
$test++; 
$admin = $o_base->isadmin;
if ($admin eq '') {	
	ok($test);
} else {
	notok($test);
	output("invalid (should be '') admin($admin)");
}

# 3
# should still be leer?
$test++; 
$admin = $o_base->isadmin('test_able ');
if ($admin eq '') {	
	ok($test);
} else {
	notok($test);
	output("invalid (should still be '') admin($admin)");
}

# 4
# user?
$test++; 
$status = $o_base->status;
if ($status eq 'U') {	
	ok($test);
} else {
	notok($test);
	output("invalid (should be 'U') status($status)");
}

# 5
# set?
$test++; 
$admin = $o_base->current('admin', 'xxx');
if ($admin eq 'xxx') {	
	ok($test);
} else {
	notok($test);
	output("invalid assignment (should be 'xxx') admin($admin)");
}

# 6
# admin?
$test++; 
$status = $o_base->status;
if ($status eq 'A') {	
	ok($test);
} else {
	notok($test);
	output("invalid status (should be 'A') status($status)");
}

# 7
# reset?
$test++; 
$o_base->current('admin', '');
$admin  = $o_base->current('admin');
$status = $o_base->status;
if ($admin eq '' and $status eq 'U') {	
	ok($test);
} else {
	notok($test);
	output("invalid reset (should be '' and 'U') admin($admin) and status($status)");
}
# Done
# -----------------------------------------------------------------------------
# .
