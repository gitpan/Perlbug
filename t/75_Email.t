#!/usr/bin/perl -w
# Email utilities splice, check_header, in_master_list, setting up for 76_Email.t -> ...
# Richard Foley RFI perlbug@rfi.net
# $Id: 75_Email.t,v 1.2 2000/08/02 08:24:48 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
	plan('tests' => 4);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Email;
use FileHandle;
use Data::Dumper;
use Mail::Internet;
use Sys::Hostname;
my $o_mail = Perlbug::Email->new;
$o_mail->check_user('richardf');
$o_mail->current('admin', 'richardf');
$o_mail->current('isatest', 1);
$Data::Dumper::Indent=1;

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my $dir			= './t/testmails/head_to_head';
my @expected	= (qw(splice check_header in_master_list admin_of_bug)); 
my %installed	= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------

my @tests = get_tests($dir, @expected);

# 1
# splice
$test++; 
$err = 0;
$context = 'splice';
foreach my $test (grep(/^$context/, @tests)) {
	my $FH = FileHandle->new("< $dir/$test");
    if (defined($FH)) {
        my $o_int = Mail::Internet->new($FH);
        close $FH;
    	if (defined($o_int)) {
			$o_mail->_original_mail($o_int);
			my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
			if (!(ref($o_hdr) && $header =~ /\w+/ && $body =~ /\w+/)) {
				$err++;
				output("$test: o_int($o_int) -> o_hdr($o_hdr), header(".length($header)."), body(".length($body).")");
			}
		}
	}
}
output("$context failed -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}


# 2  check_header
# these: given a o_hdr($data), should return 1(success) or 0(failure) based on even/odd file names
$test++; 
$err = 0;
$context = 'check_header';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $o_hdr) = &get_data($test);
	if ($ok == 1) {
		$ok = $o_mail->$context($o_hdr); # o_hdr
		if (!iseven($test) and $ok == 0) { # that's correct
			$ok = 1;
		}
	}
	if ($ok != 1) {
		$err++;
		output("$context test ($test) failed -> '$ok, $o_hdr'");
	}	
	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}


# 3 IN_MASTER_LIST 
$err = 0;
foreach my $context (qw(in_master_list)) {
	$test++; 
	foreach my $test (grep(/^$context/, @tests)) {
		my ($ok, $o_hdr) = &get_data($test);
		if ($ok == 1) {	
			ADDR:
			foreach my $addr ($o_hdr->get('From'), $o_hdr->get('Reply-To')) {
				last ADDR unless $ok == 1;
				chomp($addr);
				my $i_status = $o_mail->$context($addr);
				if (iseven($test)) {
					$ok = 0 if $i_status != 1;
				} else {
					$ok = 0 if $i_status == 1;
				}
				output("Failed($test) $addr -> status($i_status) -> ok($ok)") if $ok != 1;
			}
		}
		if ($ok != 1) {
			$err++;
			output("$context($test) failed");
		}	
	}
	output("$context -> err($err)") if $err;
	if ($err == 0) {	
		ok($test);
	} else {
		notok($test);
	}
}

# 4 ADMIN_OF_bugid (tm_claimants, tm_cc, tm_bugids)
$err = 0;
$o_mail->current('admin', ''); # !
foreach my $context (qw(admin_of_bugid)) {
	$test++; 
	ok(1);
	next; # rjsf - temp!
	my ($tid) = $o_mail->get_list("SELECT MAX(bugid) FROM tm_bug WHERE sourceaddr LIKE '%perlbug_test\@rfi.net%'");
	foreach my $test (grep(/^$context/, @tests)) {
		my ($ok, $o_hdr) = &get_data($test);
		if ($ok == 1) {
			my $i_status = $o_mail->$context($tid, ''); # $o_mail->isadmin);
			if (iseven($test)) {
				$ok = 0 if $i_status != 1;
			} else {
				$ok = 0 if $i_status == 1;
			}
			output("Failed($test) $tid -> status($i_status) -> ok($ok)") if $ok != 1;
		}
		if ($ok != 1) {
			$err++;
			output("$context($test) failed for: ".$o_mail->isadmin);
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
	my $data = '';
	my $ok = 1;
	my $FH = FileHandle->new("< $dir/$file");
    if (defined($FH)) {
        my $o_int = Mail::Internet->new($FH);
		close $FH;
		if (defined($o_int)) {
			$o_mail->_original_mail($o_int);
			my ($o_hdr, $header, $body) = $o_mail->splice;
			$ok = 0 unless ref($o_hdr) and $header =~ /\w+/ and $body =~ /\w+/;
			$data = $o_hdr;
		} else {
			output("Mail($o_int) not retrieved");		
		}
	} else {
        output("FileHandle($FH) not defined for file ($file): $!");
    }
	return ($ok, $data);
}


