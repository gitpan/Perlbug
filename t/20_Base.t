#!/usr/bin/perl -w
# Base tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 20_Base.t,v 1.1 2001/03/31 16:15:01 perlbug Exp $
#
# TODO: clean_up tests
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 1);
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
	ok(0);
	output("base object ($o_base) not retrieved");
}

# Done
# -----------------------------------------------------------------------------
# .
