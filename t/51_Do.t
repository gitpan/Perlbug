#!/usr/bin/perl 
#
# Richard Foley RFI perlbug@rfi.net
# $Id: 51_Do.t,v 1.4 2001/09/18 13:37:50 richardf Exp $
#
use strict;
use Data::Dumper;
use Perlbug::Base;
use Perlbug::Test;
plan('tests' => 4);
use lib qw(../);
my $test = 0;
my $context = 'not defined';
my $o_perlbug = '';

# Tests
# -----------------------------------------------------------------------------

# 1
# Libraries callable? 
$test++; 
$context = 'new';
if ($o_perlbug = Perlbug::Base->new) {	# wont operate stand-alone
	$o_perlbug->current('isatest', 1);
	ok($test);
} else {
	ok(0);
	output("base object ($o_perlbug) retrieval failed");
}

# 2
$test++;
$context = 'get_switches';
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

=pod
# 5
$test++;
$context = 'stats'; # takes too long to bother testing
my %stats = %{$o_perlbug->$context()}; 
if ($stats{'bugs'} >= 1) { 
	ok($test);
} else {
	ok(0);
	output("$context failed: ".Dumper(\%stats));
}
=cut

# Done
# -----------------------------------------------------------------------------
# .
