#!/usr/bin/perl -w
# Email tests for Perlbug: check email functions against config data
# Richard Foley RFI perlbug@rfi.net
# $Id: 70_Email.t,v 1.12 2001/09/18 13:37:50 richardf Exp $
#

use lib qw(../);
use strict;
use FileHandle;
use Mail::Internet;
use Perlbug::Test;
use Perlbug::Interface::Email;
use Sys::Hostname;

plan('tests' => 6);

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);

my $i_test = 0;
my $i_err  = 0;
my $context= '';

# Tests
# -----------------------------------------------------------------------------
# 
# SYSTEM
$i_test++; # 1
$i_err = 0;
$context = 'system';
foreach my $tgt (qw(maintainer)) {
	my $addr = $o_mail->system($tgt);
	my $checked = $o_mail->ck822($addr);
	if ($checked != 1) {
		$i_err++;
		output("$context $tgt address check ($i_test) failed -> '$addr'");
	}	
}
output("$context -> err($i_err)") if $i_err;
ok(($i_err == 0) ? $i_test : 0);


# EMAIL
$i_test++; # 2
$i_err = 0;
$context = 'email';
foreach my $tgt (qw(bugdb bugtron from help test)) {
	my $addr = $o_mail->email($tgt);
	my $checked = $o_mail->ck822($addr);
	if ($checked != 1) {
		$i_err++;
		output("$context $tgt address check 822 ($i_test) failed -> '$addr'");
	}	
}
output("$context -> err($i_err)") if $i_err;
ok(($i_err == 0) ? $i_test : 0);


# TARGET/FORWARD
foreach my $context (qw(target forward)) {
	$i_test++; # 3, 4
	$i_err = 0;
	foreach my $tgt ($o_mail->get_keys($context)) {
		my @addrs = $o_mail->$context($tgt);
		foreach my $addr (@addrs) {
			my $checked = $o_mail->ck822($addr); 
			if ($checked != 1) {
				$i_err++;
				output("$context $tgt address check822 ($i_test) failed($addr)");
			}
		}	
	}
	output("$context -> err($i_err)") if $i_err;
	ok(($i_err == 0) ? $i_test : 0);
}


# DUMMY
$i_test++; # 5
$i_err = 0;
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
		$i_err++;
		output("$context $tgt ck822 check ($i_test) failed -> '$addr'");
	}	
}
output("$context -> err($i_err)") if $i_err;
ok(($i_err == 0) ? $i_test : 0);


# ALL_OK
$i_test++; # 6
$i_err = 0;
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
		$i_err++;
		output("$context $tgt ck822 check ($i_test) failed -> '$addr'");
	}	
}
output("$context -> err($i_err)") if $i_err;
ok(($i_err == 0) ? $i_test : 0);

# CLEAN_HEADER_CK822
#
#


# Done
# -----------------------------------------------------------------------------
# .
		
