#!/usr/bin/perl -w
# Email tests for Perlbug: check the tron switching/decision mechanism: expects context return value(reply|quiet|etc...)
# Richard Foley RFI perlbug@rfi.net
# $Id: 74_Email.t,v 1.2 2000/08/02 08:24:19 perlbug Exp perlbug $
#
BEGIN {
	use Data::Dumper;
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
$o_mail->current('admin', 'richardf');
$o_mail->current('isatest', 1);

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my $dir		    = './t/testmails/switch';
my @expected	= (qw(insert bounce quiet new reply reply_to)); # remove? insert
my %installed	= ();
my $context		= '';
my $BUGID       = '';
my $msgid       = getnow;
my $_MSGID      = '';
my $_BUGID      = '';

# Tests
# -----------------------------------------------------------------------------

my @tests = get_tests($dir, @expected);

# 1
# INSERT for testing
$test++; 
$err = 0;
$context = 'insert';
$msgid = getnow; # new message-id
if (1 == 1) { # container
	$_MSGID=$msgid;
	my $header = q#
Return-path: <perl5-porters-return-14508-p5p=rfi.net@perl.org>
Date: Wed, 12 Jul 2000 15:26:47 +0100
From: "Richard. J. S. Foley" <perlbug_test@rfi.net>
Subject: [PATCH] "make realclean" eats my patches :-)
To: perlbug@perl.com
Message-ID: <$_MSGID>
MIME-version: 1.0
Content-type: TEXT/PLAIN
Content-transfer-encoding: 7BIT
Precedence: bulk
Delivered-to: mailing list perl5-porters@perl.org
Delivered-to: perlmail-perlbug@perl.org
Mail-For: <p5p@rfi.net>
Mailing-List: contact perl5-porters-help@perl.org; run by ezmlm
X-Comment: Message Virus scanned by m.dasa.de
List-Post: <mailto:perl5-porters@perl.org>
List-Unsubscribe: <mailto:perl5-porters-unsubscribe@perl.org>
List-Help: <mailto:perl5-porters-help@perl.org>
X-Mozilla-Status: 8001
X-Mozilla-Status2: 00000000
X-UIDL:  !!!!01JROPXND8ZK8Y7ZAG0
#;
	my $subject = ' [PATCH] "make realclean" eats my patches :-) ';
	my $from = '"Richard. J. S. Foley" <perlbug_test@rfi.net>';
	my $to = 'perlbug@perl.com';
	my $body = "\nBody (not much data... \nhere perl etc...\n";
	#
	my ($ok, $tid, $mid) = $o_mail->insert_bug($subject, $from, $to, $header, $body); 
	$_BUGID=$tid;
	if (!($ok == 1 and $o_mail->ok($tid))) {
		$err++;
		output("$context test ($test) failed -> '$tid'");
	} 
}
output("$context -> err($err) leftovers from previous tests?") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}
	
# 2
# QUIET
$test++; 
$err = 0;
$context = 'quiet';
$^W=0; # warnings while lots of duff headers
QUIET:
foreach my $test (grep(/^${context}_\d+$/, @tests)) {
	my ($switch, $data) = &get_switch($test, $BUGID, $msgid);
	if ($switch ne "do_$context") {
		$err++;
		output("$context test ($test) failed -> '$switch'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	ok(0); # notok($test);
}
$^W=0;

# 3
# BOUNCE
$test++; 
$err = 0;
$context = 'bounce';
BOUNCE:
foreach my $test (grep(/^${context}_\d+$/, @tests)) {
	my ($switch, $data) = &get_switch($test);
	if ($switch ne "do_$context") {
		$err++;
		output("$context test ($test) failed -> '$switch'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	ok(0); # notok($test);
}

# 4
# NEW
$test++; 
$err = 0;
$context = 'new';
NEW:
foreach my $test (grep(/^${context}_\d+$/, @tests)) {
	$msgid = getnow;
	my ($switch, $data) = &get_switch($test, $BUGID, $msgid);
	if ($switch ne "do_$context") {
		$err++;
		output("$context test ($test) failed -> '$switch'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	ok(0); # notok($test);
}


# 5
# REPLY
$test++; 
$err = 0;
$context = 'reply';
REPLY:
foreach my $test (grep(/^${context}_\d+$/, @tests)) {
	$msgid = getnow;
	my ($switch, $data) = &get_switch($test, $_BUGID, $msgid);
	if ($switch ne "do_$context") {
		$err++;
		output("$context test ($test) failed -> '$switch'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	skip(1); # notok($test);
}

# 6
# REPLY_TO
$test++; 
$err = 0;
$context = 'reply_to';
REPLY:
foreach my $test (grep(/^${context}_\d+$/, @tests)) {
	next REPLY; # rjsf - temp!
	$msgid = getnow;
	my ($switch, $data) = &get_switch($test, '', '', $_MSGID);
	if ($switch ne "do_$context") {
		$err++;
		output("$context test ($test) failed -> '$switch' with $data");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	ok(0); # notok($test);
}


# Done
# -----------------------------------------------------------------------------
# .

sub get_switch { # Switch wrapper
	my $file  = shift;
	my $BUGID = shift || '';
	my $msgid = shift || '';
	my $reply = shift || '';
	my ($switch, $args, $mail) = ('', '', undef);
    my $FH = FileHandle->new("< $dir/$file");
    if (defined($FH)) {
        $mail = Mail::Internet->new($FH);
        close $FH;
    	if (defined($mail)) {
			$o_mail->_mail($mail);
			if ($msgid =~ /\w+/) { # substitute
				$mail->head->replace('Message-Id', $msgid);
			}
			if ($BUGID =~ /\w+/) { 
				$mail->head->replace('Subject', "[ID $BUGID ] ".$mail->head->get('Subject'));
			}
			if ($reply =~ /\w+/) {
				$mail->head->replace('In-Reply-To', "<$reply>");
			} 
			($switch, $args) = $o_mail->switch($mail);
		} else {
			output("Mail($mail) not retrieved");		
		}
	} else {
        output("FileHandle($FH) not defined for file ($file): $!");
    }
	return ($switch, $args);
}
		
