#!/usr/bin/perl -w
# Email tests at end of run - notify_cc(), send_mail(todo), reminder(todo), return_info()
# Richard Foley RFI perlbug@rfi.net
# $Id: 79_Email.t,v 1.2 2001/10/05 08:23:53 richardf Exp $
#

use lib qw(../);
use strict;
use Perlbug::Test;
use Perlbug::Interface::Email;
use Sys::Hostname;

plan('tests' => 1);

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);
my $i_test = 0;
my $i_err  = 0;

# Tests
# -----------------------------------------------------------------------------
my $maintainer 	= $o_mail->system('maintainer');
my $hostname	= hostname;
my $date		= localtime(time);
my $mail 		= qq|To: $maintainer
From: $maintainer
Subject: Perlbug installation test message
|;
my $data = qq|Test message from Perlbug installation test run at '$hostname' 

$date
|;

my $h_hdr = {
	'From'		=> $o_test->from,
	'To'		=> $o_test->bugdb,
};


# 1
$i_test++; 
my $o_int = $o_test->setup_int($h_hdr);
my $i_sent = $o_mail->return_info($data, $o_int);
ok(($i_sent == 1) ? $i_test : 0);

# Done
# -----------------------------------------------------------------------------
# .
