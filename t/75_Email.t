#!/usr/bin/perl -w
# Email tests: checking returns from admin checking methods eg; check_user('spaceship') => 0
# Richard Foley RFI perlbug@rfi.net
# $Id: 75_Email.t,v 1.5 2001/09/18 13:37:50 richardf Exp $
#

use strict;
use lib qw(../);
use Data::Dumper;
use Perlbug::Interface::Email;
use Perlbug::Test;

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);
my $i_test = 0;

$o_mail->current({'admin' => ''});

# Tests 
# -----------------------------------------------------------------------------
my %tests = (
	'check_user'		=> [
		{ 
			'header'	=> {
				'From'		=> $o_test->admin,
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> 'richardf',
		},	
		{ 
			'header'	=> {
				'From'		=> '"Xtra-terrestrial" <'.$o_test->admin.'>',
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> 'richardf',
		},
		{ 
			'header'	=> {
				'From'		=> '"Xtra-terrestrial" <'.$o_test->admin.'.com>',
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> '',
		},
		{ 
			'header'	=> {
				'From'		=> 'bla bla bla',
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> '',
		},
		{ 
			'header'	=> {
				'From'		=> '"Xtra-terrestrial" <'.$o_test->domain.'>',
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> '',
		},
	],
	'isadmin'			=> [	
		{
			'header'	=> {
				'From'		=> $o_test->admin,
				'To'		=> 'perlbug@'.$o_test->DOMAIN,
			},
			'expected' 	=> 'richardf',
		},
		{
			'header'	=> {
				'From'		=> 'never_heard_of_him@xxx.rf-i.net',
				'To'		=> 'perlbug@'.$o_test->domain,
			},
			'expected' 	=> '',
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
		my $o_int    = $o_mail->setup_int($$h_test{'header'});
		unless (ref($o_int)) {
			$i_err++;
		} else {
			my $expected = $$h_test{'expected'};
			$o_mail->check_user($o_int->head) unless $type eq 'check_user';
			my $result = $o_mail->$type($o_int);
			$o_mail->current({'admin' => ''});
			if ($result !~ /$expected/) {
				$i_err++;
				output("Mis-matching($type) result($result) expected($expected)");
				output('Mail: '.Dumper($o_int->head->header).Dumper($o_int->body));
				last TYPE;
			}
		}
	} # each test

	$i_err == 0 ? ok($i_test) : ok(0);
	last TYPE unless $i_err == 0; 
}

# done
