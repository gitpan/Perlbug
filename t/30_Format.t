#!/usr/bin/perl -w
# Format (fmt: scalar, array, hash) tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 30_Format.t,v 1.3 2000/08/02 08:19:32 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 5);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_fmt = '';

# Tests
# -----------------------------------------------------------------------------
my %h_data = (
	'here'	=> 'and there',
	'there'	=> [qw(and over here)],
	'zip'	=> '',
	'',		=> 'o',
);

# 1
# callable? 
$test++; 
if ($o_fmt = Perlbug::Base->new) {	
	# $o_fmt->current('isatest', 1);
	ok($test);
} else {
	notok($test);
	output("Can't retrieve Format($o_fmt) object");
}

# 2
# format a scalar?
$test++;
my $format = $o_fmt->fmt($h_data{'here'}, 'a');
chomp($format);
if ($format =~ /and\sthere/) {	
	ok($test);
} else {
	notok($test);
	output("format scalar (should read /and there/) failed: '$format'");
}

# 3
# format an array ref?
$test++;
$format = $o_fmt->fmt($h_data{'there'}, 'a');
chomp($format);
if ($format =~ /and\sover\shere/) {	
	ok($test);
} else {
	notok($test);
	output("format arrayref (should read /and over here/) failed: '$format'");
}

# 4
# format a hash ref?
$test++;
$format = $o_fmt->fmt(\%h_data, 'a');
chomp($format);
if ($format =~ /here\=and\sthere/m) {	
	ok($test);
} else {
	notok($test);
	output("format hashref (should read /here=and there/) failed: '$format'");
}

# 5
# format an array in a hash?
$test++;
$format = $o_fmt->fmt(\%h_data, 'a');
chomp($format);
if ($format =~ /there\=and\sover\shere/) {	
	ok($test);
} else {
	notok($test);
	output("format array in hashref (should read /there=and over here/) failed: '$format'");
}

# Done
# -----------------------------------------------------------------------------
# .
