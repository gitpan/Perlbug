#!/usr/bin/perl -w
# Actual configuration tests system('user'), email('commands')
# Richard Foley RFI perlbug@rfi.net
# $Id: 12_Config.t,v 1.1 2001/12/05 21:02:02 richardf Exp $
#
use strict;
use lib qw(../);
use Perlbug::Test;
my $test = 0;
my $err = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Config;
use Data::Dumper;
my $o_conf = Perlbug::Config->new; 
my $o_test = Perlbug::Test->new($o_conf);

plan('tests' => 2);

# 1
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

# 2
# commands 
$test++;
$err = 0;
my %cmds = %{$o_conf->email('commands')};
CMD:
foreach my $cmd (sort keys %cmds) {
	unless ($cmds{$cmd} =~ /^[a-zA-Z]$/) {
		$err++;
		output("email command($cmd) looks wrong($cmds{$cmd})");
	}
}
if ($err == 0) {
	ok($test);
} else {
	ok(0);
	output("email commands failed");
}



# Done
# -----------------------------------------------------------------------------
# .
