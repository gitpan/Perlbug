#!/usr/bin/perl -w
# Config pattern matches for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 10_Config.t,v 1.12 2000/08/02 08:16:47 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 11);
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

# Tests: current, system, database, target, forward, feedback, email, web parameters
# -----------------------------------------------------------------------------
my @expected = qw(CURRENT DATABASE DIRECTORY EMAIL FEEDBACK FORWARD SYSTEM TARGET WEB);
my @keys = ();

# 1
# callable? 
$test++; 
if ($o_conf = Perlbug::Config->new) {	
	$o_conf->current('isatest', 1);
	ok($test);
} else {
	notok($test);
	my $env = '';
	foreach (sort keys %ENV) { $env .= "\t$_\t=\t$ENV{$_}\n"; }
	output("ENV: \n$env\n");
	output("Can't get Config($o_conf) object");
}

# hinweis
output("host(".$o_conf->database('sqlhost')."), user(".$o_conf->system('user')."), email(".$o_conf->email('mailer')."), isatest(".$o_conf->current('isatest').") set properly?");

# 2
# all keys are hashed data?
$test++;
foreach my $exp (@expected) {
	my $h_data = $o_conf->{$exp};
	push(@keys, $h_data);
	if (ref($h_data) ne 'HASH') {
		$err++;
		output("Invalid data ($h_data) returned from '$exp'");
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 3
# CURRENT
$test++;
$err = 0;
my $context = 'CURRENT';
my %data = %{$o_conf->{$context}};
my %match = (
	'admin'		=> '^$',			# auto
	'date'		=> '^\d{8}$', 		# auto
	'debug'		=> '^[0-5]$',		# 
	'format'	=> '^[aAhHlL]$',	# 
	'isatest'   => '^(0|1)$',       # 
	'log_file'	=> '\w+',			# auto
	'res_file'	=> '\w+',			# auto
	'rng_file'	=> '\w+',			# auto
	'rc_file'   => '\w+',			# auto
	'switches'	=> '^[a-zA-Z]+$', 	#	 
	'tmp_file'  => '\w+',           #
	'url'		=> '\w+',			#
	'user'		=> '^\w+$',			# 
);
foreach my $key (grep(!/^\w+_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/ and $key ne 'admin';
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err or ($data eq '' or $vmatch eq '');
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 4
# SYSTEM
$test++;
$err = 0;
$context = 'SYSTEM';
%data = %{$o_conf->{$context}};
%match = (
	'admin_switches'=> '^[a-zA-Z]+$',		# 
	'assign'		=> '^\d+$',				#
	'bugmaster'		=> '^\w+$',				# 
	'enabled'		=> '^(0|1)$',			# on | off
	'maintainer'	=> '^[\w\@\.]+$',		#
	'max_age'		=> '^\d+$',				# 
	'path'			=> '\w+',				# 		
	'restricted'	=> '^(0|1)$',		    # 
	'separator'		=> '^.$',				# path
	'source'		=> '\w+',				#
	'title'			=> '\w+',			 	# ?
	'user'			=> '\w+',				# 
	'user_switches'	=> '^[a-zA-Z]+$', 		# 
);
foreach my $key (grep(!/^\w+_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 5
# DIRECTORY
$test++;
$err = 0;
$context = 'DIRECTORY';
%data = %{$o_conf->{$context}};
%match = (
	'arch',			=> '\w+',				# dir
	'config'		=> '\w+',				# dir
	'lists'         => '\w+',				# dir
	'perlbug'		=> '\w+',				# dir 
	'site'			=> '\w+',				# dir
	'spool'			=> '\w+',				# dir
);
foreach my $key (grep(!/^\w+_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) { # /\w+/
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 6
# DATABASE
$test++;
$err = 0;
$context = 'DATABASE';
%data = %{$o_conf->{$context}};
%match = (
    'backup'	=> '.+\slatest$',		# 
	'backup_age'=> '^\d$',				#
	'connect'	=> '(\s*|.+)', 			# ?
	'database'	=> '^[\w_]+$',  		# 
	'engine'	=> '^(Mysql|Oracle)$',	# db
	'latest'	=> '\w+',	   			# 
	'password'	=> '\w+',	   			# 
	'passfile'	=> '\w+',	   			# 
	'sqlhost'	=> '\w+',	   			# 
	'user'		=> '^[\w_]+$',  		# 
);
foreach my $key (grep(!/^\w+_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}


# 7
# TARGET 
$test++;
$err = 0;
$context = 'TARGET';
%data = %{$o_conf->{$context}};
%match = (
	'generic' 	=> '[\w+\@]+',
	'macos' 	=> '[\w+\@]+', 
	'unix'    	=> '[\w+\@]+',
	'win32'    	=> '[\w+\@]+',
	'module'   	=> '[\w+\@]+',
	'test'		=> '[\w+\@]+',
);
foreach my $key (grep(!/_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid $context key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 8
# FORWARD 
$test++;
$err = 0;
$context = 'FORWARD';
%data = %{$o_conf->{$context}};
%match = (
	'generic' 	=> '\w+\@\w+',
	'macos' 	=> '\w+\@\w+', 
	'unix'    	=> '\w+\@\w+',
	'win32'    	=> '\w+\@\w+',
	'module'   	=> '\w+\@\w+',
	'test'		=> '\w+\@+',
);
foreach my $key (grep(!/_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 9
# FEEDBACK
$test++;
$err = 0;
$context = 'FEEDBACK';
%data = %{$o_conf->{$context}};
%match = (
	'new' 		=> 'active_admin|bugmaster|sourceaddr',
	'update' 	=> 'active_admin|bugmaster|sourceaddr', 
	'delete'   	=> 'active_admin|bugmaster|sourceaddr',
);
foreach my $key (grep(!/_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 10
# EMAIL
$test++;
$err = 0;
$context = 'EMAIL';
%data = %{$o_conf->{$context}};
%match = (
# 	'X-Loop'    => '^[\w\@\.]+$',		#
	'bugdb',	=> '\w+\@\w+',			#
	'bugtron',	=> '\w+\@\w+',			#
	'from',	    => '\w+\@\w+',			#
	'deny_from' => '\w+',  				#
	'domain'	=> '\w+',				#
	'hint'		=> '\w+',	  			# 		
	'help',	    => '\w+\@\w+',			#
	'maintainer'=> '\w+',				#
	'mailer'	=> '.+',				#
	'master_list'=>'\w+',               #
	'match'		=> '\w+',				# ?
	'test'      => '^[\w\@\.]+$',		# ?
	'X-Test'    => '^[\w-]+$',		    #
);
foreach my $key (grep(!/_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 11
# WEB
$test++;
$err = 0;
$context = 'WEB';
%data = %{$o_conf->{$context}};
%match = (
	'cgi'		=> '\w+',	   
	#'context'	=> '^r[ow]$',	   
	'domain'	=> '\w+',	   
	'home'		=> '\w+',	   
	'htpasswd'	=> '\w+',	   
	'hard_wired_url'=> '\w+',	   
	# 'source'	=> '\w+',	   
);
foreach my $key (grep(!/^\w+_comment$/, keys %data)) { 
	$err = 0;
	next unless $key =~ /\w+/;
	my ($data, $vmatch) = ($data{$key}, $match{$key});
	# print "$context: key($key), data($data), match($vmatch)\n";
    if ($data !~ /$vmatch/) {
		$err++;
		output("$context invalid key($key), data($data), match($vmatch)") if $err;
	}
}
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# some errors?
if ($err || 1) {
	# output("Config data: ".Dumper($o_conf));
}

# Done
# -----------------------------------------------------------------------------
# .
