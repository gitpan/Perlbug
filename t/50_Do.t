#!/usr/bin/perl -w
# Do tests for Perlbug do(f h d)
# Richard Foley RFI perlbug@rfi.net
# $Id: 50_Do.t,v 1.9 2001/12/01 15:24:43 richardf Exp $
#
use strict;
use lib qw(../);


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
use Perlbug::Test;
my $o_perlbug = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_perlbug);
my $context = 'not defined';

my $test = 0;
plan('tests' => 4);

# Tests
# -----------------------------------------------------------------------------

# 1
# Libraries callable? 
$test++; 
if (ref($o_perlbug)) {
	ok($test);
} else {
	ok(0);
	output("base object ($o_perlbug) retrieval failed");
}

# 2
$test++;
$context = 'doh';
my $data = $o_perlbug->doh; 
if (length($data) >= 1) {	
	ok($test);
} else {
	ok(0);
	output("doh failed($data)");
}

# 3
$test++;
$context = 'dof';
$o_perlbug->dof('h'); 
my $fmt = $o_perlbug->current('format');
if ($fmt eq 'h') {	
	ok($test);
} else {
	ok(0);
	output("dof('h') failed($fmt)");
}

# 4
$test++;
$context = 'dof';
$o_perlbug->dof('a'); 
$fmt = $o_perlbug->current('format');
if ($fmt eq 'a') {	
	ok($test);
} else {
	ok(0);
	output("dof('a') failed($fmt)");
}


# Done
# -----------------------------------------------------------------------------
# .
