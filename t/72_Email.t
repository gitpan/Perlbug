#!/usr/bin/perl -w
# Email tests for Perlbug: check the tron scanning of mail bodies for category, etc. - requires special scan matching
# Richard Foley RFI perlbug@rfi.net
# $Id: 72_Email.t,v 1.4 2000/12/19 13:11:31 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 5);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Email;
use FileHandle;
use Mail::Internet;
use Sys::Hostname;
my $o_mail = Perlbug::Email->new;
my $o_test = Perlbug::TestBed->new($o_mail);
$o_mail->current('admin', 'richardf');

# Setup
# -----------------------------------------------------------------------------
my %all_flags   = $o_mail->all_flags;
my %installed	= ();
my $context		= '';
my $dir			= './t/data/72';
my @expected	= (qw(category osname severity status version));
my $err			= 0;

# Tests
# -----------------------------------------------------------------------------
# 
CONTEXT:
foreach my $context (grep(!/version/, @expected)) {
	$test++; 
	$err = 0;
	my @tests = $o_test->get_tests("$dir/$context");
	if (!scalar(@tests) >= 1) {
		$err++; 
		output("No tests for context($context) in dir($dir)!");
	} else {
		my $i_ok = 1;
		TEST:
		foreach my $test (@tests) {
			last TEST unless $i_ok == 1;
			($i_ok, my $data) = &get_data("$dir/$context/$test");
			# output("data=$data");
			my $rex = join('|', $o_mail->flags($context));
			if (!($i_ok == 1) && ($data =~ /$context\=($rex)/s)) { 
				$err++;
				output("$context test ($test) failed($err) with rex($rex) -> '$data'");
			}	
		}
	}
	output("$context -> err($err)") if $err;
	($err == 0) ? ok($test) :  ok(0);
}


# 5
# VERSION
$test++; 
$err = 0;
$context = 'version';
my @versions = $o_test->get_tests("$dir/$context");
foreach my $test (grep(/^$context/, @versions)) {
	my ($ok, $data) = &get_data("$dir/$context/$test");
	# output("data=\n$data");
	if (($ok == 1) && ($data !~ /$context\=([\d\.]+)/)) {
		$err++;
		output("$context test ($test) failed -> '$data'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	ok(0);
}

# Done
# -----------------------------------------------------------------------------
# .
		
sub get_data { # get mail, data, scan, return $data as per fmt() 
	my $file = shift;
	my ($ok, $data) = (0, '');
	my $o_int = $o_test->file2minet($file);
	if (defined($o_int)) {
		my $body = join('', @{$o_int->body});
		my $matches = $o_int->head->get('X-Matches');
		$o_mail->_original_mail($o_int);
		my $h_data = $o_mail->scan($body);
		if ((ref($h_data) ne 'HASH') or ($matches !~ /\w+/)) {
			output("Data failure for file($file): h_data($h_data), or matches($matches) doesn't look good!");
		} else {
			$ok = 1;
			$data = $o_mail->fmt($h_data);
			MATCH:	
			foreach my $match (split(' ', $matches)) {
				last MATCH unless $ok == 1;
				next unless defined($match) and $match =~ /\w+/;
				if ($data !~ /\s*$match\s*/m) {
					$ok = 0;
					output("Failed '$file': expected match($match) in data($data)");
				}
			}
		}
    }
	return ($ok, $data);
}
