#!/usr/bin/perl -w
# Do tests for Perlbug do(f h d)
# Richard Foley RFI perlbug@rfi.net
# $Id: 50_Do.t,v 1.8 2001/09/18 13:37:50 richardf Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Test;
	plan('tests' => 4);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_perlbug = '';
my $context = 'not defined';

# Tests
# -----------------------------------------------------------------------------

# 1
# Libraries callable? 
$test++; 
if ($o_perlbug = Perlbug::Base->new) {	
	$o_perlbug->current('isatest', 1);
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
