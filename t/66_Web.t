#!/usr/bin/perl -w
# WWW tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 66_Web.t,v 1.1 2001/09/18 13:52:39 richardf Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Test;
	plan('tests' => 3);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Interface::Web;
my $o_web = '';

# Tests
# -----------------------------------------------------------------------------

# each new type of test?
# restore_parameters(join('&', @data));

# 1
# callable? 
$test++; 
if ($o_web = Perlbug::Interface::Web->new('x' => 'y')) {	
	$o_web->current('isatest', 1);
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
