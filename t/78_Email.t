#!/usr/bin/perl -w
# Email tests for Perlbug: check the tron scanning of mail bodies for category, etc. - requires special scan matching
# Richard Foley RFI perlbug@rfi.net
# $Id: 78_Email.t,v 1.4 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 1);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Interface::Email;
use FileHandle;
use Mail::Internet;
use Sys::Hostname;
my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::TestBed->new($o_mail);
$o_mail->current('admin', 'richardf');

# Setup
# -----------------------------------------------------------------------------
my %all_flags   = $o_mail->all_flags;
my %installed	= ();
my $context		= '';
my $dir			= './t/email/78';
my $err			= 0;

# Tests
# -----------------------------------------------------------------------------
# 
CONTEXT:
foreach my $context ('scan') {
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
			if ($i_ok != 1) {
				$err++;
				output("$context test($test) failed($err) -> $i_ok, $data");
			}	
		}
	}
	output("$dir/$context -> err($err)") if $err;
	($err == 0) ? ok($test) :  ok(0);
}

# Done
# -----------------------------------------------------------------------------
# .
		
sub get_data { # get mail, data, scan, return $data as per fmt() 
	my $file = shift;
	my ($i_ok, $data) = (0, '');
	my $o_int = $o_test->file2minet($file);
	if (defined($o_int)) {
		my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
		my @args = $o_test->minet2args($o_hdr);
		($i_ok, $data) = $o_test->check_mail($o_hdr, $body, @args);
    }
	return ($i_ok, $data);
}
