#!/usr/bin/perl -w
# Do retrieval by objectid tests for Perlbug: do (b m p t n u)
# Richard Foley RFI perlbug@rfi.net
# $Id: 52_Do.t,v 1.4 2001/03/31 16:15:01 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 7);
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

my @tgts = grep(!/^(parent|child)$/, ($o_perlbug->things('mail'), 'group', 'user')); 

# 1..6
foreach my $item (sort @tgts) {
	$test++;
	my $o_obj = $o_perlbug->object($item);
	my $table = $o_obj->attr('table');
	my $target = $o_obj->primary_key;
	$context = 'do'.substr($item, 0, 1);
	my ($id) = $o_perlbug->get_list("SELECT MAX($target) FROM $table");
	my $i_ok = $o_perlbug->$context($id); 
	if ($i_ok >= 1) {	
		ok($test);
	} else {
		ok(0);
		output("$context($id) failed($i_ok) for item($item) target($target) in table($table)");
	}
}

# Done
# -----------------------------------------------------------------------------
# .
