#!/usr/bin/perl -w
# Email tests for actual mailing functionality
# Richard Foley RFI perlbug@rfi.net
# $Id: 71_Email.t,v 1.15 2001/09/18 13:37:50 richardf Exp $
#

use lib qw(../);
use strict;
use Perlbug::Test;
use Perlbug::Interface::Email;
use Sys::Hostname;

plan('tests' => 8);

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);
my $i_test = 0;

# Tests
# -----------------------------------------------------------------------------
my $maintainer 	= $o_mail->system('maintainer');
my $hostname	= hostname;
my $date		= localtime(time);
my $err			= 0;
my $mail 		= qq|To: $maintainer
From: $maintainer
Subject: Perlbug installation test message
|;
my $body 		= qq|Test message from Perlbug installation test run at '$hostname' 

$date
|;

# 1
# callable? 
$i_test++; 
if (ref($o_mail)) {	
	ok($i_test);
} else {
	ok(0);
	output("Can't retrieve Email($o_mail) object");
}

# 2
# can open mail object
$i_test++; 
$err = 0;
my $o_Msg = Mail::Send->new;
if (ref($o_Msg)) {	
	ok($i_test);
} else {
	ok(0);
	output("Mail::Send->new failed($o_Msg)");	
}

# 3
# can print to mail program?
$i_test++; 
$err = 0;
$o_Msg->set('To', $maintainer) || $err++;
$o_Msg->set('Subject', 'Perlbug installation obj test message') || $err++;
if ($err == 0) {	
	ok($i_test);
} else {
	ok(0);
	output("print to '$o_Msg' failed");
}

# 4
# can open mail object
$i_test++; 
$err = 0;
my $o_Mail = $o_Msg->open('test') || $err++;
# this may print out a 'to: someone@some.where' note!
if ($err == 0) {	
	ok($i_test);
} else {
	ok(0);
	output("$o_Msg->open('test') failed: '$o_Mail')");	
}

# 5
# can open mail object
$i_test++; 
$err = 0;
print $o_Mail $body || $err++;
if ($err == 0) {	
	ok($i_test);
} else {
	ok(0);
	output("Can't print to $o_Mail");	
}

# 6
# can close mail filehandle?
$i_test++; 
$err = 0;
if ($o_Mail->close) {
	ok($i_test);
} else {
	ok(0);
	output("Couldn't close Mail object($o_Mail)");
}

$^W = 0;
# 7
# can send another (plain) mail?
$i_test++; 
$err = 0;
my $o_hdr1 = '';
if (1 == 1) {
	$o_hdr1 = Mail::Header->new;
	$o_hdr1->replace('To', 'perlbug_test@rfi.net');
	$o_hdr1->replace('Subject', 'some subject');
	$o_hdr1->replace('From', $maintainer);
	$o_hdr1 = $o_mail->defense($o_hdr1); # 
}
if (ref($o_hdr1)) {
	ok($i_test);
} else {
	ok(0);
	output("Couldn't get the first o_hdr($o_hdr1)");
}

# 8
# can send another (dupe) mail?
$i_test++; 
$err = 0;
my $o_hdr2 = '';
my $i_sent = 2;
if (1 == 1) {
	$o_hdr2 = $o_mail->get_header($o_hdr1);
	# $o_hdr2 = $o_hdr1->dup();
	$o_hdr2->replace('To', $maintainer);
	$o_hdr2->replace('Subject', 'some other subject');
	$o_hdr2->replace('From', 'perlbug_test@rfi.net');
	my $now = $o_mail->get_date;
	$o_hdr2->replace('Message-Id', "<${now}_$$\@rfi.net>");
	$i_sent = $o_mail->send_mail($o_hdr2, $body);
}
if (ref($o_hdr2) and $i_sent == 1) {
	ok($i_test);
} else {
	ok(0);
	output("Couldn't send($i_sent) the second header ($o_hdr2)");
}
$^W = 1;

# Done
# -----------------------------------------------------------------------------
# .
