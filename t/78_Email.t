#!/usr/bin/perl -w
# Email tests for do([jBGMNPT]) etc., 
# Richard Foley RFI perlbug@rfi.net
# $Id: 78_Email.t,v 1.6 2001/10/05 08:20:58 richardf Exp $
#

use strict;
use lib qw(../);
use Data::Dumper; $Data::Dumper::Indent=1;
use FileHandle;
use Mail::Internet;
use Perlbug::Interface::Email;
use Perlbug::Test;
use Sys::Hostname;

my $i_test = 0;

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);

my $BUGID  = $o_test->bugid;

# Tests
# -----------------------------------------------------------------------------
my %tests = (
	'dobounce' => [
		{ #  
			'header'	=> {
				'From'		=> $o_test->from,
				'To'		=> $o_test->target,
				'Subject'	=> "should bounce with a bugid",
			},
			'body'		=> "with nothing relevant here",
			'expected'	=> '^bounce: => .+\d+$',
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
			'expected'	=> '^quiet: => .*\d+$',
		},
	],
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
	'doB' => [
		{ #  
			'header'	=> {
				'To'		=> 'perlbug@'.$o_test->domain,
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
			'body'		=> "some group\n",
			'expected'	=> '^G: => \d+$'
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
				'To'		=> 'test@'.$o_test->DOMAIN,
				'Subject'	=> "re; $BUGID",
			},
			'body'		=> "some test\n",
			'expected'	=> '^T: => \d+$'
		},
	],
);

# How many?
plan('tests' => scalar(keys %tests));

my @args = ($ARGV[0] =~ /^\w+$/) ? ($ARGV[0]) : keys %tests;

TYPE:
foreach my $type (sort @args) {
	my $a_type = $tests{$type};
	my $call   = substr($type, 2);
	my $i_err  = 0;
	$i_test++; 
	TEST:
	foreach my $h_test (@{$a_type}) {
		my $expected = $$h_test{'expected'};
		my $o_int    = $o_mail->setup_int($$h_test{'header'}, $$h_test{'body'});
		my $h_cmds   = $o_mail->parse_input($o_int);
		$DB::single=2;
		my ($result) = $o_mail->process_commands({$call, $$h_cmds{$call}}, $o_int);
		$DB::single=2;
		if ($result !~ /$expected/) {
			$i_err++;
			output("Mis-matching type($type) process_commands($call, $$h_cmds{$call}) => \n\texpected($expected) \n\t  result($result)");
			last TYPE;
		}
	} # each test

	$i_err == 0 ? ok($i_test) : ok(0);
	# last TYPE unless $i_err == 0; 
}

#
