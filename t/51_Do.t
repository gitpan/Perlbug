#!/usr/bin/perl 
#
# Richard Foley RFI perlbug@rfi.net
# $Id: 51_Do.t,v 1.5 2001/12/01 15:24:43 richardf Exp $
#
use strict;
use Data::Dumper;
use Perlbug::Base;
use Perlbug::Test;

my $o_perlbug = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_perlbug);
plan('tests' => 4);

use lib qw(../);
my $test = 0;
my $context = 'not defined';

# Tests
# -----------------------------------------------------------------------------

# 1
# Libraries callable? 
$test++; 
$context = 'new';
if (ref($o_perlbug)) {
	ok($test);
} else {
	ok(0);
	output("base object ($o_perlbug) retrieval failed");
}

# 2
$test++;
$context = 'switches';
my @switches = $o_perlbug->$context(); 
if (grep(/^h$/, @switches) and grep(!/^a$/, @switches)) {	
	ok($test);
} else {
	ok(0);
	output("$context failed(@switches)");
}

# 3
$test++;
@switches = $o_perlbug->$context('user'); 
if (grep(/^b$/, @switches) and grep(!/^a$/, @switches)) { 
	ok($test);
} else {
	ok(0);
	output("$context('user') failed(@switches)");
}

# 4
$test++;
@switches = $o_perlbug->$context('admin'); 
if (grep(/^a$/, @switches) and grep(/^x$/, @switches)) { 
	ok($test);
} else {
	ok(0);
	output("$context('admin') failed(@switches)");
}

# $context = 'stats'; # takes too long to bother testing

# Done
# -----------------------------------------------------------------------------
# .
