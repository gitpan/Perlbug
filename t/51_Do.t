#!/usr/bin/perl -w
# Do utilities tests for Perlbug: get_switches, stats, admin_of_bug
# Richard Foley RFI perlbug@rfi.net
# $Id: 51_Do.t,v 1.1 2000/08/04 14:45:58 perlbug Exp perlbug $
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
my $context = 'not defined';


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_perlbug = '';

# Tests
# -----------------------------------------------------------------------------

# 1
# Libraries callable? 
$test++; 
$context = 'new';
if ($o_perlbug = Perlbug::Base->new) {	# won't operate stand-alone
	$o_perlbug->current('isatest', 1);
	ok($test);
} else {
	notok($test);
	output("base object ($o_perlbug) retrieval failed");
}

# 2
$test++;
$context = 'get_switches';
my @switches = $o_perlbug->$context(); 
if (grep(/^h$/, @switches) and grep(!/^a$/, @switches)) {	
	ok($test);
} else {
	notok($test);
	output("$context failed(@switches)");
}

# 3
$test++;
@switches = $o_perlbug->$context('user'); 
if (grep(/^b$/, @switches) and grep(!/^a$/, @switches)) { 
	ok($test);
} else {
	notok($test);
	output("$context('user') failed(@switches)");
}

# 4
$test++;
@switches = $o_perlbug->$context('admin'); 
if (grep(/^a$/, @switches) and grep(/^x$/, @switches)) { 
	ok($test);
} else {
	notok($test);
	output("$context('admin') failed(@switches)");
}

# 5
$test++;
$context = 'stats';
my %stats = %{$o_perlbug->$context}; 
if ($stats{'bugs'} >= 1) { 
	ok($test);
} else {
	notok($test);
	output("$context failed: ".Dumper(\%stats));
}

# 6
$test++;
$context = 'admin_of_bug';
my $get_test = q|SELECT bugid FROM tm_bug WHERE sourceaddr LIKE '%perlbug_test@rfi.net%'|;
my ($TID) = $o_perlbug->get_list($get_test);
my $isadmin = $o_perlbug->$context($TID, ''); 
if ($TID =~ /\w+/ and $isadmin == 0) { 
	ok($test);
} else {
	notok($test);
	output("$context failed($isadmin)");
}

# 7
# $test++;
# $o_perlbug->isadmin('perlbug_test');
# print $o_perlbug->isadmin;
# $o_perlbug->doc($TID);
# my $isnowadmin = $o_perlbug->$context($TID, ''); 
# if ($isnowadmin == 1) { 
# 	ok($test);
# } else {
# 	notok($test);
# 	output("$context failed($isnowadmin)");
# }

# Done
# -----------------------------------------------------------------------------
# .
