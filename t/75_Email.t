#!/usr/bin/perl -w
# Email utilities splice, check_incoming, in_master_list, setting up for 76_Email.t -> ...
# Richard Foley RFI perlbug@rfi.net
# $Id: 75_Email.t,v 1.4 2001/04/21 20:48:48 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 3);
}
use strict;
use lib qw(../);
my $TEST = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Interface::Email;
use FileHandle;
use Data::Dumper;
use Mail::Internet;
use Sys::Hostname;
my $o_mail = Perlbug::Interface::Email->new;
my $o_test = Perlbug::TestBed->new($o_mail);
$o_mail->check_user('richardf');
$o_mail->current('admin', 'richardf');
$Data::Dumper::Indent=1;

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my $dir			= './t/email/75';
my @expected	= (qw(splice check_incoming in_master_list)); 
my %installed	= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------


# 1
# splice
$TEST++; 
$err = 0;
$context = 'splice';
my @tests= $o_test->get_tests("$dir/$context");
foreach my $test (@tests) {
	my $o_int = $o_test->file2minet("$dir/$context/$test");
	if (defined($o_int)) {
		$o_mail->_original_mail($o_int);
		my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
		if (!(ref($o_hdr) && $header =~ /\w+/ && $body =~ /\w+/)) {
			$err++;
			output("$context/$test: o_int($o_int) -> o_hdr($o_hdr), header(".length($header)."), body(".length($body).")");
		}
	}
}
output("$dir/$context failed -> err($err)") if $err;
($err == 0) ? ok($TEST) : ok(0); 


# 2  check_incoming
# these: given a o_hdr($data), should return 1(success) or 0(failure) based on even/odd file names
$TEST++; 
$err = 0;
$context = 'check_incoming';
@tests = $o_test->get_tests("$dir/$context");
foreach my $test (@tests) {
	my ($ok, $o_hdr) = &get_data("$dir/$context/$test");
	my $i_status = $o_mail->$context($o_hdr); 
	$ok = 0;
	my $i_isodd = $o_test->isodd($test);
	if ($i_isodd) {
		$ok = ($i_status == 1) ? 1 : 0;
	} else {
		$ok = ($i_status == 0) ? 1 : 0;
	}	
	if ($ok != 1) {
		$err++;
		output("$context/$test failed isodd($i_isodd) status($i_status) success($ok)");
	}	
}
output("$dir/$context -> err($err)") if $err;
($err == 0) ? ok($TEST) : ok(0); 


# 3 IN_MASTER_LIST 
$err = 0;
$TEST++; 
$context = 'in_master_list';
@tests = $o_test->get_tests("$dir/$context");
foreach my $test (@tests) {
	my ($ok, $o_hdr) = &get_data("$dir/$context/$test");
	my @failed = ();
	my $i_errs = 0;
	ADDR:
	foreach my $addr ($o_hdr->get('From'), $o_hdr->get('Reply-To')) {
		chomp($addr);
		my $i_status = $o_mail->$context($addr); 
		my $ok = 0;
		my $i_isodd = $o_test->isodd($test);
		if ($i_isodd) {
			$ok = ($i_status == 1) ? 1 : 0;
		} else {
			$ok = ($i_status == 0) ? 1 : 0;
		}	
		if ($ok != 1) {
			output("\t\tchecked($addr) i_isodd($i_isodd) status($i_status) failed($ok)!"); 
			$i_errs++;
			push(@failed, $addr);
		}
	}
	if ($i_errs != 0) {
		$err++;
		output("\t$dir/$context/$test) failed(@failed)");
	}	
}
output("$context -> err($err)") if $err;
($err == 0) ? ok($TEST) : ok(0); 

# Done
# -----------------------------------------------------------------------------
# .
		
sub get_data { # get mail, data, scan, return data
	my $file = shift;
	my $context = shift;
	my $meth = $file;
	$meth =~ s/^(.+)_\d+$/$1/;
	my ($ok, $data) = (0, '');
	my $o_int = $o_test->file2minet($file);
	if (defined($o_int)) {
		$o_mail->_original_mail($o_int);
		my ($o_hdr, $header, $body) = $o_mail->splice;
		$ok++ if ref($o_hdr) and $header =~ /\w+/ and $body =~ /\w+/;
		$data = $o_hdr;
	}
	return ($ok, $data);
}


