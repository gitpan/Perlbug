#!/usr/bin/perl -w
# Format (format_this) tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 34_Format.t,v 1.1 2000/08/08 10:07:04 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 2);
}
use strict;
use Data::Dumper;
use lib qw(../);
my $test 	= 0;
my $fname 	= 'res';
my $format 	= 'FORMAT_B_a';
my $max 	= 220;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_fmt = Perlbug::Base->new;

# Tests
# -----------------------------------------------------------------------------
my ($TID) = $o_fmt->get_list("SELECT MAX(ticketid) FROM tm_tickets");
my $is_ok = $o_fmt->dob($TID);

my $h_data = $o_fmt->_current_target;
# print Dumper($h_data);
$h_data = $o_fmt->format_fields($h_data);
	
# 1
# basic
$test++;
my $i_ok = $o_fmt->format_this($fname, $format, $max, $h_data);
if ($i_ok == 1) {	
	ok($test);
} else {
	notok($test);
	output("scalar format_this($fname, $format, $max) failed -> $i_ok");
}

# 2
# basic
$test++;
$format = $format.'x';
$i_ok = $o_fmt->format_this($fname, $format, $max, $h_data);
if ($i_ok == 0) {	
	ok($test);
} else {
	notok($test);
	output("scalar format_this($fname, $format, $max) failed -> $i_ok");
}

# Done
# -----------------------------------------------------------------------------
# .
