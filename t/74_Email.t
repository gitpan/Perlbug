#!/usr/bin/perl -w
# Email tests for Perlbug: check the tron switching/decision mechanism
# Richard Foley RFI perlbug@rfi.net
# 
# $Id: 74_Email.t,v 1.5 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use Data::Dumper;
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 4);
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
my $err			= 0;
my %installed	= ();
my $dir		    = './t/email/74';
my @default     = (qw(bounce quiet new reply)); # switch
my @expected    = (defined($ARGV[0]) && $ARGV[0] =~ /^(\w+)$/ ? ($1) : @default);

# Tests
# -----------------------------------------------------------------------------
#
CONTEXT:
foreach my $context (@expected) {
	last CONTEXT unless $err == 0;
	$test++; 
	$err = 0;
	my @tests = $o_test->get_tests("$dir/$context");
	TEST:
	foreach my $test (@tests) {
		last TEST unless $err == 0;
		my $i_ok = 0;
		my ($switch, $data) = &get_switch("$dir/$context/$test");
		$i_ok = ($switch eq "do_$context") ? 1 : 0;
		if ($i_ok != 1) {
			$err++;
			output("$context test($test) failed($i_ok) -> '$switch, $data'");
		}	
	}
	output("$dir/$context -> err($err)") if $err;
	($err == 0) ? ok($test) : ok(0);
}

sub get_switch { # Switch wrapper
	my $file  = shift;
	my ($switch, $args) = ('', '');
	my $o_int = $o_test->file2minet($file);
   	if (!defined($o_int)) {
		croak("failed to get mail($o_int) from file($file)!");
	} else {
		$o_mail->_mail($o_int);
		$^W=0; # many duff headers...
		($switch, $args) = $o_mail->switch($o_int);
		$^W=1;
    }
	return ($switch, $args);
}
		
