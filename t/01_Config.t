#!/usr/bin/perl -w
# Actual configuration tests (dir., files, perms., email addresses etc.) for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 01_Config.t,v 1.1 2001/03/31 16:15:01 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 8);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Config;
use Data::Dumper;
my $o_conf = Perlbug::Config->new; 
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
	if ($context =~ /^(arch|spool|temp)$/) {
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
