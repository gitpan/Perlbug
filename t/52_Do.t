#!/usr/bin/perl -w
# Do retrieval by objectid tests for Perlbug: do (b m p t n u)
# Richard Foley RFI perlbug@rfi.net
# $Id: 52_Do.t,v 1.2 2000/08/08 10:08:55 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 5);
}
use strict;
use Data::Dumper;
use lib qw(../);
my $test = 0;
my $context = 'not defined';


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_perlbug = Perlbug::Base->new;

# Tests
# -----------------------------------------------------------------------------

my %tgt = ( # sigh, the english language!
	'bug'		=> 'tickets', # and history...
	'message'	=> 'messages',
	'patch'		=> 'patches',
    # 'test'		=> 'tests',
	'note'		=> 'notes',
	'user'		=> 'users',
);

# 1..6
foreach my $item (keys %tgt) {
	$test++;
	my $table = $tgt{$item};
	$context = 'do'.substr($item, 0, 1);
	$item = 'ticket' if $item eq 'bug';
	my $target = $item.'id';
	my ($id) = $o_perlbug->get_list("SELECT MAX($target) FROM tm_$table");
	my $i_ok = $o_perlbug->$context($id); 
	if ($i_ok >= 1) {	
		ok($test);
	} else {
		notok($test);
		output("$context($id) failed($i_ok) for item($item) target($target) in table($table)");
	}
}

# Done
# -----------------------------------------------------------------------------
# .
