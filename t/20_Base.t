#!/usr/bin/perl -w
# Base tests for admin/check_user 
# Richard Foley RFI perlbug@rfi.net
# $Id: 20_Base.t,v 1.2 2001/09/18 13:37:50 richardf Exp $
#
# TODO: clean_up tests
#
use strict;
use lib qw(../);
use Perlbug::Base;
use Perlbug::Test;

my $o_base = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_base);

plan('tests' => 3);
my $i_test = 0;
my $i_err  = 0;

# Tests
# -----------------------------------------------------------------------------

# 1
# callable? 
$i_test++; 
if (ref($o_base) and ref($o_test)) {
	ok($i_test);
} else {
	ok(0);
	output("base object ($o_base) not retrieved");
}

# 2 
# admin is in db
my $bg = $o_base->system('bugmaster');
my $get_list = "SELECT active FROM pb_user WHERE userid = '$bg'";
my ($res) = $o_base->get_list($get_list);
if ($res eq '1') {
	ok($i_test);
} else {
	ok(0);
	output("Bugmaster($bg) appears not to be an registered($res) with this installation($get_list)!");
}

# 3
# data structures
my $get_data = "SELECT * FROM pb_user WHERE userid = '$bg'";
my ($h_res) = $o_base->get_data($get_data);
if (ref($h_res) eq 'HASH' && $$h_res{'userid'} =~ /^\w+$/o) {
	ok($i_test);
} else {
	ok(0);
	output("Failed to get_data($get_data) => h_res($h_res)");
}

# 4 
# check_user()


# Done
# -----------------------------------------------------------------------------
# .
