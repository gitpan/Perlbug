#!/usr/bin/perl -w
# Format (format_(bug|ticket|message|patch|test|note)_fields) tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 33_Format.t,v 1.2 2000/08/08 10:07:17 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 3);
}
use strict;
use Data::Dumper;
use lib qw(../);
my $test = 0;
my $cntxt = 'bug';

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_fmt = Perlbug::Base->new;

# Tests
# -----------------------------------------------------------------------------
my ($TID) = $o_fmt->get_list("SELECT MAX(ticketid) FROM tm_tickets");
my %h_data = (
	'ticketid' 	=> $TID,
	'admins' 	=> [qw(me you)],
	'messageids'=> [qw(1 2 3)],
	'ccs'		=> [qw(m1 m2 m3)],
	'notes'		=> [qw(1)],
	'noteid',   => '1',
	'sourceaddr'=> 'perlbug_test@rfi.net',
	'subject'   => 'some subject',
	'parents'	=> [$TID],
	'children'  => [$TID, $TID],
	'fixed'		=> '',
	'severity'	=> 'low',
	'category'  => 'notabug',
	'version'   => 'no idea',
	'osname' 	=> 'x',
	'msgbody'   => 'heres the msgbody...',
);

# 1
# ref
$test++;
my $context = "format_${cntxt}_fields";
my $h_fmtd = $o_fmt->$context(\%h_data); 
if (ref($h_fmtd)) {	
	ok($test);
} else {
	notok($test);
	output("Failed $context(\%h_data) -> '$h_fmtd'");
}

# 2
# ticket ref
$test++;
if ($$h_fmtd{'ticketid'} =~ /^\<a\shref\=\"perlbug\.cgi\?req\=bid\&bid\=$TID\&.+/i) {	
	ok($test);
} else {
	notok($test);
	output("format $context($h_fmtd) ticketid failed -> ".Dumper($$h_fmtd{'ticketid'}));
}

# 3
# history
$test++;
if ($$h_fmtd{'history'} =~ /^\<a\shref\=\"perlbug\.cgi\?req\=hist\&hist\=$TID\&.+/i) {	
	ok($test);
} else {
	notok($test);
	output("format $context($h_fmtd) history failed -> ".Dumper($$h_fmtd{'history'}));
}

# Done
# -----------------------------------------------------------------------------
# .
