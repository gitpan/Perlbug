#!/usr/bin/perl -w
# Email tests for Perlbug: check bugdb::parse_mail(subject, body)->$h_ref: requires special X-Matches parsing
# Richard Foley RFI perlbug@rfi.net
# $Id: 73_Email.t,v 1.2 2000/12/19 13:11:31 perlbug Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 3); # rjsf - 4
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
$o_mail->check_user('richard@rfi.net'); # enable 

# Setup
# -----------------------------------------------------------------------------
my $err			= 0;
my $dir			= './t/data/73';
my @expected	= (qw(header2admin scan_header parse_commands parse_mail)); 
@expected	= (qw(scan_header parse_commands parse_mail)); 
	#  parse_commands should be in Cmd
my %installed	= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------
# 
# 1-4
# HEADER2ADMIN SCAN_HEADER PARSE_COMMANDS PARSE_MAIL
foreach my $context (@expected) {
	$err = 0;
	$test++; 
	my @tests = $o_test->get_tests("$dir/$context");
	foreach my $test (@tests) {
		my ($ok, $data) = &get_data("$dir/$context/$test");
		if ($ok != 1) {
			$err++;
			output("$context($test) failed -> '$data'");
		}	
	}
	output("$context -> err($err)") if $err;
	($err == 0) ? ok($test) : ok(0);
}


# Done
# -----------------------------------------------------------------------------
# .
		
sub get_data { # get mail, data, scan, return $data as per fmt() 
	my $file = shift;
    my $data = '';
	my $ok = 0;
	my $o_int = $o_test->file2minet($file);
	if (defined($o_int)) {
		$o_mail->_original_mail($o_int);
		my ($o_hdr, $header, $body) = $o_mail->splice;
		my $to   	= $o_hdr->get('To');
		my $subject	= $o_hdr->get('Subject');
		my $matches = $o_hdr->get('X-Matches');
		chomp($to, $subject, $matches, $body);
		my $h_data = $o_mail->parse_mail($o_int);
		if (!((ref($h_data) eq 'HASH') and ($matches =~ /\w+/) and ($to =~ /\w+/) and ($subject =~ /\w+/) and ($body =~ /\w+/))) {
			output("Data failure for file($file): h_data($h_data), matches($matches) or to($to) or subject($subject) or body($body) doesn't look good!");
		} else {
			$ok = 1;
			$data = $o_mail->fmt($h_data);
			MATCH:	
			foreach my $match (split(' ', $matches)) { 	#  regex regex regex regex ...
				last MATCH unless $ok == 1;
				next unless defined($match) and $match =~ /\w+/;
				if ($data !~ /$match/i) {
					$ok = 0;
					output("Failed($file) -> expected match($match)");
				} 
			}
		}
    }
	return ($ok, $data);
}
