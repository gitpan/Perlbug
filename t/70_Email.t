#!/usr/bin/perl -w
# Email tests for Perlbug: check email functions against config data
# Richard Foley RFI perlbug@rfi.net
# $Id: 70_Email.t,v 1.9 2000/08/02 08:15:37 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 6);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Email;
use FileHandle;
use Mail::Internet;
use Sys::Hostname;
my $o_mail = Perlbug::Email->new;
$o_mail->current('isatest', 1);

$o_mail->current('admin', 'richardf');

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my @tests		= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------
# 
# SYSTEM
$test++; 
$err = 0;
$context = 'system';
foreach my $tgt (qw(maintainer)) {
	my $addr = $o_mail->system($tgt);
	my $checked = $o_mail->ck822($addr);
	if ($checked != 1) {
		$err++;
		output("$context $tgt address check ($test) failed -> '$addr'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# EMAIL
$test++; 
$err = 0;
$context = 'email';
foreach my $tgt (qw(bugdb bugtron from help test)) {
	my $addr = $o_mail->email($tgt);
	my $checked = $o_mail->ck822($addr);
	if ($checked != 1) {
		$err++;
		output("$context $tgt address check 822 ($test) failed -> '$addr'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# TARGET
$test++; 
$err = 0;
$context = 'target';
foreach my $tgt ($o_mail->get_keys($context)) {
	my $addrs = $o_mail->$context($tgt);
	foreach my $addr (split(/\s+/, $addrs)) {
		my $checked = $o_mail->ck822($addr); 
		if ($checked != 1) {
			$err++;
			output("$context $tgt address check 822 ($test) failed -> '$addr'");
		}
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# FORWARD
$test++; 
$err = 0;
$context = 'forward';
foreach my $tgt ($o_mail->get_keys($context)) {
	my $addrs = $o_mail->$context($tgt);
	foreach my $addr (split(/\s+/, $addrs)) {
		my $checked = $o_mail->ck822($addr); 
		if ($checked != 1) {
			$err++;
			output("$context $tgt address check 822 ($test) failed -> '$addr'");
		}
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# DUMMY
$test++; 
$err = 0;
$context = 'all_duff';
my %map = (
	'blank' 		=> '',
	'no_ampersand'	=> 'no.ampersand.net',
	'ridiculous'	=> 'rid icul @ @ ous',
	'http'			=> 'http://www.perl.org',
);
foreach my $tgt (keys %map) {
	my $addr = $map{$tgt};
	my $checked = $o_mail->ck822($addr);
	if ($checked == 1) {
		$err++;
		output("$context $tgt ck822 check ($test) failed -> '$addr'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# ALL_OK
$test++; 
$err = 0;
$context = 'all_ok';
%map = (
	'rpo' 		=> 'richard@perl.org',
	'rfm'		=> 'Richard.Foley@m.dasa.de',
	'named'		=> '"Richard Foley" <richard@rfi.net>',
	'extended'	=> '"etc etc etc" <email@some.place>',
);
foreach my $tgt (keys %map) {
	my $addr = $map{$tgt};
	my $checked = $o_mail->ck822($addr);
	if ($checked != 1) {
		$err++;
		output("$context $tgt ck822 check ($test) failed -> '$addr'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# CLEAN_HEADER_CK822
#
#


# Done
# -----------------------------------------------------------------------------
# .
		
