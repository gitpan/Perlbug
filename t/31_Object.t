#!/usr/bin/perl -w
# Setup test data for Perlbug: insert: user, bug, patch, note, test, claimants, ccs
# Richard Foley RFI perlbug@rfi.net
# $Id: 31_Object.t,v 1.2 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 7);
}
use strict;
use lib qw(../); 

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
use FileHandle;
use Mail::Internet;
use Sys::Hostname;
my $o_pb = Perlbug::Base->new;
my $o_test = Perlbug::TestBed->new($o_pb);
$o_pb->current('admin', 'richardf');

# Setup
# -----------------------------------------------------------------------------
my $err  = 0;
my $test = 0;

# SETUP
# -----------------------------------------------------------------------------

my $TO		= '"Perlbug DB" <perlbug@perl.com>';
my $FROM	= 'Richard. J. S. Foley" <perlbug_test@rfi.net>';
my $SUBJECT = 'some email -> "make realclean" eats my patches :-)';
my $NEWBID	= '19870502.007';
my $MSGID 	= '19870502@rfi.net';
my $REPLYID = '';
my %MAIL 	= (
	'toaddr'		=> $TO,
	'sourceaddr'	=> $FROM,
	'subject'		=> $SUBJECT,
	'email_msgid'	=> $MSGID,
	'body'			=> q#
	This is a perlbug(<unrecognised>) of some sort...
	
	os=irix status=onhold 
	
	(not much data... here perl etc...}

	on behalf a perl bug test report

	#,
	'header'		=> qq#
Return-path: <perl5-porters-return-14508-p5p=rfi.net\@perl.org>
Date: Wed, 12 Jul 2000 15:26:47 +0100
From: $FROM
Subject: $SUBJECT
To: $TO
Cc: perlbug_test_cc\@rfi.net
Cc: cc_perlbug_interest\@rfi.net
Message-ID: <$MSGID>
MIME-version: 1.0
Content-type: TEXT/PLAIN
Content-transfer-encoding: 7BIT
Precedence: bulk
Delivered-to: mailing list perl5-porters\@perl.org
Delivered-to: perlmail-perlbug\@perl.org
Mail-For: <p5p\@rfi.net>
Mailing-List: contact perl5-porters-help\@perl.org; run by ezmlm
X-Comment: Message Virus scanned by m.dasa.de
List-Post: <mailto:perl5-porters\@perl.org>
List-Unsubscribe: <mailto:perl5-porters-unsubscribe\@perl.org>
List-Help: <mailto:perl5-porters-help\@perl.org>
X-Mozilla-Status: 8001
X-Mozilla-Status2: 00000000
X-UIDL:  !!!!01JROPXND8ZK8Y7ZAG0
	#,
);

# Tests
# -----------------------------------------------------------------------------

# 1 - 7
# INSERT for TestBed
# 
my @objects = $o_pb->things('mail');
OBJ:
foreach my $obj (sort @objects) {
	$test++; 
	next OBJ unless $obj =~ /\w+/;
	my $o_obj = $o_pb->object($obj);
	if (!(ref($o_obj))) {
		output("\tobj($obj) failed to retrieve object($o_obj)!");
	} else {
		my $pri = $o_obj->primary_key;
		my $oid = $o_obj->new_id;
		$MAIL{'body'} =~ s/\<unrecognised\>/$obj/si;
		$o_obj->create({
			$pri 	=> $oid,
			%MAIL, 
		});
		my $i_ok = $o_obj->CREATED;
		if ($i_ok != 1) {
			output("\tfailed to insert $obj($i_ok)!"); 
		} else {	
			my $oid = $o_obj->oid;
			output("\tinstalled object($obj) oid($oid)");
			if ($obj eq 'bug') {
				$o_obj->update( { $pri => $NEWBID } );
				$i_ok = $o_obj->UPDATED;
				if ($i_ok) {
					output("\tupdated($oid)->$NEWBID");
				} else {
					output("\tfailed to update $obj($i_ok)!") unless $i_ok;
				}
			}
		}
		if ($i_ok == 1) {
			ok($test);
		} else {
			ok(0);
		}
	} 
}
if ($err == 0) {	
	# ok($test);
	output("...installed ".@objects." objects");
} else {
	# ok(0);
	output("...failed($err) on objects installation"); 
}
    
# done.

