#!/usr/bin/perl -w
# Perlbug::Interface::$interface::do.() calls (b c d g h m n p q r s t u etc.)
# Richard Foley RFI perlbug@rfi.net
# $Id: 60_Interface.t,v 1.2 2001/12/01 15:24:43 richardf Exp $
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
my @interfaces = map { 'Perlbug::'.$_ } (map { 'Interface::'.$_ } qw(Cmd Email Web));
plan('tests' => (scalar(@interfaces) * 2));

# Tests
# -----------------------------------------------------------------------------
my $o_obj = $o_base->object('user');
my $table = $o_obj->attr('table');
my $prime = $o_obj->primary_key;

my %pos = ( # 
	'b'		=> [$o_test->bugid],
	'c'		=> [$o_test->changeid],
	'd'		=> '0',
  # 'e' 	=> means different things to each interface
	'f'		=> 'a',
	'g'		=> [qw(1)],
	'h'		=> '',
	'j'		=> {},
	'k'		=> [$o_test->bugid],
	'm'		=> [$o_test->messageid],
	'n'		=> [$o_test->noteid],
  # 'o'		=> overview (takes too long)
	'p'		=> [qw(1)],
	'q'		=> "SELECT COUNT($prime) FROM $table", 	# sql query
  #	'r'		=> see 23_Base.t
  #	's'		=> see 23_Base.t
	't'		=> [$o_test->testid],
	'u'		=> [$o_test->isadmin],
);

my %neg = ( # 
	'b'		=> ['un-recogniS_able bugid'],
	'c'		=> ['u_n_ k_n - o n o_w [ hE-RE ]'], 
	'f'		=> '',
	'g'		=> [' \' '],
	'm'		=> [' \" '],
	'n'		=> [' &543! '],
	'p'		=> [' no * such_patchid '],
	'q'		=> "SELECT * FROM $table WHERE 1 = 0",
	't'		=> [' \_ '],
	'u'		=> [''],
);

# DOIT

PN:
foreach my $cxt (qw(pos neg)) {
	my $test = 0;
	my %tgt  = (($cxt eq 'pos') ? %pos : %neg);

	INT:	
	foreach my $interface (@interfaces) {
		$i_test++;
		$i_errs = 0;
		$test   = 0;
		my $o_interface = new $interface ('no_debug');
		Perlbug::Test->new($o_interface);

		my @wanted = (defined($ARGV[0]) && $ARGV[0] =~ /^([a-z])$/) ? ($1) : keys %tgt;
		# TARGET 
		# foreach my $tgt (sort keys %tgt) {
		foreach my $tgt (sort @wanted) {
			$test++;
			my $context = "do$tgt";
			my $args    = $tgt{$tgt};
			my ($res)   = $o_interface->$context($args); 
			if (
				($cxt eq 'pos' && !(defined($res) && $res =~ /\w+/o)) ||
				($cxt eq 'neg' &&   defined($res) && $res =~ /\w+/o)
			) {	
				$i_errs++;
				output("$cxt $interface test($test) $context($args) failed($res)");
				exit;
			}
		}	

		if ($i_errs == 0) {
			ok($i_test);
		} else {
			ok(0);
			output("$cxt $test failed($i_errs)");
			last PN;
		}
	}
}

# Done
# -----------------------------------------------------------------------------
# .
