#!/usr/bin/perl -w
# Base tests for Perlbug: parse_str 
# Richard Foley RFI perlbug@rfi.net
# $Id: 60_Base.t,v 1.3 2000/08/02 08:20:44 perlbug Exp $
#
# TODO: clean_up tests
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
my $err = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_base = Perlbug::Base->new; 

# Setup
# -----------------------------------------------------------------------------
my ($TID) = $o_base->get_list("SELECT MAX(ticketid) FROM tm_tickets");
my %matches = (
	'bugids' => { 
		"close_mac_5.5_${TID}_nocc_33" 		=> [$TID],
		"close_open_${TID}_${TID}1_nocc" 	=> [$TID],
		"close_open_1${TID}_${TID}_nocc" 	=> [$TID],
		"${TID}_nocc" 						=> [$TID],
		$TID 								=> [$TID],
	},
	'changeids' => { 
		"close_mac_5.5_${TID}_x_nocc_33"=> [qw(33)],
		"noc_${TID}_32_x_n21occ" 		=> [qw(32)],
		"${TID}1123_88" 				=> [qw(88)],
		"nox  22222_ide atall_11_919 "  => [qw(11 22222 919)],
	},
	'flags' => { # str => match
		"close_mac_5.5_${TID}_nocc_33" 	=> [qw(mac close)],
		"win_onho_5.5_${TID}" 			=> [qw(win onho)],
		"${TID}_nocc_123_close" 		=> [qw(close)],
		"patch_inst" 					=> [qw(patch inst)],
	},
	'versions' => { 
		"close_mac_5.5_${TID}_nocc_33" 	=> [qw(5.5)],
		"333335.5_${TID}_nocc" 			=> [qw(333335.5)],
		"close_mac_${TID}_3.4.4.4.4.4" 	=> [qw(3.4.4.4.4.4)],
		"1.2.3.4.5.6.7.8._9" 			=> [qw(1.2.3.4.5.6.7.8.)],
	},
	'unknown' => { 
		"close_mac_5.5_${TID}_x_nocc_33" => [qw(x nocc)],
		"noc_${TID}_x_nocc" 			=> [qw(noc x nocc)],
		"${TID}1" 						=> ["${TID}1"],
		"1${TID}" 						=> ["1${TID}"],
		"ope_cloooooooooooooose" 		=> [qw(cloooooooooooooose)],
		"nox ide atall" 				=> [qw(nox ide atall)],
	},
);

# Tests
# -----------------------------------------------------------------------------

# 1-5
# all
foreach my $context (sort keys %matches) {
	$test++;
	$err = 0;
	my %context = %{$matches{$context}};
	foreach my $str (keys %context) {
		my @tgts = @{$context{$str}};
		my %data = $o_base->parse_str($context{$str});
		my @data = @{$data{$context}};
		if (compare(\@data, \@tgts)) {	
			push(@data, 'x');
			if (compare(\@data, \@tgts)) { # check check is OK :-)
				$err++;
				output("$context failed: data(@data) should not equal (@tgts)");
			}
		} else {
			$err++;
			output("$context failed: str($str) and targets(@tgts) gave data(@data)".Dumper(\%data));
		}
	}
	if ($err == 0) {	
		ok($test);
	} else {
		notok($test);
		output("$context failed: $err errors");
	}
}

# Done
# -----------------------------------------------------------------------------
# .

=item compare

Compare two arrays: returns 1 if identical, 0 if not.

    my $identical = compare(\@arry1, \@arry2);

=cut

sub compare {           # 
    my ($first, $second) = @_;
	local $^W = 0;  # silence spurious -w undef complaints
	return 0 unless @$first == @$second;
	for (my $i = 0; $i < @$first; $i++) {
    	return 0 if $first->[$i] ne $second->[$i];
	}
	return 1;
}
