#!/usr/bin/perl -w
# Email tests for returns of do(from|h|j|remap(line)|...) etc.
# Richard Foley RFI perlbug@rfi.net
# $Id: 76_Email.t,v 1.8 2001/12/01 15:24:43 richardf Exp $
#

use strict;
use lib qw(../);
use Data::Dumper; 
use FileHandle;
use Mail::Internet;
use Perlbug::Interface::Email;
use Perlbug::Test;
use Sys::Hostname;

my $i_test = 0;

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);

my $DOMAIN = $o_test->DOMAIN;

# Tests
# -----------------------------------------------------------------------------
my %tests = (
	'doh'		=> [
		{ 
			'args'		=> [qw(zip)],
			'expected' 	=> '\w+',
		},	
	],
	'doH'		=> [
		{ 
			'args'		=> [qw(zip)],
			'expected' 	=> '\w+',
		},	
	],
	'doj'		=> [
		{ 
			'args'		=> {
				'to' 		=> 'perlbug-test@'.$DOMAIN, 
				'from' 		=> $o_test->from,
				'replyto'	=> $o_test->replyto,
				'subject' 	=> 'testing the response',
				'header'	=> 'email header',
				'body'		=> 'email body',
			},
			'expected' 	=> '\w+',
		},	
	],
	'default'		=> [
		{ 
			'args'		=> [('To', $o_test->forward)],
			'expected' 	=> quotemeta($o_test->forward),
		},	
	],
	'from'		=> [
		{ 
			'args'		=> [($o_test->from)],
			'expected' 	=> quotemeta($o_test->from),
		},	
		{ 
			'args'		=> [($o_test->bugdb, $o_test->from, $o_test->replyto)],
			'expected' 	=> quotemeta($o_test->from),
		},	
		{ 
			'args'		=> [('', $o_test->bugdb, 'xyz@rfi.net', $o_test->from, ' ')],
			'expected' 	=> 'xyz\@rfi\.net',
		},	
		{ 
			'args'		=> [($o_test->fulladdr, $o_test->from, $o_test->bugdb)],
			'expected' 	=> quotemeta($o_test->fulladdr),
		},	
		{ 
			'args'		=> [qw(this that the other)],
			'expected' 	=> '',
		},	
		{ 
			'args'		=> [($o_test->bugdb, $o_test->target)],
			'expected' 	=> '',
		},	

	],
	'get_forward'		=> [
		{ 
			'args'		=> [('To', $o_test->forward)],
			'expected' 	=> quotemeta($o_test->forward),
		},	
	],
	'in_master_list'	=> [
		{ 
			'args'		=> [('"ABCdef" <xYz@rfi.NET>', ( 
				'xyz@rfi.net', '"XYZ" <XYZ@rfi.net>', 'etc'
				))],
			'expected' 	=> '1',
		},	
		{ 
			'args'		=> [($o_test->bugdb, (
				'xyz@rfi.net', '"XYZ" <XYZ@rfi.net>', 'etc'
				))],
			'expected' 	=> '0',
		},	
	],
	'ok'		=> [
		{ 
			'args'		=> [('To', $o_test->forward)],
			'expected' 	=> quotemeta($o_test->forward),
		},	
	],	
	'remap'		=> [
		{ 
			'args'		=> [('To', $o_test->forward)],
			'expected' 	=> quotemeta($o_test->forward),
		},	
	],
	'spec'		=> [
		{ 
			'args'		=> [qw(a z)],
			'expected' 	=> '\w+',
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
	TEST:
	foreach my $h_test (@{$a_type}) {
		my @args = ref($$h_test{'args'}) eq 'HASH' ? ($$h_test{'args'}) : @{$$h_test{'args'}};
		unless (@args >= 1) {
			$i_err++;
		} else {
			my $expected = $$h_test{'expected'};
			my ($result) = $o_mail->$type(@args);
			if ($result !~ /$expected/) {
				$i_err++;
				output("Mis-matching($type) args(@args) => result($result) expected($expected)");
				output('Mail: '.Dumper($h_test)) if $Perlbug::DEBUG;
				last TEST;
			}
		}
	} # each test

	$i_err == 0 ? ok($i_test) : ok(0);
	last TYPE unless $i_err == 0; 
}

# done
