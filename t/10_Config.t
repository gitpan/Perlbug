
# Config pattern matches for Perlbug, for ck822 email tests see t/70_Email.t 
# Richard Foley RFI perlbug@rfi.net
# $Id: 10_Config.t,v 1.3 2002/01/11 13:51:06 richardf Exp $
#

use strict;
use lib qw(../);
use Perlbug::Config;
use Perlbug::Test;
plan('tests' => 21);
use Data::Dumper;

my $o_conf = Perlbug::Config->new;
my $o_test = Perlbug::Test->new($o_conf);
my %conf   = ();
my @conf   = ();
my %seen   = ();
my $test   = 0;
my $err    = 0;

# Tests: keys
# -----------------------------------------------------------------------------
my @expected = qw(
	CURRENT DATABASE DEFAULT DIRECTORY EMAIL 
	ENV FEEDBACK FORWARD GROUP LINK MESSAGE SEVERITY 
	STATUS SYSTEM TARGET VARS VERSION WEB 
);

# 1
# callable? 
$test++; 
if (ref($o_conf)) {
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
output(join(', ', 
	'host(' 	. $o_conf->database('sqlhost')	.')',
	'user(' 	. $o_conf->system('user')		.')',
	'email('  	. $o_conf->email('mailer')		.')',
	'isatest('	. $o_conf->current('isatest')	.')',
	).'set properly?'
);

# 2
# EXPECTED
if ($o_test->compare([(sort keys %conf)], \@expected)) {
	ok($test);	
} else {
	output("Expected configuration(\n@expected) not matched in conf(\n".join(' ', sort keys %conf).")");
	ok(0);
}

# 3
my %match   = %{&get_matches()};
if ($o_test->compare([(sort map { uc($_) } keys %match)], \@expected)) {
	ok($test);	
} else {
	output("Expected matches\n(@expected) not matched\n(".join(' ', sort keys %match).")");
	ok(0);
}

# 4-n
foreach my $confkey (sort keys %conf) {
	$test++;
	my $i_errs = 0;
	my @errs   = ();
	next unless $confkey =~ /\w+/o;
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


# some errors?
if ($err || 1) {
	output("Config data: ".Dumper($o_conf)) if $Perlbug::DEBUG;
}

#
# GET_MATCHES
#
sub get_matches {
	my %MATCHES = (
		'current' => {
			'default'	=> '\w+',
			'cc'		=> '.*$',
			'admin'		=> '^[\w]*$',
			'context'	=> '^(text|html)$',		# auto
			'debug'		=> '^(|\[*[fFmMsStTxX0-5]+\]*)$',	#
			'fatal'		=> '^[01]$',
			'format'	=> '^[aAhHiIlLxX]$',	# 
			'framed'    => '^(0|1)$',       	# 
			'mailing'   => '^(0|1)$',
			'isatest'   => '^([01])$',       	# 
			'user'		=> '^\w+$',				#	 
		},
		'database'	=> {
			'default'			=> '\w+',
			'backup_args'		=> '^[\s\-\w]+$',		# 
			'backup_interval'	=> '^\d$',				#
			'connect'			=> '(\s*|.+)', 			# ?
			'database'			=> '^[\w_]+$',  		# 
			'engine'			=> '^([a-zA-Z]+)$',		# db
			'user'				=> '^[\w_]+$',  		# 
		}, 
		'default'	=> {
			'default'	=> '\w+',
		},
		'directory'	=> {
			'default'	=> '\w+',
		},
		'email'		=> {
			'default'		=> '\w+\@\w+',			#
			'antimatch'		=> '\w+',				#
			'commands'		=> '\w+',				# {}
			'deny_from'		=> '\w+',
			'domain'		=> '[\w\.]+',			#
			'hint'			=> '\w+',
			'mailer'		=> '\w+',				#
			'master_list'	=> '\w+',				#
			'match'			=> '\w+',				#
			'X-Test'		=> 'X-Perlbug-Test',	#
		},
		'env'	=> {
			'default'	=> '\w+',
		},
		'feedback'	=> {
			'default'	=> '(active|admin|cc|maintainer|group|master|source)',
		},
		'forward'	=> {
			'default',		=> '\w+\@\w+',			#
			'dailybuild',	=> '\w+',				#
		},
		'group'	=> {
			'default'	=> '\w+',
		},
		'link'	=> {
			'default'	=> '\w+',
		},
		'message'	=> {
			'default'	=> '\w+',
		},
		'severity'	=> {
			'default'	=> '\w+',
		},
		'status'	=> {
			'default'	=> '\w+',
		},
		'system' 	=> {
			'default'	=> '\w+',
			'admin_switches'=> '^[a-zA-Z]+$',		# 
			'assign'		=> '^\d+$',				#
			'bugmaster'		=> '^\w+$',				# 
			'cachable'		=> '^(0|1)$',			# on | off
			'compress'		=> '^\w+$',				# 
			'enabled'		=> '^(0|1)$',			# on | off
			'hostname'		=> '^[\w\.]+$',			# 
			'maintainer'	=> '\w+\@\w+',			#
			'max_age'		=> '^\d+$',				# 
			'max_errors'	=> '^\d+$',				# 
			'restricted'	=> '^(0|1)$',		    # 
			'separator'		=> '^\W$',				# path
			'timeout_auto'	=> '^\d+$',				#
			'timeout_interactive'=> '^\d+$',		#
			'user_switches'	=> '^[a-zA-Z]+$', 		# 
			'watch'			=> '^(yes|no)$',	    # 
		},
		'target'	=> {
			'default',		=> '\w+\@\w+',			#
		},
		'vars'	=> {
			'default'	=> '\w+',
		},
		'version'	=> {
			'default',		=> '\w+',	
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
