#!/usr/bin/perl -w
# Do tests for Perlbug do(f h d)
# Richard Foley RFI perlbug@rfi.net
# $Id: 50_Do.t,v 1.5 2000/08/08 10:07:59 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 6);
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
	notok($test);
	output("base object ($o_perlbug) retrieval failed");
}

# 2
# Fetch data?
$test++;
my $debug = $o_perlbug->current('debug'); 
if ($debug =~ /^[01234]$/) {	
	ok($test);
} else {
	notok($test);
	output("data fetch failed (should be '^[01234]$') debug($debug)");
}

# 3
# Modify data?
$test++;
$o_perlbug->dod([3]); 
$debug = $o_perlbug->current('debug');
if ($debug == 3) {	
	ok($test);
} else {
	notok($test);
	output("invalid reset (should be '3') of debug($debug)");
}

# 4
$test++;
$context = 'doh';
my $data = $o_perlbug->$context; 
if (length($data) >= 1) {	
	ok($test);
} else {
	notok($test);
	output("$context failed($data)");
}

# 5
$test++;
$context = 'dof';
my $i_fok = $o_perlbug->$context('h'); 
if ($i_fok == 1) {	
	ok($test);
} else {
	notok($test);
	output("$context('h') failed($data)");
}

# 6
$test++;
$context = 'dof';
$i_fok = $o_perlbug->$context('a'); 
if ($i_fok == 1) {	
	ok($test);
} else {
	notok($test);
	output("$context('a') failed($data)");
}


# Done
# -----------------------------------------------------------------------------
# .
