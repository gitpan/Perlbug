#!/usr/bin/perl -w
# Email tests for Perlbug: check the tron scanning of mail bodies for category, etc. - requires special scan matching
# Richard Foley RFI perlbug@rfi.net
# $Id: 72_Email.t,v 1.3 2000/08/02 08:23:15 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Testing;
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
$o_mail->current('admin', 'richardf');

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my $dir			= './t/testmails/scan_body';
my @expected	= (qw(category osname severity status version));
my %all_flags   = $o_mail->all_flags;
my %installed	= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------

my @tests = get_tests($dir, @expected);

# rjsf
# foreach (keys %{$self->all_flags}) {
#   # expected vals in $self->flags($key) etc.
# }
#

# 1
# CATEGORY
$test++; 
$err = 0;
$context = 'category';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $data) = &get_data($test);
	# output("data=$data");
	# get category types from db
	if ($ok != 1) {
		$err++;
		output("$context test ($test) failed -> '$data'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 2
# OSNAME
$test++; 
$err = 0;
$context = 'OSNAME';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $data) = &get_data($test);
	# output("data=$data");
	# *** get osname flags from db
    my $rex = join('|', $o_mail->flags($context));
	if (($ok == 1) && ($data !~ /$context\=($rex)/)) { 
		$err++;
		output("$context test ($test) failed -> '$data'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 3
# SEVERITY
$test++; 
$err = 0;
$context = 'severity';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $data) = &get_data($test);
	# output("data=$data");
	# get severity types from db
    my $rex = join('|', $o_mail->flags($context));
	if (($ok == 1) && ($data !~ /$context\=($rex)/)) {
		$err++;
		output("$context test ($test) failed -> '$data'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 4
# STATUS
$test++; 
$err = 0;
$context = 'status';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $data) = &get_data($test);
	# output("data=$data");
	# get status from db
    my $rex = join('|', $o_mail->flags($context));
	if (($ok == 1) && ($data !~ /$context\=($rex)/)) {
		$err++;
		output("$context test ($test) failed");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 5
# VERSION
$test++; 
$err = 0;
$context = 'version';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $data) = &get_data($test);
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
	notok($test);
}

# Done
# -----------------------------------------------------------------------------
# .
		
sub get_data { # get mail, data, scan, return $data as per fmt() 
	my $file = shift;
    my $data = '';
	my $ok = 0;
	my $FH = FileHandle->new("< $dir/$file");
    if (defined($FH)) {
        my $o_int = Mail::Internet->new($FH);
        close $FH;
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
					next unless defined($match) and $match =~ /\w+/;
					if ($data !~ /\s*$match\s*/m) {
						$ok = 0;
						output("Failed '$file': expected match($match) in data($data)");
					} 
					last MATCH unless $ok == 1;
				}
			}
		} else {
			output("Mail($o_int) not retrieved");		
		}
	} else {
        output("FileHandle($FH) not defined for file ($dir/$file): $!");
    }
	return ($ok, $data);
}
