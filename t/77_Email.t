#!/usr/bin/perl -w
# Email tests against(o_hdr) -> out=ref(o_hdr|o_send|undef|1|0)?
# Richard Foley RFI perlbug@rfi.net
# $Id: 77_Email.t,v 1.5 2001/09/18 13:37:50 richardf Exp $
#

use strict;
use lib qw(../);
use Data::Dumper;
use FileHandle;
use Mail::Internet; $Data::Dumper::Indent=1;
use Perlbug::Interface::Email;
use Perlbug::Test;
use Sys::Hostname;

my $i_test = 0;

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);

# Tests
# -----------------------------------------------------------------------------
my %tests = (
	'check_incoming' => [
		{ 
			'header'	=> {
				'From'		=> 'thine@rfi.net',
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> '1', 
		},
		{ 
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> '1', 
		},
		{ 
			'header'	=> {
				'From'		=> $o_test->bugdb,
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> '0', 
		},
		{ 
			'header'	=> {
				'From'		=> 'thine@rfi.net',
				'To'		=> $o_test->forward,
			},
			'expected' 	=> '1', 
		},
		{ 
			'header'	=> {
				'From'		=> $o_test->target,
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> '0', 
		},
		{ 
			'header'	=> {
				'From'		=> 'thine@rfi.net',
				'To'		=> $o_test->bugdb,
				'X-Perlbug'	=> 'defined',
			},
			'expected' 	=> '0', 
		},

		{ 
			'header'	=> {
				'From'		=> 'postmaster',
				'To'		=> $o_test->bugdb,
			},
			'expected' 	=> '0', 
		},
	],
	'clean_header' => [
		{ 
			'header'	=> {
				'From'		=> 'thine@rfi.net',
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> 'ref', 
		},
		{ 
			'header'	=> {
				'From'		=> '',
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> 'undef', 
		},
	],
	'defense' => [
		{ 
			'header'	=> {
				'From'		=> 'they@rfi.net',
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> 'ref', 
		},
		{ 
			'header'	=> {
				'From'		=> 'they@rfi.net',
				'To'		=> '',
			},
			'expected' 	=> 'undef', 
		},
	],
	'get_header-default' => [
		{ 
			'header'	=> {
				'From'		=> 'thee@rfi.net',
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> 'ref', 
		},	
		{ 
			'header'	=> {
				'From'		=> '',
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> 'undef', 
		},	
	],
	'get_header-ok' => [
		{ 
			'header'	=> {
				'From'		=> 'thy@rfi.net',
				'To'		=> 'perlbug@'.$o_test->DOMAIN,
			},
			'expected' 	=> 'ref', 
		},	
		{ 
			'header'	=> {
			},
			'expected' 	=> 'undef',
		},	
	],
	'get_header-remap' => [
		{ 
			'header'	=> {
				'From'		=> 'thou@rfi.net',
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> 'ref', 
		},	
		{
			'header'	=> {
				'From'		=> '',
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> 'undef',
		},
	],
	'trim_to' => [
		{ 
			'header'	=> {
				'From'		=> 'them@rfi.net',
				'To'		=> 'xperlbug@'.$o_test->domain,
			},
			'expected' 	=> 'ref', 
		},
		{ 
			'header'	=> {
				'From'		=> 'them@rfi.net',
				'To'		=> '',
			},
			'expected' 	=> 'undef',
		},
	],
);

# How many?
plan('tests' => scalar(keys %tests));

TYPE:
foreach my $type (sort keys %tests) {
	my $a_type = $tests{$type};
	my $i_err = 0;
	$i_test++; 
	my ($call, $arg) = split('-', $type);
	TEST:
	foreach my $h_test (@{$a_type}) {
		my $o_int    = $o_test->setup_int($$h_test{'header'});
		my $expected = $$h_test{'expected'};
		unless (ref($o_int)) {
			($i_err++ && last TEST) unless $expected =~ /^(undef|0)$/o;
		} else {
			my $result = $o_mail->$call($o_int->head, $arg);
			unless (
			  ($expected eq 'ref' &&   (ref($result))) || 
			  ($expected eq 'undef' && !ref($result))  || 
			  ($expected eq $result)
			  ) {
				$i_err++;
				output("Mis-matching($type) expected($expected) result($result)");
				output('Header: '.Dumper($$h_test{'header'}));
				last TEST;
			#} else {
			#	output("expected($expected) got($result)");
			}
		}
	} # each test

	$i_err == 0 ? ok($i_test) : ok(0);
	last TYPE unless $i_err == 0; 
}

# done

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

__END__

'X-Perlbug'
Reply-To: perlbug@perl.org x
Reply-To: xperlbug@perl.org y 

From: "Richard Foley" <not_in_any_list_I_know_of@rfi.net>   
Subject: register -> propose

# extract address from p5p
From: "Richard Foley" <richard.foley@rfi.net>   
Subject: register -> ok

# remap
.org|.com -> p5p
 
To: funny+looking+address%%line-here.@perl.org                                                          
Should get_forward(generic) while unrecognised To:

To: perlbug@perl.org
Cc: "perlbug db" <perlbug@perl.org>
Cc: "perlbug db" <perlbug@perl.com>
Cc: "etcasd9w08452n hj34rhj12v 3478 sdfgh " <perlbug@perl.com>
From: rf@rfi.net
Subject: over the rainbow
-> p5p

To: fictitious_perlbug@perl.org
Cc: "not seen before" <fictitious_perlbug@perl.org>
Cc: "never seen" fictitious_perlbug@perl.org
-> ?

To: .org
From: .com
-> fail 

To: "some dodgy address" perlbug@perl.org 
-> fail

