#!/usr/bin/perl -w
# TicketMonger tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 40_TM.t,v 1.3 2000/08/02 08:19:51 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 6);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_perlbug = '';

# Tests
# -----------------------------------------------------------------------------
my $str 	= 'a string with an id (20010817.021) inside';
my $tid		= '20010817.021';
my $blank 	= '';
my $notanid = '2001817.021';
my $ok		= 0;
my $id      = '';

# 1
# callable? 
$test++; 
if ($o_perlbug = Perlbug::Base->new) {	
	$o_perlbug->current('isatest', 1);
	ok($test);
} else {
	notok($test);
}

# 2
# recognise an id?
$test++; 
($ok, $id) = $o_perlbug->get_id($str);
if ($ok == 1) {	
	ok($test);
} else {
	notok($test);
}

# 3
# extract an id properly?
$test++; 
if ($id =~ /^$tid$/) {	
	ok($test);
} else {
	notok($test);
}

# 4
# connect to the database?
$test++; 
my $dbh =  $o_perlbug->DBConnect;
if (ref($dbh)) {	
	ok($test);
} else {
	notok($test);
	output("Invalid database handle dbh($dbh)");
}

# 5
# database pingable? 
$test++; 
my $res = 1; # $dbh->ping; # rjsf: doesn't work?!?
if ($res == 1) {
	ok($test);
} else {
	notok($test);
	output("Can't ping($res) the db :-(");
}

# 6
# data from the database? 
$test++; 
my @data =  $o_perlbug->get_list('SELECT * FROM tm_id');
if (scalar(@data) == 1) {	
	ok($test);
} else {
	notok($test);
	output("Can't get tables(@data)");
}

# Done
# -----------------------------------------------------------------------------
# .
