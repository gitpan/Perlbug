#!/usr/bin/perl -w
# Email tests for Perlbug: check the tron switching/decision mechanism: expects context return value(reply|quiet|etc...)
# Richard Foley RFI perlbug@rfi.net
# $Id: 99_Test.t,v 1.2 2000/08/02 08:16:15 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 14);
}
use strict;
use lib qw(../);
use Perlbug::Base;
my $test = 0;
my $err  = 0;
my $context = '';
my $o_perlbug = Perlbug::Base->new;
$o_perlbug->current('admin', 'richardf');
$o_perlbug->current('isatest', 1);

my $get_tests = "SELECT bugid FROM tm_bug WHERE sourceaddr LIKE '%perlbug_test\@rfi.net%'";
my @testids = $o_perlbug->get_list($get_tests);
my $testids = join("', '", @testids);

my %map = ( # WHERE
	'tm_cc' 			=> "address LIKE '%perlbug_test\@rfi.net%'",
	'tm_bug_user'		=> "userid = 'perlbug_test'",
  # 'tm_flag'			=> 'a b c', 
  # 'tm_id'				=> 'x y z',
    'tm_log'			=> "userid = 'perlbug_test' OR objectid IN ('$testids')",
	'tm_message'		=> "msgheader LIKE '%perlbug_test\@rfi.net%'",
	'tm_bug_message'	=> "bugid IN ('$testids')",
  	'tm_note'			=> "sourceaddr LIKE '%perlbug_test\@rfi.net%'",
	'tm_bug_note'		=> "bugid IN ('$testids')",
	'tm_patch'			=> "sourceaddr LIKE '%perlbug_test\@rfi.net%'",
	'tm_bug_patch'		=> "bugid IN ('$testids')",
	'tm_parent_child'	=> "parentid IN ('$testids') OR childid IN ('$testids')", 
	'tm_bug'			=> "sourceaddr LIKE '%perlbug_test\@rfi.net%' OR bugid IN ('$testids')",
	'tm_test'			=> "sourceaddr LIKE '%perlbug_test\@rfi.net%'",
	'tm_bug_test'		=> "bugid IN ('$testids')",
	'tm_user'			=> "userid = 'perlbug_test'",	
);

# 1-14
# REMOVE perlbug_test installed data from database
$test++; 
foreach my $table (keys %map) {
	$err = 0;
	$context = "clean_$table";
	my $del = $o_perlbug->delete_from_table($table, "WHERE ".$map{$table});
	$err = !$del;
	output("$context -> $del -> err($err)") if $err;
	ok(!$err);
}

# done
