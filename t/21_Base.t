#!/usr/bin/perl -w
# Base object calls
# Richard Foley RFI perlbug@rfi.net
# $Id: 21_Base.t,v 1.2 2001/12/01 15:24:43 richardf Exp $
#

use strict;
use lib qw(../);
use Data::Dumper;
use Perlbug::Base;
use Perlbug::Test;

my $i_test = 0;

my $o_base = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_base);

# Tests
# -----------------------------------------------------------------------------
my %tests = (
	'cgi' => [
		{ 
			'args'		=> [(-nodebug)],
			'expected' 	=> 'ref', 
		},
	],
	'db' => [
		{ 
			'args'		=> [()],
			'expected' 	=> 'ref', 
		},
	],
	'log' => [
		{ 
			'args'		=> [()],
			'expected' 	=> 'ref', 
		},
	],
	'object' => [
		{ 
			'args'		=> [qw(bug)],
			'expected' 	=> 'ref', 
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
		my @args     = @{$$h_test{'args'}};
		my $expected = $$h_test{'expected'};
		my $result = $o_base->$call(@args);
		unless (
		  ($expected eq 'ref' &&   (ref($result))) || 
		  ($expected eq 'undef' && !ref($result))  || 
		  ($expected eq $result)
		  ) {
			$i_err++;
			output("Mis-matching($type) args(@args) => expected($expected) result($result)");
			output('Header: '.Dumper($h_test)) if $Perlbug::DEBUG;
			last TEST;
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

