#!/usr/bin/perl -w
# Email tests for Perlbug: Mail::Header oriented checks in(o_hdr) -> out(o_hdr|o_send|undef)
# Richard Foley RFI perlbug@rfi.net
# $Id: 77_Email.t,v 1.2 2000/08/02 08:25:28 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 3);
}
use strict;
$|=1;
use lib qw(../);
my $test = 0;

# Libs
# -----------------------------------------------------------------------------
use Perlbug::Email;
use Perlbug::Testing;
use FileHandle;
use Data::Dumper;
use Mail::Internet;
use Sys::Hostname;
my $o_mail = Perlbug::Email->new;
$o_mail->current('admin', 'richardf');
$o_mail->current('isatest', 1);
$Data::Dumper::Indent=1;

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my $dir			= './t/testmails/head_to_head';
my @expected	= (qw(trim_to clean_header defense)); 
my %installed	= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------
my @tests = get_tests($dir, @expected);

# 1-3
# trim_to, clean_header, defense
foreach my $context (@expected) {
	$test++; 
	$err = 0;
	foreach my $test (grep(/^$context/, @tests)) {
		my ($ok, $o_hdr) = &get_data($test);
		$o_hdr = $o_mail->$context($o_hdr);
		if (iseven($test)) {
			$ok = 0 unless ref($o_hdr);
		} else {
			$ok = 0 if ref($o_hdr);
		}
		if ($ok != 1) {
			$err++;
			output("$context test ($test) failed -> '$o_hdr'");
		}	
	}
	output("$context -> err($err)") if $err;
	if ($err == 0) {	
		ok($test);
	} else {
		notok($test);
	}
}


# Done
# -----------------------------------------------------------------------------
# .
		
sub get_data { # get mail, data, scan, return data
	my $file = shift;
	my $context = shift;
	my $meth = $file;
	$meth =~ s/^(.+)_\d+$/$1/;
	my $data = ();
	my $ok = 1;
	my $FH = FileHandle->new("< $dir/$file");
    if (defined($FH)) {
        my $o_int = Mail::Internet->new($FH);
        close $FH;
    	if (defined($o_int)) {
			$o_mail->_original_mail($o_int);
			my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
			$data = $o_hdr;
		} else {
			output("Mail($o_int) not retrieved");		
		}
	} else {
        output("FileHandle($FH) not defined for file ($file): $!");
    }
	return ($ok, $data);
}


