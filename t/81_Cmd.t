#!/usr/bin/perl -w
# Command line tests for Perlbug: process
# Richard Foley RFI perlbug@rfi.net
# $Id: 81_Cmd.t,v 1.1 2001/03/31 16:15:01 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 1);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Interface::Cmd;
my $o_cmd = '';
my $o_test = '';

# Tests
# -----------------------------------------------------------------------------

# each new type of test?
# restore_parameters(join('&', @data));

# 1
# callable? 
$test++; 
$o_cmd = Perlbug::Interface::Cmd->new();
if (ref($o_cmd)) {	
	$o_test = Perlbug::TestBed->new($o_cmd);
	ok($test);
} else {
	ok(0);
	output("Cmd object ($o_cmd) not retrieved");
}

# Done
# -----------------------------------------------------------------------------
# .
