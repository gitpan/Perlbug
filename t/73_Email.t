#!/usr/bin/perl -w
# Email tests for Perlbug: parse_input($o_int) -> { 'b' => 'bugid' }
# Richard Foley RFI perlbug@rfi.net
# $Id: 73_Email.t,v 1.7 2001/12/01 15:24:43 richardf Exp $
#
# Note: this does NOT test parse_header()!

# Setup
# -----------------------------------------------------------------------------

use lib qw(../);
use strict;
use Data::Dumper;
use Perlbug::Interface::Email;
use Perlbug::Test;

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);
my $i_test = 0;

my $BUGID   = $o_test->bugid;
my $SUBJECT = 'some irrelevant subject matter';

# Tests - odd=bugdb@perl.org, even=*@bugs.perl.org (equivalent)
# -----------------------------------------------------------------------------
my $ifadmin = $o_mail->isadmin ? 'a' : 'v';
my $inreplytomsgid = $o_test->inreplytomsgid;
my $inreplytobugid = $o_test->inreplytobugid;
my %tests = (
	'bounce'	=> [
		{ 
			'expected'	=> { 
				'bounce'	=> [$o_mail->message('bounce')],
			},
			'header'	=> {
				'To'		=> 'perlbug@'.$o_test->domain,
				'Subject'	=> 'Get more sex today! but no perl',
				'From'		=> $o_test->from,
			},
		},
		{ 
			'expected'	=> { 
				'bounce'	=> [$o_mail->message('bounce')],
			},
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'Get even more sex today! but no perl',
				'From'		=> $o_test->from,
			},
		},
		{ #  
			'expected'	=> { 
				'nocommand'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> 'bugdb@'.$o_test->domain,
				'Subject'	=> 'Get more rubbish today!',
				'From'		=> $o_test->from,
			},
		},
		{ #  
			'expected'	=> { 
				'nocommand'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> 'bugdb@'.$o_test->domain,
				'Subject'	=> '- some non - existent -- commands',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'bounce'	=> [$o_mail->message('nobugids')],
			},
			'header'	=> {
				'To'		=> 'Note@'.$o_test->DOMAIN,
				'Subject'	=> 'a new note but no bugid',
				'From'		=> $o_test->from,
			},
		},
	],
	'bug'	=> [
		{ # 
			'expected'	=> { 
				'B'		=> $o_mail->message('new'),
			},
			'header'	=> {
				'To'		=> 'perlbug@'.$o_test->domain,
				'Subject'	=> 'new to/body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				a perl bug	
			|,
		},
		{ # 
			'expected'	=> { 
				'B'		=> $o_mail->message('new'),
			},
			'header'	=> {
				'To'		=> 'perlbug@'.$o_test->domain, # placeholder
				'Subject'	=> 'another new to/Body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				a nother pErlbUG 	
			|,
		},
		{ # 
			'expected'	=> {
				'B'	=> $o_mail->message('new'),
			},
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'a target/body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				perl
			|,
		},
		{ # 
			'expected'	=> {
				'B'	=> $o_mail->message('new'),
			},
			'header'	=> {
				'To'		=> 'mickey@mouse.rfi.net',
				'Cc'		=> 'minnie@mouse.rfi.net',
				'Cc'		=> $o_test->target,
				'Subject'	=> 'OK: new bug perl installed fine on cc',
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				perl
			|,
		},
		{ # 
			'expected'	=> { 				
				'B'	=> 'bug_aix_high',
			},
			'header'	=> {
				'To'		=> 'bUG_aix_high@'.$o_test->DOMAIN,
				'Subject'	=> 'a new to/body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				perl
			|,
		},
		{ # 
			'expected'	=> { 				
				'B'	=> 'bug',
			},
			'header'	=> {
				'To'		=> 'bUG@'.$o_test->DOMAIN,
				'Subject'	=> 'a new to/body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				perl
			|,
		},
	],
	'forward'	=> [
		{ # 
			'expected'	=> { 
				# 'v'			=> [q|please forward this one|],
				'v'			=> [q|admins|],
			},
			'header'	=> {
				# 'To'		=> $o_test->bugdb, # rjsf
				'To'		=> 'admins@'.$o_test->DOMAIN,
				'Subject'	=> '-v please forward this one',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'v'			=> [q|admins_|],
			},
			'header'	=> {
				'To'		=> 'ADMINS_@'.$o_test->DOMAIN,
				'Subject'	=> 'please forward this two',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'v'			=> [q|admins|],
			},
			'header'	=> {
				'To'		=> 'Admins@'.$o_test->DOMAIN,
				'Subject'	=> 'please forward this three',
				'From'		=> $o_test->from,
			},
		},
	],
	'help'	=> [
		{ #  
			'expected'	=> { 
				'h'			=> [],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> '-h',
				'From'		=> $o_test->from,
			},
		},
		{ #  
			'expected'	=> { 
				'h'			=> [qw(help)],
			},
			'header'	=> {
				'To'		=> 'hElp@'.$o_test->DOMAIN,
				'Subject'	=> $SUBJECT,
				'From'		=> $o_test->from,
			},
		},
		{ #  
			'expected'	=> { 
				'H'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> 'not_a_bug@'.$o_test->DOMAIN,
				'Subject'	=> 'Get more hair tomorrow! but no perl in body',
				'From'		=> $o_test->from,
			},
		},
	],
	'mixed'	=> [  
		{ #
			'expected'	=> { 
				'h'			=> [],
				'Q'			=> [],
				'd'			=> '2',
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> '-h -Q -d 2', 
				'From'		=> $o_test->from,
			},
		},
		{ #
			'expected'	=> { 
				'd'			=> '2',
				'h'			=> [],
				'p'			=> [qw(22)],
				'Q'			=> [],
				'r'			=> 'mac ope',
				't'			=> [qw(43)],
				'u'			=> [qw(perlbug)],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> '-h -r mac ope -u perlbug -t43 -Q -d2 -p22', 
				'From'		=> $o_test->from,
			},
		},
		{ #
			'expected'	=> { 
				'f'			=> 'A',
				'h'			=> [],
				'l'			=> [20010821],
				'm'			=> [qw(21 303)],
				'n'			=> [qw(1)],
				'r'			=> 'mac ope',
				'd'			=> '2',
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> '-h -n 1-m21 303 -fA -l   20010821 -r mac ope -d 2', 
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'b'			=> [($BUGID)],
			},
			'header'	=> {
				'To'		=> 'bugdb@'.$o_test->DOMAIN, 
				'Subject'	=> "-b $BUGID $BUGID",
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'Q'			=> [q|db|],
			},
			'header'	=> {
				'To'		=> 'db@'.$o_test->DOMAIN, 
				'Subject'	=> $SUBJECT,
				'From'		=> $o_test->from,
			},
		},
		{ #
			'expected'	=> { 
				'b'			=> [($BUGID)],
				'd'			=> '2',
				'g'			=> [qw(install regex)],
				'p'			=> [qw(22 1311)],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> "-b $BUGID -ginstall    regex   -d2 -p22 1311", 
				'From'		=> $o_test->from,
			},
		},
	],
	'nocommand'	=> [
		{ # 
			'expected'	=> { 
				'nocommand'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> 'Re; this bug '.$o_test->bugid,
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'nocommand'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Cc'		=> $o_test->forward,
				'Subject'	=> 'Re; that in - reply - to bug',
				'From'		=> $o_test->from,
				'In-Reply-To'	=> $inreplytomsgid,
			},
		},
	],
	'note'	=> [
		{ # 
			'expected'	=> {
				'N'	=> $BUGID,
			},
			'header'	=> {
				'To'		=> 'somebody@somewhere.com',
				'Cc'		=> $o_test->bugdb,
				'Subject'	=> "-N $BUGID",
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'N'	=> "note-$BUGID",
			},
			'header'	=> {
				'To'		=> "NoTe-$BUGID@".$o_test->DOMAIN,
				'Subject'	=> 'a new note in to bugid',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'N'	=> "note_$BUGID",
			},
			'header'	=> {
				'To'		=> 'somebody@somewhere.com',
				'Cc'		=> 'NoTe_'.$BUGID.'@'.$o_test->DOMAIN,
				'Subject'	=> 'ccd note',
				'From'		=> $o_test->from,
			},
		},
	],
	'overview'	=> [
		{ #  
			'expected'	=> { 
				'o'			=> [],
				'H'			=> [],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> '-o -H',
				'From'		=> $o_test->from,
			},
		},
		{ #  
			'expected'	=> { 
				'o'			=> [],
			},
			'header'	=> {
				'To'		=> 'overview@'.$o_test->DOMAIN,
				'Subject'	=> 'an overview request',
				'From'		=> $o_test->from,
			},
		},
	],
	'patch'	=> [
		{ # 
			'expected'	=> { 
				'P'	=> '19990422.001 123',
			},
			'header'	=> {
				'To'		=> 'somebody@somewhere.com',
				'Cc'		=> $o_test->bugdb,
				'Subject'	=> '-P 19990422.001 123',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'P'	=> 'patch_19990422.001_123',
			},
			'header'	=> {
				'To'		=> 'somebody@somewhere.com',
				'Cc'		=> 'patch_19990422.001_123@'.$o_test->DOMAIN,
				'Subject'	=> 'ccd administration',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'P'	=> 'patch_xyz '.$BUGID,
			},
			'header'	=> {
				'To'		=> 'PATCH_xyz@'.$o_test->DOMAIN,
				'Subject'	=> "a new patch for $BUGID",
				'From'		=> $o_test->from,
			},
		},
	],
	'perlbug-test'	=> [
		{ #  
			'expected'	=> { 
				'j'	=> 'perlbug-test',
			},
			'header'	=> {
				'To'		=> 'perlbug-test@'.$o_test->DOMAIN,
				'From'		=> $o_test->from,
			},
		},
		{ #  
			'expected'	=> { 
				'j'	=> 'perlbug_test',
			},
			'header'	=> {
				'To'		=> 'PerlBUG_test@'.$o_test->DOMAIN,
				'From'		=> $o_test->from,
			},
		},	
		{ #  
			'expected'	=> { 
				'j'	=> '',
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> '-j',
				'From'		=> $o_test->from,
			},
		},
	],
	'proposal'	=> [ 
		{ #  
			'expected'	=> { 
				'v'			=> ["close aix $BUGID 19870502.008 19870502.007"],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> "-v close aix $BUGID 19870502.008 19870502.007",
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'v'			=> ["propose_close_aix_${BUGID}_19870502.008_19870502.007"],
			},
			'header'	=> {
				'To'	=> 'propose_close_aix_'.$BUGID.'_19870502.008_19870502.007@'.$o_test->DOMAIN,
				'Subject'	=> $SUBJECT,
				'From'		=> $o_test->from,
			},
		},
	],
	'query'	=> [
		{ #  - sql retrieval
			'expected'	=> { 
				'q'			=> [q|select * from pb_bug|],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> '-q select * from pb_bug',
				'From'		=> $o_test->from,
			},
		},
		{ # 10 
			'expected'	=> { 
				'q'			=> [q|select * from pb_bug|],
			},
			'header'	=> {
				'To'		=> 'query@'.$o_test->DOMAIN,
				'Subject'	=> 'select * from pb_bug',
				'From'		=> $o_test->from,
			},
		},
	],
	'quiet'	=> [
		{ # 
			'expected'	=> { 
				'quiet'		=> [$o_mail->message('quiet')],
			},
			'header'	=> {
				'To'		=> 'bugdb_@'.$o_test->domain,
				'Subject'	=> 'a non=recognised address',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'quiet'		=> [$o_mail->message('quiet')],
			},
			'header'	=> {
				'To'		=> 'Note@'.$o_test->domain,
				'Subject'	=> 'a more expected non-recognised address',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'nocommand'		=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> $o_mail->email('bugdb'),
				'From'		=> $o_test->target,
				'Subject'	=> 'from us?',
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				perl
			|,
		},
		{ # 
			'expected'	=> { 
				'quiet'		=> [$o_mail->message('quiet')],
			},
			'header'	=> {
				'To'		=> $o_test->forward,
				'Subject'	=> 'a forward address is not a reply without a bugid', 
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				perl
			|,
		},
		{ # 
			'expected'	=> { 
				'nocommand'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> 'Re; that no bug - no command',
				'From'		=> $o_test->from,
				'In-Reply-To'	=> '<non.existent@bugid>',
			},
		},
	],
	'register'	=> [
		{ # 
			'expected'	=> { 
				'V'	=> 'register',
			},
			'header'	=> {
				'To'		=> 'Register@'.$o_test->DOMAIN,
				'From'		=> '"Richard Foley" <rf\@rfi.net>', 
				'Subject'	=> 'register me',
			},
		},
		{ # 
			'expected'	=> { 
				'V'	=> 'register_me',
			},
			'header'	=> {
				'To'		=> 'register_ME@'.$o_test->DOMAIN,
				'From'		=> '"Richard Foley" <richard.foley\@rfi.net>', 
				'Subject'	=> 'register me',
			},
		},
		{ # 
			'expected'	=> { 
				'V'	=> 'register_rumpelstiltskin',
			},
			'header'	=> {
				'To'		=> 'register_RumpelstiltskiN@'.$o_test->DOMAIN,
				'From'		=> '"Rumperlstiltskin" <some.one\@rfi.net>', 
				'Subject'	=> 'register me',
			},
		},
	],
	'reply'	=> [
		{ # 
			'expected'	=> { 
				'M'		=> $o_test->bugid,
			},
			'header'	=> {
				'To'		=> $o_test->forward,
				'Subject'	=> 'Re; reply via this subject line '.$BUGID,
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'M'		=> $inreplytobugid,
			},
			'header'	=> {
				'To'		=> $o_test->forward,
				'Subject'	=> 'Re; reply via in-reply-to line',
				'From'		=> $o_test->from,
				'In-Reply-To'	=> $inreplytomsgid,
			},
		},	,
		{ # 
			'expected'	=> { 
				'M'		=> $inreplytobugid,
			},
			'header'	=> {
				'To'		=> $o_test->forward,
				'Subject'	=> 'Re; reply via in-reply-to line',
				'From'		=> $o_test->from,
				'In-Reply-To'	=> ' your mail: '.$inreplytomsgid.' "xtra"',
			},
		},	
		{ # 
			'expected'	=> { 
				'M'		=> 'reply_'.$BUGID,
			},
			'header'	=> {
				'To'		=> "reply_$BUGID\@".$o_test->DOMAIN,
				'Subject'	=> 'Re; reply via to line',
				'From'		=> $o_test->from,
			},
		},	
		{ # 
			'expected'	=> { 
				'M'		=> 'reply_123'.$BUGID.'789',
			},
			'header'	=> {
				'To'		=> "reply_123${BUGID}789\@".$o_test->DOMAIN,
				'Subject'	=> 'Re; reply via to line with extended bugid',
				'From'		=> $o_test->from,
			},
		},	
		{ # 
			'expected'	=> { 
				'M'		=> 'reply_'.$BUGID.'_'.$BUGID,
			},
			'header'	=> {
				'To'		=> "REPLy_${BUGID}_$BUGID\@".$o_test->DOMAIN,
				'Subject'	=> 'Re; reply via to line',
				'From'		=> $o_test->from,
			},
		},	
	],
	'test'	=> [
		{ # 
			'expected'	=> { 
				'T'	=> 'test_'.$BUGID,
			},
			'header'	=> {
				'To'		=> 'somebody@somewhere.com',
				'Cc'		=> 'teST_'.$BUGID.'@'.$o_test->DOMAIN,
				'Subject'	=> 'ccd test',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'T'	=> 'test'.$BUGID,
			},
			'header'	=> {
				'To'		=> "Test$BUGID@".$o_test->DOMAIN,
				'Subject'	=> 'a new test in to bugid',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'expected'	=> { 
				'T'	=> $BUGID,
			},
			'header'	=> {
				'To'		=> 'somebody@somewhere.com',
				'Cc'		=> $o_test->bugdb,
				'Subject'	=> "-T $BUGID",
				'From'		=> $o_test->from,
			},
		},
	],
	'unrecognised'	=> [
		{ #  
			'expected'	=> { 
				'nocommand'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Cc'		=> $o_test->bugdb,
				'Subject'	=> 'some request',
				'From'		=> $o_test->from,
			},
		},
		{ #  
		'expected'	=> { # a/v
				'H'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> 'some_request@'.$o_test->DOMAIN,
				'Subject'	=> "Re: $BUGID",
				'From'		=> $o_test->from,
			},
		},
		{
			'expected'	=> { # a/v
				'H'	=> [$o_mail->message('nocommand')],
			},
			'header'	=> {
				'To'		=> 'some_open_close_aix_blablabla@'.$o_test->DOMAIN,
				'Subject'	=> "Re: $BUGID",
				'From'		=> $o_test->from,
			},
		},

	],
);

# How many?
plan('tests' => scalar(keys %tests));

my $i_err = 0;
my $arg = $ARGV[0] || '';
TYPE:
foreach my $type (sort keys %tests) {				# a_bounce, a_bug etc.
	last TYPE unless $i_err == 0;
	if ($arg =~ /^(\w+)/) { next TYPE unless $type eq $arg; }
	$i_test++; 
	TEST:
	foreach my $h_test (sort @{$tests{$type}}) {	# h_anon
		last TEST unless $i_err == 0;				# 
		my $o_int    = $o_test->setup_int($$h_test{'header'}, $$h_test{'body'});
		my %expected = %{$$h_test{'expected'}}; 	# h_anon{
		unless (ref($o_int)) {						# 	'header'	=> 'To: bla bla bla\netc.',
			$i_err++;								#   'expected'	=> [qw(this and that)],
		} else {									# }
			my ($h_cmds, $body) = $o_mail->parse_input($o_int);
			my %cmds = (ref($h_cmds) eq 'HASH') ? %{$h_cmds} : ();
			$DB::single=2;
			CHECK:
			foreach my $key (sort keys %expected) {	# h, H, b, a, j, B, N, P 
				last CHECK unless $i_err == 0;
				my @expected = (ref($expected{$key}) eq 'ARRAY') ? @{$expected{$key}} : ($expected{$key});

				my $TYP = $o_mail->return_type($key);
				my @found = ();
				if ($TYP eq 'HASH') { 
					@found = $cmds{$key}{'opts'};
				} elsif ($TYP eq 'ARRAY') {	
					@found = @{$cmds{$key}};
				} else {
					@found = $cmds{$key};
				}
				my @fnd = ();
				foreach my $fnd (@found) {
					$fnd =~ s/^\s+//;
					$fnd =~ s/\s+$//;
					push(@fnd, $fnd);
				}

				my @notfound = ();
				EXP:
				foreach my $exp (@expected) {	# bugid++, close, aix, etc. 
					last EXP unless $i_err == 0;
					$exp = quotemeta($exp);
					if (!(grep(/^$exp$/, @fnd))) {
						push(@notfound, $exp);
						output("type($type) key($key) TYP($TYP)\n\texp($exp) not found in \n\tfnd(".join(', ', @fnd).")\n"); 
						# $DB::single=2 if $key eq 'N';
						$i_err++;
					}
				}
				delete $cmds{$key} unless scalar(@notfound) >= 1; 
			}	
			if (scalar(keys %cmds) >= 1) {
				$i_err++;
				output("Redundant commands: ".Dumper(\%cmds)) if $Perlbug::DEBUG;
			}
		}
		output("Failed to parse test($type)") unless $i_err == 0; 
	}
	ok(($i_err == 0) ? $i_test : 0);
}	# each type 


# done
