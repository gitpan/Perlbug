#!/usr/bin/perl -w
# Command line tests for Perlbug: process
# Richard Foley RFI perlbug@rfi.net
# $Id: 80_Cmd.t,v 1.1 2000/08/02 08:21:13 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 1);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Cmd;
my $o_cmd = '';

# Tests
# -----------------------------------------------------------------------------

# each new type of test?
# restore_parameters(join('&', @data));

# 1
# callable? 
$test++; 
if ($o_cmd = Perlbug::Cmd->new('x' => 'y')) {	
	$o_cmd->current('isatest', 1);
	ok($test);
} else {
	notok($test);
	output("Cmd object ($o_cmd) not retrieved");
}

=pod
# 2
# process returns as expected 
$test++; 
$err = 0;
my @cmds = (
	'h', 'd1', 'Q',
);
foreach my $cmd (@cmds) {
	my $res = $o_cmd->process($cmd) == 1;
	if ($res == 1) {
		# OK
	} else {
		$err++;
		output("Cmd process($cmd) failed($res)");
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
	output("Cmd process had $err errors");
}
=cut

# Done
# -----------------------------------------------------------------------------
# .
