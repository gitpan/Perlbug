#!/usr/bin/perl -w
# Format (format_data) tests for all objects (b m p t n u) for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 35_Format.t,v 1.2 2000/08/08 10:05:49 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 6);
}
use strict;
use Data::Dumper;
use lib qw(../);
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_fmt = Perlbug::Base->new;

# Tests
# -----------------------------------------------------------------------------

# 1
# nope
$test++;
my %unrec = (
	'unrecognised object' => 'something',
	'someid' => '123',
	'xid' => 'abc',
);
my $i_nok = $o_fmt->format_data(\%unrec);
if ($i_nok == 0) {	
	ok($test);
} else {
	notok($test);
	output("format_data(\%unrec) failed -> $i_nok");
}

my %tgt = ( # sigh, the english language!
	'bug'		=> 'tickets', # and history...
	'message'	=> 'messages',
	'patch'		=> 'patches',
  # 'test'		=> 'tests',
	'note'		=> 'notes',
	'user'		=> 'users',
);


# 2..6
foreach my $item (keys %tgt) {
	$test++;
	my $table = $tgt{$item};
	my $context = 'do'.substr($item, 0, 1);
	$item = 'ticket' if $item eq 'bug';
	my $target = $item.'id';
	my ($id) = $o_fmt->get_list("SELECT MAX($target) FROM tm_$table");
	my $i_ok = $o_fmt->$context($id);
	my $curr = $o_fmt->_current_target;
	$i_ok = $o_fmt->format_data($curr) if $i_ok == 1; 
	if ($i_ok >= 1) {	
		ok($test);
	} else {
		notok($test);
		output("format_data $context($id) failed($i_ok) for item($item) target($target) in table($table)");
	}
}

# Done
# -----------------------------------------------------------------------------
# .
