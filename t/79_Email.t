#!/usr/bin/perl -w
# Email tests - runs through complete (parse and process) cycle for each do([aHjBGMNPT]) etc., 
# Using bugdb@* approach (see 78_Email.t for *@bugs.perl.org)
# Richard Foley RFI perlbug@rfi.net
# $Id: 79_Email.t,v 1.3 2001/12/01 15:24:43 richardf Exp $
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
	#
	'doH' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> '-H',
			},
			'body'		=> "Help request\n",
			'expected'	=> '(?ms:^H: => .+)',
		},
	],	
	'doB' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> '-B this is a bug opts linux 5.7.2',
			},
			'body'		=> "some perl bug on linux against 5.7.2\n",
			'expected'	=> '^B: => \d+\.\d+$'
		},
	],	
	'doG' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> "-G newgroupname$$",
			},
			'body'		=> "test insertion group from: ".$o_test->from,
			'expected'	=> '^G: => \d+$'
		},
	],	
	'doM' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> "-M re; $BUGID",
			},
			'body'		=> "some reply to $BUGID\n",
			'expected'	=> '^M: => \d+$'
		},
	],
	'doN' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> "-N opts $BUGID",
			},
			'body'		=> "some note against $BUGID\n",
			'expected'	=> '^N: => \d+$'
		},
	],
	'doP' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> "-P opts $BUGID",
			},
			'body'		=> "some patch against $BUGID\n",
			'expected'	=> '^P: => \d+$'
		},
	],
	'doT' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> "-T opts $BUGID",
			},
			'body'		=> "some test against $BUGID\n",
			'expected'	=> '^T: => \d+$'
		},
	],
	# lc
	'doa' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> "-a close $BUGID",
			},
			'body'		=> "some admin command\n",
			'expected'	=> '(?ms:^a: => \w+)',
		},
	],	
	'doh' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> '-h',
			},
			'body'		=> "help request\n",
			'expected'	=> '(?ms:^h: => .+)',
		},
	],	
	'doj' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> '-j',
			},
			'body'	=> "just want a response\n",
			'expected'	=> '^j: => .*\d+$'
		},
	],
	'doh' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> '-h',
			},
			'body'		=> "with nothing relevant here",
			'expected'	=> '^h: => .+',
		},
	],
	'donocommand' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb,
				'From'		=> $o_test->from,
				'Subject'	=> 'no recognisable commands here',
			},
			'body'		=> "with nothing in here either",
			'expected'	=> '(?ms:^nocommand: => .+)',
		},
	],
	'doquiet' => [
		{ #  
			'header'	=> {
				'To'		=> $o_test->bugdb.'unheard-of.net',
				'From'		=> $o_test->from,
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
	if (ref($a_type) ne 'ARRAY') {
		$i_err++;
		output("no $type tests($a_type)!");
	} else {
		my $call   = substr($type, 2);
		TEST:
		foreach my $h_test (@{$a_type}) {
			my $expected = $$h_test{'expected'};
			my $o_int    = $o_mail->setup_int($$h_test{'header'}, $$h_test{'body'});
			my $h_cmds   = $o_mail->parse_input($o_int);
			my @cmds = keys %{$h_cmds};
			if (!$o_mail->compare([$call], \@cmds)) {
				$i_err++;
				output("intended call($call) not delivered");
				output(Dumper($h_cmds)) if $Perlbug::DEBUG;
			} else {
				my ($result) = $o_mail->process_commands({$call, $$h_cmds{$call}}, $o_int);
				if ($result !~ /$expected/) {
					$i_err++;
					output("Mis-matching type($type) process_commands($call, $$h_cmds{$call}) => \n\texpected($expected) \n\t  result($result)");
				}
			}
			last TEST if $i_err;
		} # each test
	}
	$i_err == 0 ? ok($i_test) : ok(0);
	last TYPE unless $i_err == 0; 
}

#
