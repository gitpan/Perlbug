#!/usr/bin/perl -w
# Setup test data for Perlbug: insert: user, bug, patch, note, test, claimants, ccs
# Richard Foley RFI perlbug@rfi.net
# $Id: 31_Object.t,v 1.8 2001/12/01 15:24:43 richardf Exp $
#
use Perlbug::Test;
use strict;
use lib qw(../); 

# Libs
# -----------------------------------------------------------------------------
use Data::Dumper;
use FileHandle;
use Mail::Internet;
use Perlbug::Base;
use Sys::Hostname;
my $o_pb = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_pb);
$o_pb->current('admin', 'richardf');

# Setup
# -----------------------------------------------------------------------------
my $err  = 0;
my $test = 0;

# SETUP
# -----------------------------------------------------------------------------
my $TO		= '"Perlbug DB" <perlbug@perl.com>';
my $FROM	= $o_test->from;
my $SUBJECT = 'some email -> "make realclean" eats my patches :-)';
my $BUGID   = $o_test->bugid;
my $MSGID 	= $o_test->email_messageid;
my $REPLYID = '';
my %MAIL 	= (
	'toaddr'		=> $TO,
	'sourceaddr'	=> $FROM,
	'subject'		=> $SUBJECT,
	'email_msgid'	=> $MSGID,
	'body'			=> q#
	This is a perlbug(<unrecognised>) of some _  ' ' sort...
	
	os=irix status=onhold 
	
	(not much data... here perl etc...)

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
Delivered-to: mailing list perl5-porters\@perl.org
Delivered-to: perlmail-perlbug\@perl.org
Mailing-List: contact perl5-porters-help\@perl.org; run by ezmlm
X-Comment: Message Virus scanned by m.dasa.de
X-UIDL:  !!!!01JROPXND8ZK8Y7ZAG0
	#,
);
# 
my %TEMPLATE = (
	'name'			=> 'bug',
	'format'		=> 'a',
	'wrap'			=> '75',
	'description'	=> 'test insertion of bug template', 
	'header'		=> '', 
	'body'			=> q#
Bug: <{bugid}>  Created: <{created}>  Modified: <{created}>
Subject: <{subject}>

Status:   <{status_names}>
OS:       <{osname_names}>
Severity: <{severity_names}>
Group:    <{group_names}>

Message ids: <{patch_ids}>
Patch ids:   <{patch_ids}>

Header:   
<{header}>

Body:
<{body}>

	#,
);	


# Tests
# -----------------------------------------------------------------------------

# 1 - 8
# INSERT for Test
# 
my @objects = ($o_pb->objects('mail'), 'template');
plan('tests' => scalar(@objects));

OBJ:
foreach my $obj (sort @objects) {
	$test++; 
	next OBJ unless $obj =~ /\w+/o;
	my $o_obj = $o_pb->object($obj);
	if (!(ref($o_obj))) {
		output("\tobj($obj) failed to retrieve object($o_obj)!");
	} else {
		my $pri = $o_obj->primary_key;
		my $oid = $o_obj->new_id;
		$MAIL{'body'} =~ s/\<unrecognised\>/$obj/si;
		# output("\tusing new $obj oid($oid)");
		# $pri 	=> (($obj eq 'bug') ? $BUGID : $oid),
		my %DATA = ($obj eq 'template') ? %TEMPLATE : %MAIL;
		$o_obj->create({
			$pri 	=> $oid, # actually we DO need to do it this way
			%DATA, 
		});
		my $i_ok = $o_obj->CREATED;
		if ($i_ok != 1) {
			output("\tfailed to insert $obj($i_ok)!"); 
		} else {	
			my $oid = $o_obj->oid;
			output("\tinstalled object($obj) oid($oid)");
			if ($obj eq 'bug') {
				my $i_del = $o_obj->delete([$BUGID])->DELETED;
				output("\tdeleted($BUGID) => del($i_del)");
				# $o_obj->update( { $pri => $BUGID } );
				# $i_ok = $o_obj->UPDATED;
				my $update = "UPDATE pb_bug SET $pri = '$BUGID' WHERE $pri = '$oid'";
				my $sth = $o_pb->exec($update);
				if (defined($sth)) {
					output("\tupdated($oid)->$BUGID");
				} else {
					output("\tfailed to update $obj($sth)!");
					$i_ok = 0;
				}
			}
		}
		ok(($i_ok == 1) ? $test : 0);
	} 
}
if ($err == 0) {	
	output("...installed ".@objects." objects");
} else {
	output("...failed($err) on objects installation"); 
}
   
# done.

