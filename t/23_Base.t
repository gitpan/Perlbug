#!/usr/bin/perl -w
# Base tests for help(), spec() etc., things that return swathes of data etc.
# Richard Foley RFI perlbug@rfi.net
# $Id: 23_Base.t,v 1.1 2001/09/18 13:37:50 richardf Exp $
#

use strict;
use lib qw(../);
use Data::Dumper; 
use Perlbug::Base;
use Perlbug::Test;
use Sys::Hostname;

my $i_test = 0;

my $o_base = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_base);

# Tests
# -----------------------------------------------------------------------------
my %tests = (
	'help'		=> [
		{ 
			'args'		=> [()],
			'expected' 	=> '[a-zA-Z]+',
		},	
		
	],
	'spec'		=> [
		{ 
			'args'		=> [()],
			'expected' 	=> '[a-zA-Z]+',
		},	
	],
	'tell_time'	=> [
		{ 
			'args'		=> [()],
			'expected' 	=> '[a-zA-Z]+',
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
		my @args     = @{$$h_test{'args'}};
		my $expected = $$h_test{'expected'};
		my ($result) = $o_base->$type(@args);
		if ($result !~ /$expected/) {
			$i_err++;
			output("Mis-matching($type) args(@args) => expected($expected) result($result)");
			last TYPE;
		}
	} # each test

	$i_err == 0 ? ok($i_test) : ok(0);
	last TYPE unless $i_err == 0; 
}

#
