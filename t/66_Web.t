#!/usr/bin/perl -w
# WWW tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 66_Web.t,v 1.2 2001/12/01 15:24:43 richardf Exp $
#
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;
use Perlbug::Interface::Web;
use Perlbug::Test;

my $o_web = Perlbug::Interface::Web->new('x' => 'y');
my $o_test = Perlbug::Test->new($o_web);

plan('tests' => 3);

# Tests
# -----------------------------------------------------------------------------

# each new type of test?
# restore_parameters(join('&', @data));

# 1
# callable? 
$test++; 
if (ref($o_web)) {
	ok($test);
} else {
	ok(0);
	output("Web object ($o_web) not retrieved");
}

# 2
# dummy second test
$test++; 
$err = 0;
if ($o_web->current('url') =~ /\w+/o) {	
	ok($test);
} else {
	ok(0);
	output("current url(".$o_web->current('url').") looks odd");
}

# 3
# dummy third test
$test++; 
$err = 0;
if ($o_web->current('url') =~ /\w+/o) {	
	ok($test);
} else {
	ok(0);
	output("current url(".$o_web->current('url').") still looks odd");
}


# Done
# -----------------------------------------------------------------------------
# .
