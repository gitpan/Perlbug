#!/usr/bin/perl -w
# Cmd tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 65_Cmd.t,v 1.3 2001/10/19 12:40:21 richardf Exp $
#
use Perlbug::Test;
use Perlbug::Interface::Cmd;
use strict;
use lib qw(../);
my $i_test = 0;
my $i_errs = 0;

my $o_cmd = Perlbug::Interface::Cmd->new;
my $o_test = Perlbug::Test->new($o_cmd);

# TESTs
# -----------------------------------------------------------------------------
my %tests = (
	'dob'	=> [
		{ 
			'string'	=> 'b 19870502.007',
			'expected'	=> 'Subject:\s+some email\s+->.+',
		},
	],
	'dod'	=> [
		{ 
			'string'	=> 'd 12 ',
			'expected'	=> '^d: 12 => 12$',
		}
	],
	'doq'	=> [
		{ 
			'string'	=> 'q SELECT COUNT(bugid) FROM pb_bug',
			'expected'	=> '\w+',
		}
	],
);

# How many?
plan('tests' => scalar(keys %tests));

TYPE:
foreach my $type (sort keys %tests) {
	last TYPE unless $i_errs == 0;
	$i_test++; 
	TEST:
	foreach my $h_test (sort @{$tests{$type}}) {
		last TEST unless $i_errs == 0;
		my $string   = $$h_test{'string'}; 
		my $expected = $$h_test{'expected'}; 
		my ($result) = $o_cmd->process($string);
		if ($result !~ /$expected/) {
			output("string($string) did not produce expected($expected) result($result)!\n");
			$i_errs++;
		}
	}
	ok(($i_errs == 0) ? $i_test : 0);
}	# each type 

# done
# .
