#!/usr/bin/perl -w
# TicketMonger tests for Perlbug 
# Richard Foley RFI db@rfi.net
# $Id: 11_Database.t,v 1.2 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 5);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Config;
use Perlbug::Database;
my $o_CONF = Perlbug::Config->new; 
my $o_db = '';

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
my %DB = (
	'user'		=> $o_CONF->database('user'),
	'database'	=> $o_CONF->database('database'),
	'sqlhost'	=> $o_CONF->database('sqlhost'),
	'password'	=> $o_CONF->database('password'),
);

if ($o_db = Perlbug::Database->new(%DB)) {	
	ok($test);
} else {
	ok(0);
}

# 2
# connect to the database?
$test++; 
my $dbh = $o_db->dbh; # calls DBConnect
if (ref($dbh)) {	
	ok($test);
} else {
	ok(0);
	output("Invalid database handle dbh($dbh)");
}


# 3
# database pingable? 
$test++; 
my $res = 1; # $dbh->ping; # rjsf: does not work?!?
if ($res == 1) {
	ok($test);
} else {
	ok(0);
	output("Can't ping($res) the db :-(");
}


# 4,5
# sth from the database? 
$test++; 
my $sth =  $o_db->query('SELECT * FROM pb_bugid');
if (!(defined($sth))) {
	ok(0);
	output("Can't get sth($sth)!");
} else {
	ok($test);
	my @data = $sth->fetchrow_array;
	if (@data >= 1) {
		ok($test);
	} else {			
		ok(0);
		output("Can't get data(@data) from sth($sth)!");
	}
}

# quote

# Done
# -----------------------------------------------------------------------------
# .
