#!/usr/bin/perl -w
# Config pattern matches for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 00_Config.t,v 1.2 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 16);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Config;
use Data::Dumper;
my $o_conf = ''; 
my %conf   = ();
my @conf   = ();
my %seen   = ();

# Tests: current, system, database, target, forward, feedback, email, web parameters
# -----------------------------------------------------------------------------
my @expected = qw(CURRENT DATABASE DIRECTORY EMAIL FEEDBACK FORWARD SYSTEM TARGET WEB);

# 1
# callable? 
$test++; 
if ($o_conf = Perlbug::Config->new) {	
	$o_conf->current('isatest', 1);
	ok($test);
	%conf = %{$o_conf->{'_config'}};
} else {
	ok(0);
	my $env = '';
	foreach (sort keys %ENV) { $env .= "\t$_\t=\t$ENV{$_}\n"; }
	output("ENV: \n$env\n");
	output("Can't get Config($o_conf) object");
}

# hinweis
output("host(".$o_conf->database('sqlhost')."), user(".$o_conf->system('user')."), email(".$o_conf->email('mailer')."), isatest(".$o_conf->current('isatest').") set properly?");


# 2-n
my %match   = %{&get_matches()};
foreach my $confkey (sort keys %conf) {
	$test++;
	my $i_errs = 0;
	my @errs   = ();
	next unless $confkey =~ /\w+/;
	# output("\t[$test] CONFKEY($confkey)...");
	$seen{$confkey}++ if grep(/^$confkey/, @expected); # next one
	my $h_data = $conf{$confkey};
	if (ref($h_data) ne 'HASH') {
		$i_errs++;
		output("[$test] Error: confkey($confkey) has no data ref($h_data)!");
	} else {
		my %data = %{$h_data};
		foreach my $key (keys %data) { 
			my @data = (ref($data{$key}) eq 'ARRAY') ? @{$data{$key}} : ($data{$key});
			my $vmatch = $match{lc($confkey)}{$key} || $match{lc($confkey)}{'default'} || '\w+';
			# output("\t[$test] key($key), data(@data), match($vmatch)");
			foreach my $data (@data) {
				if ($data !~ /$vmatch/) {
					$i_errs++;
					output("\t[$test] Error: invalid key($key), data($data), match($vmatch)");
				}
			}
		}
	}
	if ($i_errs == 0) {
		# output("\t[$test] $confkey passed with no errors($i_errs)");
		ok($test);
	} else {
		$err++;
		output("\t[$test] $confkey has $i_errs invalid key's(@errs)");
		ok(0);
	}
}

# x
# EXPECTED
if (keys %seen == @expected) {
	ok($test);	
} else {
	output("Expected(@expected) not all found(".join(', ', keys %seen).")");
	ok(0);
}


# some errors?
if ($err || 1) {
#	output("Config data: ".Dumper($o_conf));
}

#
# GET_MATCHES
#
sub get_matches {
	my %MATCHES = (
		'current' => {
			'default'	=> '\w+',
			'admin'		=> '^[\w]*$',
			'context'	=> '^(text|html)$',		# auto
			'debug'		=> '^(|\[*[cCmMsSxX0-5]+\]*)$',	#
			'format'	=> '^[aAhHiIlLxX]$',	# 
			'framged'   => '^(0|1)$',       	# 
			'isatest'   => '^([012])$',       	# 
			'switches'	=> '^[a-zA-Z]+$', 		#	 
			'user'		=> '^\w+$',				#	 
		},
		'directory'	=> {
			'default'	=> '\w+',
		},
		'database'	=> {
			'default'			=> '\w+',
			'backup_args'		=> '^[\s\-\w]+$',		# 
			'backup_interval'	=> '^\d$',				#
			'connect'			=> '(\s*|.+)', 			# ?
			'database'			=> '^[\w_]+$',  		# 
			'engine'			=> '^(Mysql|Oracle)$',	# db
			'user'				=> '^[\w_]+$',  		# 
		}, 
		'email'		=> {
			'default',		=> '\w+\@\w+',			#
			'deny_from',	=> '\w+',
			'domain'		=> '[\w\.]+',			#
			'hint',			=> '\w+',
			'mailer'		=> '\w+',				#
			'master_list'	=> '\w+',				#
			'match'			=> '\w+',				#
			'X-Test'		=> 'X-Perlbug-Test',	#
		},
		'feedback'	=> {
			'default'	=> '(active|admin|cc|maintainer|group|master|source)',
		},
		'forward'	=> {
			'default',		=> '\w+\@\w+',			#
			'dailybuild',	=> '\w+',				#
		},
		'system' 	=> {
			'default'	=> '\w+',
			'admin_switches'=> '^[a-zA-Z]+$',		# 
			'assign'		=> '^\d+$',				#
			'bugmaster'		=> '^\w+$',				# 
			'cachable'		=> '^(0|1)$',			# on | off
			'compress'		=> '^\w+$',				# 
			'enabled'		=> '^(0|1)$',			# on | off
			'hostname'		=> '^\w+$',				# 
			'maintainer'	=> '\w+\@\w+',			#
			'max_age'		=> '^\d+$',				# 
			'max_errors'	=> '^\d+$',				# 
			'restricted'	=> '^(0|1)$',		    # 
			'separator'		=> '^\W$',				# path
			'timeout_auto'	=> '^\d+$',				#
			'timeout_interactive'=> '^\d+$',		#
			'user_switches'	=> '^[a-zA-Z]+$', 		# 
		},
		'target'	=> {
			'default',		=> '\w+\@\w+',			#
		},
		'web'		=> {
			'default'	=> '\w+',
		},
	);
	return \%MATCHES;
}

# Done
# -----------------------------------------------------------------------------
# .
