#!/usr/bin/perl -w
# Email tests for Perlbug: decisions of switch() => do_...() 
# Richard Foley RFI perlbug@rfi.net
# $Id: 74_Email.t,v 1.8 2001/12/01 15:24:43 richardf Exp $
#

use lib qw(../);
use strict;
use Data::Dumper;
use Perlbug::Interface::Email;
use Perlbug::Test; 

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);
my $i_test = 0;

my $BUGID  = $o_test->bugid;
my $INREPLYTOMSGID = $o_test->inreplytomsgid;
#my ($INREPLYTOMSGID) = $o_mail->get_list(
#	"SELECT MAX(email_msgid) FROM pb_bug WHERE email_msgid LIKE '%_\@_%'"
#);

# Tests 
# -----------------------------------------------------------------------------
my %tests = (
	'bounce'	=> [
		{ #  
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'Get more sex today! but no body perl',
				'From'		=> $o_test->from,
			},
		},
		{ #  
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'Get more sex today! but no perl in body',
				'From'		=> $o_test->from,
			},
			'body'		=> qq| a per l bug	|,
		},
	],
	'B'	=> [ # bug
		{ # 
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'new to/body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq| a perl bug	|,
		},
		{ # 
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'another new to/Body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq| a nother pErlbUG 	|,
		},
		{ # 
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'a target/body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq| perl |,
		},
		{ # 
			'header'	=> {
				'To'		=> 'mickey@mouse.rfi.net',
				'Cc'		=> 'minnie@mouse.rfi.net',
				'Cc'		=> $o_test->target,
				'Subject'	=> 'OK: new bug perl installed fine on cc',
				'From'		=> $o_test->from,
			},
			'body'		=> qq| perl |,
		},
		{ # 
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'a new to/body bug',
				'From'		=> $o_test->from,
			},
			'body'		=> qq| perlisofous |,
		},
	],
	'nocommand'	=> [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> 'Get more rubbish today!',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->target,
				'Subject'	=> 'from us with no cmds?',
				'From'		=> $o_test->from,
			},
			'body'		=> qq| xerl |,
		},
		{ # 
			'header'	=> {
				'To'		=> $o_mail->email('bugdb'),
				'Subject'	=> 'Re; that no bug cmds',
				'From'		=> $o_test->from,
				'In-Reply-To'	=> '<non.existent@bugid>',
			},
		},
	],
	'quiet'		=> [
		{ # 
			'header'	=> {
				'To'		=> 'xyz@'.$o_test->DOMAIN,
				'Subject'	=> 'Re; that no bug cmds',
				'From'		=> $o_test->from,
				'In-Reply-To'	=> '<non.existent@bugid>',
			},
		},
		{ # 
			'header'	=> {
				'To'		=> $o_mail->email('bugdb').'x',
				'Subject'	=> 'a non=recognised address',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'header'	=> {
				'To'		=> 'Note@'.$o_test->domain,
				'Subject'	=> 'a more expected non-recognised address',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'header'	=> {
				'To'		=> $o_test->forward,
				'Subject'	=> 'a forward address is not a new bug', # should be bounce?
				'From'		=> $o_test->from,
			},
			'body'		=> qq|
				perl
			|,
		},
		{ #  
			'header'	=> {
				'To'		=> 'bug@'.$o_test->DOMAIN,
				'Subject'	=> 'Get more hair tomorrow! but no perl',
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'header'	=> {
				'To'		=> 'Note@'.$o_test->DOMAIN,
				'Subject'	=> "a new note but no perl",
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'header'	=> {
				'To'		=> 'PATCH_xyz@'.$o_test->DOMAIN,
				'Subject'	=> "a new patch but no perl",
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'header'	=> {
				'To'		=> 'test_NOBUGID@'.$o_test->DOMAIN,
				'Subject'	=> "a new test but no perl",
				'From'		=> $o_test->from,
			},
		},
	],
	'M'	=> [
		{ # 
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'Subject'	=> 'Re; this bug '.$o_test->bugid,
				'From'		=> $o_test->from,
			},
		},
		{ # 
			'header'	=> {
				'To'		=> $o_test->target,
				'Subject'	=> 'Re; that in-reply bug',
				'From'		=> $o_test->from,
				'In-Reply-To'	=> $INREPLYTOMSGID,
			},
		},

	],
);


# How many?
plan('tests' => scalar(keys %tests));

TYPE:
foreach my $expected (sort keys %tests) {
	my $a_type = $tests{$expected};
	my $i_err = 0;
	TEST:
	foreach my $h_test (@{$a_type}) {
		$i_test++; 
		my $o_int    = $o_test->setup_int($$h_test{'header'}, $$h_test{'body'});
		unless (ref($o_int)) {
			$i_err++;
		} else {
			my ($switch, $msg) = $o_mail->switch($o_int);
			if ($switch ne $expected) {
				$i_err++;
				output("Mis-matching switch($switch) expected($expected): msg($msg)");
				output('Mail: '.Dumper($o_int->head->header).Dumper($o_int->body)) if $Perlbug::DEBUG;
				last TEST;
			}
		}
	} # each test

	$i_err == 0 ? ok($i_test) : ok(0);
	last TYPE unless $i_err == 0;
}


# done
