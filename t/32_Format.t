#!/usr/bin/perl -w
# Format (format_fields) tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 32_Format.t,v 1.1 2000/08/07 07:39:49 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 4);
}
use strict;
use Data::Dumper;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_fmt = Perlbug::Base->new;

# Tests
# -----------------------------------------------------------------------------
my %h_data = (
	'ticketid' => '19990102.003',
	'status'   => 'and there',
	'there'	   => [qw(and over here)],
	'zip'	   => '',
	'',		   => 'o',
);

# 1
# scalar
$test++;
my $h_fmtd = $o_fmt->format_fields(\%h_data);
if (Dumper($h_fmtd) =~ /\'ticketid\'\s\=\>\s\'19990102.003\'/i) {	
	ok($test);
} else {
	notok($test);
	output("scalar format_fields($h_fmtd) failed -> ".Dumper($h_fmtd));
}

# 2
# scalar
$test++;
$h_fmtd = $o_fmt->format_fields(\%h_data);
if (Dumper($h_fmtd) !~ /\'ticketid\'\s\s\=\>\s\'19990102.003\'/i) {	
	ok($test);
} else {
	notok($test);
	output("scalar format_fields($h_fmtd) failed -> ".Dumper($h_fmtd));
}

# 3
# array
$test++;
$h_fmtd = $o_fmt->format_fields(\%h_data);
if (Dumper($h_fmtd) =~ /\'there\'\s\=\>\s\'and\sover\shere\'/i) {	
	ok($test);
} else {
	notok($test);
	output("array format_fields($h_fmtd) failed -> ".Dumper($h_fmtd));
}

# 4
# array
$test++;
$h_fmtd = $o_fmt->format_fields(\%h_data);
if (Dumper($h_fmtd) !~ /\'there\'\s\=\>\s\'and\s\sover\shere\'/i) {	
	ok($test);
} else {
	notok($test);
	output("array format_fields($h_fmtd) failed -> ".Dumper($h_fmtd));
}

# Done
# -----------------------------------------------------------------------------
# .
