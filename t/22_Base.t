#!/usr/bin/perl -w
# Base parse_str tests
# Richard Foley RFI perlbug@rfi.net
# $Id: 22_Base.t,v 1.1 2001/09/18 13:37:50 richardf Exp $
#

use lib qw(../);
use strict;
use Data::Dumper;
use Perlbug::Base;
use Perlbug::Test;

my $o_base = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_base);
my $i_test = 0;

my $BUGID  = $o_test->bugid;

# Tests
# -----------------------------------------------------------------------------
# nb. parse_str() returns minimally bugids->{} and unknown->{} even if empty
my @tests = (
	{ # 1 - bugid and osname
		'string'	=> qq|aix_irix_${BUGID}_etc|,
		'expected'	=> { 
			'bug'		=> {
				'ids' 	=> [($BUGID)],
			},
			'osname'	=> {
				'names'	=> [qw(aix irix)],
			},
			'unknown'	=> {
				'names'	=> [qw(etc _)],
			},
		},
	},
	{ # 2 - and version number
		'string'	=> qq|5.0.5_Aix_IRIX_${BUGID}_Etc|,
		'expected'	=> { 
			'bug'		=> {
				'ids' 	=> [($BUGID)],
			},
			'osname'	=> {
				'names'	=> [qw(Aix IRIX)],
			},
			'unknown'	=> {
				'names'	=> [qw(Etc _)],
			},
			'version'	=> {
				'names'	=> [qw(5.0.5)],
			},
		},
	},
	{ # 3 - and change id and duplicates
		'string'	=> qq|5.6.1_44_AIX_AIX_aix_irix_${BUGID}_${BUGID}_${BUGID}_AITXC|,
		'expected'	=> { 
			'bug'		=> {
				'ids' 	=> [($BUGID)],
			},
			'change'	=> {
				'names'	=> [qw(44)],
			},
			'osname'	=> {
				'names'	=> [qw(AIX irix)],
			},
			'unknown'	=> {
				'names'	=> [qw(AITXC _)],
			},
			'version'	=> {
				'names'	=> [qw(5.6.1)],
			},
		},
	},
	{ # 4 - and in spaces
		'string'	=> qq|${BUGID} 5.7.2 open xto_xwin323 6644|,
		'expected'	=> { 
			'bug'		=> {
				'ids' 	=> [($BUGID)],
			},
			'change'	=> {
				'names'	=> [qw(6644)],
			},
			'status'	=> {
				'names'	=> [qw(open)],
			},
			'unknown'	=> {
				'names'	=> [qw(xto xwin323 _)],
			},
			'version'	=> {
				'names'	=> [qw(5.7.2)],
			},
		},
	},
	{ # 5 - and swapped around
		'string'	=> qq|5.7.0 ${BUGID} closed maxosi|,
		'expected'	=> {  
			'bug'		=> {
				'ids' 	=> [($BUGID)],
			},
			'status'	=> {
				'names'	=> [qw(closed)],
			},
			'unknown'	=> {
				'names'	=> [qw(maxosi)],
			},
			'version'	=> {
				'names'	=> [qw(5.7.0)],
			},
		},
	},
	{ # 6 - and more versions and none unknown
		'string'	=> qq|5.7.1 $BUGID $BUGID high 5.0.5 5.005.3 ${BUGID}|,
		'expected'	=> {
			'bug'		=> {
				'ids' 	=> [($BUGID)],
			},
			'severity'	=> {
				'names'	=> [qw(high)],
			},
			'version'	=> {
				'names'	=> [qw(5.0.5 5.005.3 5.7.1)],
			},
		},
	},
	{ # 7 - and more variety
		'string'	=> qq|5.7.1 coRe MACOS iNSTALL high CLOSED 5.0.5 5.005.3 ${BUGID}|,
		'expected'	=> {
			'bug'		=> {
				'ids' 	=> [($BUGID)],
			},
			'group'		=> {
				'names'	=> [qw(coRe INSTALL)],
			},
			'osname'	=> {
				'names'	=> [qw(MACOS)],
			},
			'severity'	=> {
				'names'	=> [qw(high)],
			},
			'status'	=> {
				'names'	=> [qw(CLOSED)],
			},
			'version'	=> {
				'names'	=> [qw(5.0.5 5.005.3 5.7.1)],
			},
		},
	},
);

# How many?
plan('tests' => scalar(@tests));
my $i_err = 0;

TEST:
foreach my $h_test (@tests) {
	$i_test++; 
	last TEST unless $i_err == 0;
	my %expected = %{$h_test->{'expected'}}; 
	my $string  = $h_test->{'string'};
	my %scanned = $o_base->parse_str($string);
	TARGET:
	foreach my $target (sort keys %expected) {			# osname, bug
		last TARGET unless $i_err == 0;
		# print "target($target): ".Dumper($expected{$target});
		TYPE:	
		foreach my $type (keys %{$expected{$target}}) {	# ids, names
			last TYPE unless $i_err == 0;
			my @expd = (ref($expected{$target}{$type}) eq 'ARRAY') ? @{$expected{$target}{$type}} : ();
			my @data = (ref($scanned{$target}{$type}) eq 'ARRAY')  ? @{$scanned{$target}{$type}}  : ();
			my @scan = @data;
			EXP:
			foreach my $exp (@expd) {					# aix, irix, $BUGID, 444
				if (grep(/^$exp$/i, @data)) {
					# output("Found key($key) exp($exp) in data(@data)");
					@data = grep(!/^$exp$/i, @data);
				} else {
					$i_err++;
					output("Failed to find $target $type=$exp in parsed(@data)!");
				}
			}
			if (!(scalar(@data) >= 1)) {
				if ($type eq 'names' && scalar($scanned{$target}{'ids'}) >= 1) {
					delete $scanned{$target}{'ids'}; # workaround
				}
				delete $scanned{$target}{$type};
			} else {
				$i_err++;
				output("Redundant $target $type data(@data)");
			}
		}
		if (!(scalar(keys %{$scanned{$target}}) >= 1)) {
			delete $scanned{$target};
		} else {
			$i_err++;
			output("Redundant $target data: ".Dumper($scanned{$target}));
		}
	}
	if (scalar(keys %scanned) >= 1) {
		$i_err++;
		output("Redundant scanned: ".Dumper(\%scanned));
	}
	output("Failed to scan($string)") if $i_err != 0;
	($i_err == 0) ? ok($i_test) : ok(0);
}	# each test

# done
