#!/usr/bin/perl -w
# Object utility tests diff()
# Richard Foley RFI perlbug@rfi.net
# $Id: 33_Object.t,v 1.5 2001/12/05 20:58:38 richardf Exp $
#
use strict;
use lib qw(../);
use Perlbug::Base;
use Perlbug::Test;

my $o_base = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_base);
my $o_obj  = $o_base->object('bug');

plan('tests' => 2);
my $i_test = 0;
my $i_err  = 0;

# Tests
# -----------------------------------------------------------------------------

# 1
# callable? 
$i_test++; 
if (ref($o_base) and ref($o_test) and ref($o_obj)) {
	ok($i_test);
} else {
	ok(0);
	output("object($o_obj) not retrieved");
}

# 2
# data structures
my $orig = q|
	original 
	data
|;
my $chan = q|

	xriginal 
	data
|;

my $diff = $o_obj->diff($orig, $chan);
if ($diff =~ /^old:\s*\n2\s+original\s*\nnew:\s*\n2\s+xriginal\s*\n$/ms) {
	ok($i_test);
} else {
	ok(0);
	output("Failed diff($diff) from orig($orig) changed($chan)");
}


# Done
# -----------------------------------------------------------------------------
# .
