#!/usr/bin/perl -w
# TicketMonger tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 10_File.t,v 1.2 2001/09/18 13:37:50 richardf Exp $
#
BEGIN { 
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Test; 
	plan('tests' => 8); 
}
use strict;
use lib qw(../);
use Carp;
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Config;
use Perlbug::File;

my $o_conf= Perlbug::Config->new();

# Tests
# -----------------------------------------------------------------------------

# 1
# log defined?
$test++; 
my $logfile = $o_conf->current('log_file');
if ($logfile =~ /\w+/o) {	
	ok($test);
} else {
	ok(0);
	output("Log file($logfile) not defined");
}

my $o_log = Perlbug::File->new($logfile);
# 2
# log object?
$test++; 
if (ref($o_log)) {	
	ok($test);
} else {
	ok(0);
	output("Can't retrieve Log($o_log) object");
}

# 3
# log exists?
$test++; 
if (-e $logfile) {	
	ok($test);
} else {
	ok(0);
	output("Log file($logfile) doesn't exist");
}

# 4
# log readable?
$test++; 
if (-r $logfile) {	
	ok($test);
} else {
	ok(0);
	output("Log file($logfile) not readable");
}

# 5
# log writable?
$test++; 
if (-w $logfile) {	
	ok($test);
} else {
	ok(0);
	output("Log file($logfile) not writable");
}

# 6
# FH ref?
$test++; 
my $fh = $o_log->handle;
if (ref($fh)) {	
	ok($test);
} else {
	ok(0);
	output("Log FH($fh) looks duff");
}

# 7
# Isa FileHandle?
$test++; 
if ($fh->isa('FileHandle')) {	
	ok($test);
} else {
	ok(0);
	output("Log FH not a filehandle($fh)");
}

# 8
# Can read log? 
$test++; 
my $msg = "Message from Perlbug Log test($$)\n";
my $done = $o_log->append($msg);
my ($data) = reverse $o_log->read; # last line only
chomp($msg, $data);
$msg = quotemeta($msg);
if (grep(/$msg/, $data)) {
	ok($test);
} else {
	ok(0);
	output("log($o_log)->read() failed -> in($msg) out($data)");
}

# .

