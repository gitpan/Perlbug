#!/usr/bin/perl -w
# Email tests for Perlbug: check mailability (both command line and module based - not finished 
# Richard Foley RFI perlbug@rfi.net
# $Id: 71_Email.t,v 1.11 2000/08/02 08:22:21 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 8);
}
use strict;
use lib qw(../);
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Email;
use Sys::Hostname;
my $o_mail = Perlbug::Email->new;
$o_mail->current('isatest', 1);

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
$test++; 
if (ref($o_mail)) {	
	ok($test);
} else {
	notok($test);
	output("Can't retrieve Email($o_mail) object");
}

# 2
# can open mail object
$test++; 
$err = 0;
my $o_Msg = Mail::Send->new;
if (ref($o_Msg)) {	
	ok($test);
} else {
	notok($test);
	output("Mail::Send->new failed($o_Msg)");	
}

# 3
# can print to mail program?
$test++; 
$err = 0;
$o_Msg->set('To', $maintainer) || $err++;
$o_Msg->set('Subject', 'Perlbug installation obj test message') || $err++;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
	output("print to '$o_Msg' failed");
}

# 4
# can open mail object
$test++; 
$err = 0;
my $o_Mail = $o_Msg->open('test') || $err++;
# this may print out a 'to: someone@some.where' note!
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
	output("$o_Msg->open('test') failed: '$o_Mail')");	
}

# 5
# can open mail object
$test++; 
$err = 0;
print $o_Mail $body || $err++;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
	output("Can't print to $o_Mail");	
}

# 6
# can close mail filehandle?
$test++; 
$err = 0;
if ($o_Mail->close) {
	ok($test);
} else {
	notok($test);
	output("Couldn't close Mail object($o_Mail)");
}

# 7
# can send another (plain) mail?
$test++; 
$err = 0;
my $o_hdr1 = '';
if (1 == 1) {
	$o_mail->_original_mail($o_mail->_duff_mail);
	$o_hdr1 = $o_mail->get_header;
	$o_hdr1->add('To', 'perlbug_test@rfi.net');
	$o_hdr1->add('Subject', 'some subject');
	$o_hdr1->add('From', $maintainer);
	$o_hdr1 = $o_mail->defense($o_hdr1);
}
if (ref($o_hdr1)) {
	ok($test);
} else {
	notok($test);
	output("Couldn't get the first o_hdr($o_hdr1)");
}

# 8
# can send another (dupe) mail?
$test++; 
$err = 0;
my $o_hdr2 = '';
my $i_sent = 2;
if (1 == 1) {
	$o_hdr2 = $o_mail->get_header($o_hdr1);
	$o_hdr2->replace('To', $maintainer);
	$o_hdr2->replace('Subject', 'some other subject');
	$o_hdr2->replace('From', 'perlbug_test@rfi.net');
	$o_hdr2->add('Message-Id', 'abc');
	$i_sent = $o_mail->send_mail($o_hdr2, $body);
}
if (ref($o_hdr2) and $i_sent == 1) {
	ok($test);
} else {
	notok($test);
	output("Couldn't send($i_sent) the second header ($o_hdr2)");
}

# Done
# -----------------------------------------------------------------------------
# .
