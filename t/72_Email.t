#!/usr/bin/perl -w
# Email tests for Perlbug: check the bugtron scan($mailbody) for category, etc.
# Richard Foley RFI perlbug@rfi.net
# $Id: 72_Email.t,v 1.9 2001/09/19 07:30:31 richardf Exp $
#

use lib qw(../);
use strict;
use Data::Dumper;
use Perlbug::Interface::Email;
use Perlbug::Test;

my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::Test->new($o_mail);
my $i_test = 0;

my $BUGID  = $o_test->bugid;

# Tests
# -----------------------------------------------------------------------------
my @tests = (
	{ # 1 - simple and tight
		'expected'	=> { 
			'group' 	=> [qw(regex)],
			'osname'	=> [qw(aix)],
			'project'	=> [qw(perl5)],
			'severity'	=> [qw(medium)],
			'status'	=> [qw(open)],
		},
		'body'		=> qq|
	category=regex
	osname=aix
	project=perl5
	severity=medium
	status=open
		|,
	},
	{ # 2 - mixed up and case-insensitive
		'expected'	=> { 
			'group'		=> [qw(core install)],
			'osname'	=> [qw(aix)],
			'severity' 	=> [qw(low)],
			'status'	=> [qw(open)],
		},
		'body'		=> qq|
setup on osname =   AIX			 
	Severity   =low for this email message   
STATUS  =  opEN

		CATEGORY =	iNstall  
		category =	core
		category =	CoRE
		category =	CORE
		|,
	},
	{ # 3 - version
		'expected'	=> { 
			'version'	=> [qw(5.0 5.005 5.0.5 5.005.03)],
		},
		'body'		=> qq|
	version=5.005.03
		|, 
	},
	{ # 4 - version
		'expected'	=> { 
			'version'	=> [qw(5.6 5.6.0 5.6.0-RC1 5.7.0 5.7.0-6849 5.7.2)],
		},
		'body'		=> qq|
	version=5.6.0-RC1
	version=5.7.0
	version=5.7.0-6849
	version=5.7.2
		|, # version=5.10.001
	},
	{ # 5 - project, version
		'expected'	=> { 
			'project'	=> [qw(perl5)],
			'version'	=> [qw(5.053)],
		},
		'body'		=> qq|
		Summary of my perl5 (5.0 patchlevel 5 subversion 3) configuration: 
		|, 
	},
	{ # 6 - project, version
		'expected'	=> { 
			'project'	=> [qw(perl5)],
			'version'	=> [qw(5.05640)],
		},
		'body'		=> qq|
		Summary of my perl5 (revision 5.0 version 5 subversion 640) configuration:    
		|, 
	},
	{ # 7 - project, version
		'expected'	=> { 
			'project'	=> [qw(perl5)],
			'version'	=> [qw(5.003)],
		},
		'body'		=> qq|
		some stuff running under perl 5.003 gobbledegook
		|, 
	},
	{ # 8 - project, version
		'expected'	=> { 
			'project'	=> [qw(perl5)],
			'version'	=> [qw(5.6.0)],
		},
		'body'		=> qq|
		Site configuration information for perl 5.6.0:
		|, 
	},
	{ # 9 - project, version
		'expected'	=> { 
			'project'	=> [qw(perl5)],
			'version'	=> [qw(5.0503)],
		},
		'body'		=> qq|
		generated with the help of perlbug 1.27 running under perl 5.0503.
		|, 
	},
);


# How many?
plan('tests' => scalar(@tests));
my $i_err = 0;

TEST:
foreach my $h_test (@tests) {
	$i_test++; 
	last TEST unless $i_err == 0;
	my %expected = %{$$h_test{'expected'}}; 
	my $body     = $$h_test{'body'};
	my %scanned  = %{$o_mail->scan($body)};
	CHECK:
	foreach my $key (sort keys %expected) {	# category
		last CHECK unless $i_err == 0;
		my @expected = (ref($expected{$key}) eq 'ARRAY') ? sort @{$expected{$key}} : ();
		my @scanned  = (ref($scanned{$key}{'names'}) eq 'ARRAY') ? sort @{$scanned{$key}{'names'}} : ();
		if ($o_test->compare(\@expected, \@scanned)) {
			delete $scanned{$key};
		} else {
			$i_err++;
			output("key($key) failed to find \n\texpected(@expected) in \n\t scanned(@scanned)");
		}
	}
	if (scalar(keys %scanned) >= 1) {
		$i_err++;
		output("Redundant scanned: ".Dumper(\%scanned));
	}
	output("Failed to scan($body) scanned: ".Dumper(\%scanned)) if $i_err != 0;
	($i_err == 0) ? ok($i_test) : ok(0);
}	# each test

# done
