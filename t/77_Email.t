#!/usr/bin/perl -w
# Email tests for Perlbug: Mail::Header oriented checks in(o_hdr) -> out(o_hdr|o_send|undef)
# Richard Foley RFI perlbug@rfi.net
# $Id: 77_Email.t,v 1.4 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 3);
}
use strict;
$|=1;
use lib qw(../);
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Interface::Email;
use Perlbug::TestBed;
use FileHandle;
use Data::Dumper;
use Mail::Internet;
use Sys::Hostname;
my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::TestBed->new($o_mail);
$o_mail->current({'admin', 'richardf'});
$Data::Dumper::Indent=1;

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my $dir			= './t/email/77';
my @expected	= (qw(trim_to clean_header defense)); 
my %installed	= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------

# 1-3
# trim_to, clean_header, defense
foreach my $context (@expected) {
	$test++; 
	$err = 0;
	my @tests = $o_test->get_tests("$dir/$context");
	TEST:
	foreach my $test (@tests) {
		last TEST unless $err == 0;
		my ($orig, $o_orighdr) = &get_data("$dir/$context/$test");
		$^W=0;
		my $o_hdr = $o_mail->$context($o_orighdr);
		$^W=1;
		my $ok = 0;
		my $i_isodd = $o_test->isodd($test);
		if ($i_isodd) {
			$ok = ref($o_hdr) ? 1 : 0;
		} else {
			$ok = ref($o_hdr) ? 0 : 1;
		}
		if ($ok != 1) {
			$err++;
			output("$context/$test failed: isodd($i_isodd) hdr($o_hdr) orig($o_orighdr) -> ok($ok)"); 
		}	
	}
	output("$dir/$context -> err($err)") if $err;
	($err == 0) ? ok($test) : ok(0);
}


# Done
# -----------------------------------------------------------------------------
# .
		
sub get_data { # get mail, data, scan, return data
	my $file = shift;
	my $context = shift;
	my $meth = $file;
	$meth =~ s/^(.+)_\d+$/$1/;
	my ($ok, $o_hdr) = (0, '');
	my $o_int = $o_test->file2minet($file);
	if (defined($o_int)) {
		$o_mail->_original_mail($o_int);
		($o_hdr, my ($header, $body)) = $o_mail->splice($o_int);
		$ok++ if ref($o_hdr);
	}
	return ($ok, $o_hdr);
}


