#!/usr/bin/perl -w
# Email tests - runs through complete (parse and process) cycle for each do([aHjBGMNPT]) etc., 
# Using *@bugs.perl.org approach (see 79_Email.t for bugdb@*)
# Richard Foley RFI perlbug@rfi.net
# $Id: 78_Email.t,v 1.7 2001/12/01 15:24:43 richardf Exp $
#

use strict;
use lib qw(../);
use Data::Dumper;
use Perlbug::Interface::Email;
use Perlbug::Test;

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);

my $BUGID  = $o_test->bugid;

# Tests
# -----------------------------------------------------------------------------
my %tests = ( # UC->lc
	# UC
	'doH' => [
		{ #  
			'header'	=> {
				'To'		=> 'help@'.$o_test->DOMAIN,
				'From'		=> $o_test->from,
			},
			'body'		=> "Help request\n",
			'expected'	=> '(?ms:^H: => .+)',
		},
	],	
	'doB' => [
		{ #  
			'header'	=> {
				'To'		=> 'bug@'.$o_test->DOMAIN,
				'From'		=> $o_test->from,
			},
			'body'		=> "some perl bug\n",
			'expected'	=> '^B: => \d+\.\d+$'
		},
	],	
	'doG' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> "group_xgroup$$@".$o_test->DOMAIN,
				'Subject'	=> "new group",
			},
			'body'		=> "test insertion group from: ".$o_test->from,
			'expected'	=> '^G: => \d+$'
		},
	],	
	'doM' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> 'reply@'.$o_test->DOMAIN,
				'Subject'	=> "re; $BUGID",
			},
			'body'		=> "some reply\n",
			'expected'	=> '^M: => \d+$'
		},
	],
	'doN' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> 'note@'.$o_test->DOMAIN,
				'Subject'	=> "re; $BUGID",
			},
			'body'		=> "some note\n",
			'expected'	=> '^N: => \d+$'
		},
	],
	'doP' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> 'patch@'.$o_test->DOMAIN,
				'Subject'	=> "re; $BUGID",
			},
			'body'		=> "some patch\n",
			'expected'	=> '^P: => \d+$'
		},
	],
	'doT' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> 'test_close_'.$BUGID.'@'.$o_test->DOMAIN,
				'Subject'	=> 'this is a test',
			},
			'body'		=> "a test from michael schwern\n",
			'expected'	=> '^T: => \d+$'
		},
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> 'test@'.$o_test->DOMAIN,
				'Subject'	=> "re; $BUGID",
			},
			'body'		=> "some test\n",
			'expected'	=> '^T: => \d+$'
		},
	],
	# lc
	'doa' => [
		{ #  
			'header'	=> {
				'To'		=> "close_$BUGID".'@'.$o_test->DOMAIN,
				'From'		=> $o_test->from,
			},
			'body'		=> "some admin command\n",
			'expected'	=> '(?ms:^a: => \w+)',
		},
	],	
	'doh' => [
		{ #  
			'header'	=> {
				'To'		=> 'help@'.$o_test->DOMAIN,
				'From'		=> $o_test->from,
			},
			'body'		=> "help request\n",
			'expected'	=> '(?ms:^h: => .+)',
		},
	],	
	'doj' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> "perlbug-test@".$o_test->DOMAIN,
				'Subject'	=> "just want a response",
			},
			'body'		=> "???\n",
			'expected'	=> '^j: => .*\d+$'
		},
	],
	'donocommand' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> $o_test->bugdb,
				'Subject'	=> 'no recognisable commands here',
			},
			'body'		=> "with nothing in here either",
			'expected'	=> '(?ms:^nocommand: => .+)',
		},
	],
	'doquiet' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> $o_test->target,
				'Subject'	=> 'Grow more hair today!',
			},
			'body'		=> "silent spam :-)",
			'expected'	=> '^quiet: => quiet ok$',
		},
	],
);

# How many?
plan('tests' => scalar(keys %tests));
my @args = (defined($ARGV[0])) ? ($ARGV[0]) : keys %tests;
my $i_test = 0;

TYPE:
foreach my $type (sort @args) {
	$i_test++; 
	my $i_err = 0;
	my $a_type = $tests{$type};
	my $call   = substr($type, 2);
	TEST:
	foreach my $h_test (@{$a_type}) {
		my $expected = $$h_test{'expected'};
		my $o_int    = $o_mail->setup_int($$h_test{'header'}, $$h_test{'body'});
		my $h_cmds   = $o_mail->parse_input($o_int);
		output("call($call) cmds: ".Dumper($h_cmds)) if $Perlbug::DEBUG;
		$DB::single=2;
		my ($result) = $o_mail->process_commands({$call, $$h_cmds{$call}}, $o_int);
		$DB::single=2;
		if ($result !~ /$expected/) {
			$i_err++;
			output("Mis-matching type($type) process_commands($call, $$h_cmds{$call}) => \n\texpected($expected) \n\t  result($result)");
			last TEST;
		}
	} # each test
	$i_err == 0 ? ok($i_test) : ok(0);
	last TYPE unless $i_err == 0; 
}

#
