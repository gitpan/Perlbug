#!/usr/bin/perl -w
# Perlbug::Interface::$interface::do.() calls (b c d g h m n p q r s t u etc.)
# Richard Foley RFI perlbug@rfi.net
# $Id: 60_Interface.t,v 1.1 2001/09/18 13:37:50 richardf Exp $
#
# NB. There are more than 25 tests / per / interface here, it seemed a bit of 
#     a cheat to claim this as 100+ tests, although perfectly true, so I have 
#     instead called each interface (pos. + neg. = * 2) the tests instead.
#

use strict;
use lib qw(../);
use Data::Dumper;
use Perlbug::Base;
use Perlbug::Interface::Cmd;
use Perlbug::Interface::Email;
use Perlbug::Interface::Web;
use Perlbug::Test;

my $i_errs = 0;
my $i_test = 0;

my $o_base  = Perlbug::Base->new;
my $o_test  = Perlbug::Test->new($o_base);
my @interfaces = map { 'Perlbug::'.$_ } ('Base', map { 'Interface::'.$_ } qw(Cmd Email Web));
plan('tests' => (scalar(@interfaces) * 2));

# Tests
# -----------------------------------------------------------------------------
my $o_obj = $o_base->object('user');
my $table = $o_obj->attr('table');
my $prime = $o_obj->primary_key;

my %tgt = ( # 
	'b'		=> [$o_test->bugid],
	'c'		=> [qw(1)],
	'd'		=> '0',
	'f'		=> 'a',
	'g'		=> [qw(1)],
	'h'		=> '',
	'k'		=> [$o_test->bugid],
	'm'		=> [qw(1)],
	'n'		=> [qw(1)],
  # 'o'	=> '', 					# overview (takes too long)
	'p'		=> [qw(1)],
	'q'		=> "SELECT COUNT($prime) FROM $table", 	# sql query
	'r'		=> 'not much data',		# retrieve by body 
	's'		=> 'realclean',			# subject - ditto
	't'		=> [qw(1)],
	'u'		=> [$o_test->isadmin],
);

my %xtgt = ( # 
	'b'		=> ['un-recognised bugid'],
	'c'		=> ['u_n_ k_n - o n o_w [ hE-RE ]'], 
	'f'		=> '',
	'g'		=> [' \' '],
	'm'		=> [' \" '],
	'n'		=> [' &543! '],
	'p'		=> [' no * such_patchid '],
	'q'		=> "SELECT * FROM $table WHERE 1 = 0",
	'r'		=> 'this 41 is ext-rem_elt_tlitlty un_lik-ly 2B theirs asdl- now() ss', 
	's'		=> 'no tVeRy-eq\ually likl ey to f_IND any upper(tnhi at all nghasd\\fvmn)',
	't'		=> [' \_ '],
	'u'		=> [''],
);

# DOIT

my $test = 0;
POS:
foreach my $interface (@interfaces) {
	$i_test++;
	$i_errs = 0;
	$test   = 0;
	my $o_interface = new $interface ('no_debug');
	Perlbug::Test->new($o_interface);

	# TARGET 
	foreach my $tgt (sort keys %tgt) {
		$test++;
		my $context = "do$tgt";
		my $args    = $tgt{$tgt};
		my ($res)   = $o_interface->$context($args); 
		if ($res !~ /\w+/) {	
			$i_errs++;
			output("positive $interface test($test) $context($args) failed($res)");
			last POS;
		}
	}

	if ($i_errs == 0) {
		ok($i_test);
	} else {
		ok(0);
		output("$test failed($i_errs)");
		last POS;
	}
}

NEG:
foreach my $interface (@interfaces) {
	$i_test++;
	$i_errs = 0;
	$test   = 0;
	my $o_interface = new $interface ('no_debug');
	Perlbug::Test->new($o_interface);

	# !TARGET
	foreach my $xtgt (sort keys %xtgt) {
		$test++;
		my $context = "do$xtgt";
		my $xargs   = $xtgt{$xtgt};
		my ($res)   = $o_interface->$context($xargs); 
		if (defined($res) && $res =~ /\w+/o) {	
			$i_errs++;
			output("negative $interface test($test) x $context($xargs) failed($res)");
			last NEG;
		}
	}

	if ($i_errs == 0) {
		ok($i_test);
	} else {
		ok(0);
		output("$test failed($i_errs)");
		last NEG;
	}
}

# Done
# -----------------------------------------------------------------------------
# .
