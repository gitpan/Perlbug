#!/usr/bin/perl -w
# WWW tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 90_Web.t,v 1.1 2000/08/02 08:21:35 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 3);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Web;
my $o_web = '';

# Tests
# -----------------------------------------------------------------------------

# each new type of test?
# restore_parameters(join('&', @data));

# 1
# callable? 
$test++; 
if ($o_web = Perlbug::Web->new('x' => 'y')) {	
	$o_web->current('isatest', 1);
	ok($test);
} else {
	notok($test);
	output("Web object ($o_web) not retrieved");
}

# 2
# dummy second test
$test++; 
$err = 0;
if ($o_web->current('url') =~ /\w+/) {	
	ok($test);
} else {
	notok($test);
	output("current url(".$o_web->current('url').") looks odd");
}

# 3
# dummy third test
$test++; 
$err = 0;
if ($o_web->current('url') =~ /\w+/) {	
	ok($test);
} else {
	notok($test);
	output("current url(".$o_web->current('url').") still looks odd");
}


# Done
# -----------------------------------------------------------------------------
# .
