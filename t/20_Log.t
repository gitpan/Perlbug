#!/usr/bin/perl -w
# TicketMonger tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 20_Log.t,v 1.5 2000/08/08 10:11:11 perlbug Exp perlbug $
#
BEGIN { 
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing; 
	plan('tests' => 8); 
}
use strict;
use lib qw(../);
use Carp;
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Log;
my ($log, $res, $rng, $tmp, $debug, $user) = (
	'/tmp/perlbug_test_'.$$.'_log_file.log', 
	'/tmp/perlbug_test_'.$$.'_range_file.rng', 
	'/tmp/perlbug_test_'.$$.'_result_file.res', 
	'/tmp/perlbug_test_'.$$.'_result_file.tmp', 
	2, 'perlbug',
);
my $o_log = Perlbug::Log->new(
	'log_file' => $log, 'res_file' => $res, 'rng_file' => $rng, 'tmp_file' => $tmp, 
	'debug' => $debug, 'user' => $ENV{'LOGNAME'},
);

# Tests
# -----------------------------------------------------------------------------

# 1
# log object?
$test++; 
if (ref($o_log)) {	
	ok($test);
} else {
	notok($test);
	output("Can't retrieve Log($o_log) object");
}

# 2
# log defined?
$test++; 
my $logfile = $o_log->{'log_file'};
if ($logfile =~ /\w+/) {	
	ok($test);
} else {
	notok($test);
	output("Log file($logfile) not defined");
}

# 3
# log exists?
$test++; 
if (-e $logfile) {	
	ok($test);
} else {
	notok($test);
	output("Log file($logfile) doesn't exist");
}

# 4
# log readable?
$test++; 
if (-r $logfile) {	
	ok($test);
} else {
	notok($test);
	output("Log file($logfile) not readable");
}

# 5
# log writable?
$test++; 
if (-w $logfile) {	
	ok($test);
} else {
	notok($test);
	output("Log file($logfile) not writable");
}

# 6
# FH ref?
$test++; 
my $fh = $o_log->{'log_fh'};
if (ref($fh)) {	
	ok($test);
} else {
	notok($test);
	output("Log FH($fh) looks duff");
}

# 7
# Isa FileHandle?
$test++; 
if ($fh->isa('FileHandle')) {	
	ok($test);
} else {
	notok($test);
	output("Log FH not a filehandle($fh)");
}

# 8
# Can read log? 
$test++; 
my $msg = "Message from Perlbug Log test($$)";
$o_log->debug(0, $msg);
my @data = @{ $o_log->read('log') };
$msg = quotemeta($msg);
if (grep(/$msg/, @data)) {
	ok($test);
} else {
	notok($test);
	output("log($o_log)->read('log') failed -> '$msg'");
}

# .

