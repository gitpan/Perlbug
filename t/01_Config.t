#!/usr/bin/perl -w
# Actual configuration tests (dir., files, perms., email addresses etc.) for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 01_Config.t,v 1.2 2001/09/18 13:37:50 richardf Exp $
#
use strict;
use lib qw(../);
use Perlbug::Test;
plan('tests' => 8);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Config;
use Data::Dumper;
my $o_conf = Perlbug::Config->new; 
my $o_test = Perlbug::Test->new($o_conf);
$o_conf->current('isatest', 1);

# Tests: spool and other dirs
# -----------------------------------------------------------------------------

# 1-6
# Directories 
$test++;
$err = 0;
foreach my $context ($o_conf->get_keys('directory')) { 
	my $err = 0;
	my $dir = $o_conf->directory($context);
	if (! -d $dir) {
		$err++; # 1	
		output("Dir($dir) not exists)");
	}
	if (! -r $dir) {
		$err++; # 2
		output("Dir($dir) not readable)");
	}
	if ($context =~ /^(arch|spool|temp)$/o) {
		if (! -w $dir) {
			$err++; # 3
			output("Dir($dir) not writable)");
		}
	}
	if ($err == 0) {	
		# output("$context directory($dir) looks ok");
		ok($test);
	} else {
		ok(0);
		output("$context directory failure($err)");
	}
	$test++;
}
$test--;

# 7
# User 
$test++;
$err = 0;
my $user = $o_conf->system('user');
my @data = getpwnam($user);
if (-d $data[7]) {
	ok($test);
} else {
	ok(0);
	output("Non-existent user($user) -> data(@data) on system");
}



# Done
# -----------------------------------------------------------------------------
# .
