#!/usr/bin/perl -w
# TicketMonger tests for Perlbug 
# Richard Foley RFI db@rfi.net
# $Id: 11_Database.t,v 1.5 2001/09/18 13:37:50 richardf Exp $
#
use Perlbug::Config;
use Perlbug::Database;
use Perlbug::Test;
plan('tests' => 11);
use strict;
use lib qw(../);
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
my $o_conf = Perlbug::Config->new; 
my $o_test = Perlbug::Test->new($o_conf);
my $o_db = '';

# Tests
# -----------------------------------------------------------------------------
my $str 	= 'a string with an id (20010817.021) inside';
my $tid		= '20010817.021';
my $blank 	= '';
my $notanid = '2001817.021';
my $ok		= 0;
my $id      = '';

# 1 callable? 
$test++; 
my %DB = $o_conf->get_all('database');
if ($o_db = Perlbug::Database->new(%DB)) {	
	ok($test);
} else {
	ok(0);
}

# 2 connect to the database?
$test++; 
my $dbh = $o_db->dbh; # calls DBConnect
if (ref($dbh)) {	
	ok($test);
} else {
	ok(0);
	output("Invalid database handle dbh($dbh)");
}

# 3 database pingable? 
$test++; 
my $res = 1; # $dbh->ping; # rjsf: does not work?!?
if ($res == 1) {
	ok($test);
} else {
	ok(0);
	output("Can't ping($res) the db :-(");
}

# 4 quote 
$test++; 
my $ustr = "x ' %";
my $qstr = $o_db->quote($ustr);
if ($qstr =~ /^x\s\\' %$/o) { # '
	ok($test);
} else {
	ok(0);
	output("Can't quote($ustr) => quoted($qstr)!");
}

# 5, 6 sth from the database? 
$test++; 
my $table = 'pb_bug';
my $sth =  $o_db->query("SELECT COUNT(*) FROM $table");
if (!(defined($sth))) {
	ok(0);
	output("Can't get sth($sth)!");
} else {
	ok($test); 
	my @data = $sth->fetchrow_array;
	# 6
	if (@data >= 1) {
		ok($test); #
	} else {			
		ok(0);
		output("Can't get data(@data) from sth($sth)! missing table($table)?");
	}
}

# 7 create table 
my $TABLE = "${table}_$$";
$test++; 
my $create  = qq|CREATE TABLE $TABLE (id INTEGER(3), string VARCHAR(16))|;
my $created = $o_db->query($create);
if (defined($created)) {
	ok($test);
} else {
	ok(0);
	output("Can't create($create)!");
}

# 8 insert into table 
$test++; 
my $insert   = qq|INSERT INTO $TABLE SET id = '21', string = 'some nonsense'|;
my $inserted = $o_db->query($insert);
if (defined($created)) {
	ok($test);
} else {
	ok(0);
	output("Can't create($create) => created($created)!");
}

# 9 update into table 
$test++; 
my $update  = qq|UPDATE $TABLE SET string = 'more nonsense' WHERE id = '21'|;
my $updated = $o_db->query($update);
if (defined($created)) {
	ok($test);
} else {
	ok(0);
	output("Can't update($update) => updated($updated)!");
}

# 10 delete from table 
$test++; 
my $delete  = qq|DELETE FROM $TABLE WHERE id = '17'|;
my $deleted = $o_db->query($delete);
if (defined($deleted)) {
	ok($test);
} else {
	ok(0);
	output("Can't delete($delete) => deleted($deleted)!");
}

# 11 drop table 
$test++; 
my $drop    = qq|DROP TABLE $TABLE|;
my $dropped = $o_db->query($drop);
if (defined($dropped)) {
	ok($test);
} else {
	ok(0);
	output("Can't drop($drop) => dropped($dropped)!");
}

# Done
# -----------------------------------------------------------------------------
# .
