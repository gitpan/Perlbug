#!/usr/bin/perl -w
# Email tests for Perlbug: get_forward, default, remap, get_header
# context, get_header
# Richard Foley RFI perlbug@rfi.net
# $Id: 76_Email.t,v 1.4 2001/04/21 20:48:48 perlbug Exp $
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
my $dir			= './t/email/76';
my @orig		= (qw(default get_forward remap get_header_remap get_header_default)); 
my @expected    = (defined($ARGV[0]) && $ARGV[0] =~ /^(\w+)$/ ? ($1) : @orig);
my %installed	= ();
my $context		= '';
my @tests		= ();

# Tests
# -----------------------------------------------------------------------------

# 1 DEFAULT 
$err = 0;
$test++; 
$context = 'default';
if (grep(/^$context$/, @expected)) {
@tests = $o_test->get_tests("$dir/$context");
foreach my $test (@tests) {
	my ($ok, $o_hdr) = &get_data("$dir/$context/$test");
	my @res = ();
	if ($ok == 1) {
		TAG:
		foreach my $tag ($o_hdr->tags) { 
			last TAG unless $ok == 1;
			my @lines = $o_hdr->get($tag);
			my $res = my @res = $o_mail->$context($tag, @lines); # default
			chomp(@lines, @res);
			if ($o_test->isodd($test)) { 	# should have result
				$ok = 0 unless scalar(@res) >= 1;
			} else {						# should be empty 
				$ok = 0 if scalar(@res) >= 1;
			}
			output("$test tag($tag: @lines) --> failed($ok) <-- recieved($res, @res)") if $ok != 1;
			$err++ if $ok != 1;
		}
	}
	if ($ok != 1) {
		$err++;
		output(uc($context)." test ($test) failed -> '@res'");
	}	
}
}
output("$dir/$context -> err($err)") if $err;
($err == 0) ? ok($test) : ok(0);


# perl line mapping
$test++; 
$err = 0;
$context = 'get_forward';
if (grep(/^$context$/, @expected)) {
@tests = $o_test->get_tests("$dir/$context");
TEST:
foreach my $test (@tests) {
	last TEST unless $err == 0;
	my ($isok, $o_hdr) = &get_data("$dir/$context/$test");
	my @res = ();
	if ($isok == 1) {
		my $i_errs= 0;
		TAG:
		foreach my $tag ($o_hdr->tags) { 
			next TAG unless $tag =~ /^(To|Cc)$/i;
			my @lines = $o_hdr->get($tag);
			LINE:
			foreach my $line(@lines) {
				chomp($line);
				my ($res) = $o_mail->$context($tag, $line); # get_forward
				my $remap = grep(/^$res$/i, $o_mail->get_vals('forward'));
				my $i_isok = $o_test->okbyfilearg($test, $remap);
				if ($i_isok != 1) {
					output("$test($context) tag($tag) line($line) res($res) remap($remap) i_isok($i_isok)"); 
					$i_errs++; 
				}
			}
		}
		$isok = 0 if $i_errs >= 1;
	}
	if ($isok != 1) {
		$err++;
		output(uc($context)." test ($test) failed($isok)");
	}	
}
}
output("$dir/$context -> err($err)") if $err;
($err == 0) ? ok($test) : ok(0);


# 3 REMAP
# per line forwarding 
$test++; 
$err = 0;
$context = 'remap';
if (grep(/^$context$/, @expected)) {
@tests = $o_test->get_tests("$dir/$context");
TEST:
foreach my $test (@tests) {
	last TEST unless $err == 0;
	my ($isok, $o_hdr) = &get_data("$dir/$context/$test");
	if ($isok == 1) {
		my $i_errs= 0;
		TAG:
		foreach my $tag ($o_hdr->tags) { 
			next TAG unless $tag =~ /^(To|Cc)$/i;
			my @lines = $o_hdr->get($tag);
			LINE:
			foreach my $line(@lines) {
				chomp($line);
				my ($res) = $o_mail->$context($tag, $line); # get_forward
				my $remap = grep(/^$res$/i, $o_mail->get_vals('forward'));
				my $i_isok = $o_test->okbyfilearg($test, $remap);
				if ($i_isok != 1) {
					output("$test($context) tag($tag) line($line) res($res) remap($remap) i_isok($i_isok)"); 
					$i_errs++; 
				}
			}
		}
		$isok = 0 if $i_errs >= 1;
	}
	if ($isok != 1) {
		$err++;
		output(uc($context)." test ($test) failed($isok)");
	}	
}
}
output("$dir/$context -> err($err)") if $err;
($err == 0) ? ok($test) : ok(0);



# 4
# GET_HEADER_DEFAULT
$err = 0;
$test++; 
$context = 'get_header_default';
if (grep(/^$context$/, @expected)) {
@tests = $o_test->get_tests("$dir/$context");
TEST:
foreach my $test (@tests) {
	last TEST unless $err == 0;
	my ($ok, $o_orig) = &get_data("$dir/$context/$test");
	my $o_hdr = $o_mail->get_header($o_orig, 'default');
	$ok = 0 unless ref($o_hdr);
	if ($ok == 1) {
		my %map = (
			'Message-Id' => 'ne',
			'Reply-To'	 => 'ne',
			'From'		 => 'ne',
			'Subject'	 => 'eq',
			'To'		 => 'eq',
			'Cc'		 => 'eq',
		);
		TAG:
		foreach my $tag ($o_orig->tags, $o_hdr->tags) { # check both
			last TAG unless $ok == 1;
			my $old = $o_orig->get($tag);
			next TAG unless $old =~ /\w+/; 		# had something to operate on
			my $new = $o_hdr->get($tag);
			if (grep(/^$tag$/, keys %map)) { 	# if one of ours
				if (defined($new)) {			# must be defined 
					chomp($old, $new);
					if ($map{$tag} eq 'eq') {
						$ok = 0 unless $new eq $old;
						output("tag($tag, $old) should ($map{$tag}) be the same($new) -> ok($ok)") if $ok != 1;
					} else {
						$ok = 0 unless $old ne $new;
						output("tag($tag, $old) should ($map{$tag}) be different($new) -> ok($ok)") if $ok != 1;
					}
				} else {
					$ok = 0;
					output("tag($tag, $old) expects value($new) -> ok($ok)") if $ok != 1;
				}
			} else { 							# must not appear = should have been trounced!
				$ok = 0 unless !defined($new);
				output("tag($tag, $old) expects no value($new) -> ok($ok)") if $ok != 1;
			}
			output("$context($test): $tag: $old -> $new failure($ok)") if $ok != 1;
		}
	
	}
	if ($ok != 1) {
		$err++;
		output("$context($test) failed -> '$o_hdr'");
	}	
}
}
output("$dir/$context -> err($err)") if $err;
($err == 0) ? ok($test) : ok(0);


# 5
# GET_HEADER_REMAP
$err = 0;
$test++; 
$context = 'get_header_remap';
if (grep(/^$context$/, @expected)) {
@tests = $o_test->get_tests("$dir/$context");
TEST:
foreach my $test (@tests) {
	last TEST unless $err == 0;
	my ($ok, $o_orig) = &get_data("$dir/$context/$test");
	my $o_hdr = $o_mail->get_header($o_orig, 'remap');
	$ok = 0 unless ref($o_hdr);
	if ($ok == 1) {
		TAG:
		foreach my $tag ($o_orig->tags, $o_hdr->tags) { # check both
			last TAG unless $ok == 1;
			my @old = $o_orig->get($tag);
			next TAG unless scalar(@old) >= 1; 			# had something to operate on
			my @lines = $o_hdr->get($tag);
			foreach my $new (@lines) {
				if (defined($new)) {					# must appear
					chomp(@old, $new);
					if ($tag =~ /^(To|Cc)$/i) { 	# one of ours
						if ($o_test->isodd($test)) { # should remap
							$ok = (grep(/^$new$/, $o_mail->get_vals('forward'))) ? 1 : 0;
							output("$test($tag: @old) should remap($new) -> ok($ok)") if $ok != 1;
						} else {			 # should NOT remap
							$ok = (grep(/^$new$/, @lines)) ? 1 : 0;
							output("$test($tag: @old) should not remap($new) -> ok($ok)") if $ok != 1;
						}
					} else {							# should be the same
						$ok = 0 unless grep(/$new/, @old);
						output("$test($tag) should be maintained new($new) NOT IN old(@old) -> ok($ok)") if $ok != 1;
					}
				} else { 								# should have a value
					$ok = 0;
					output("$test($tag: @old) expects a value($new) -> ok($ok)");
				}
			}
			output("$test($tag: @old) -> '@lines' failure($ok)") if $ok != 1;
		}
	
	}
	if ($ok != 1) {
		$err++;
		output("$context($test) failed -> '$o_hdr'");
	}	
}
}
output("$dir/$context -> err($err)") if $err;
($err == 0) ? ok($test) : ok(0);


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
		my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
		$ok++ if ref($o_hdr) and $header =~ /\w+/ and $body =~ /\w+/;
		$data = $o_hdr;
	}
	return ($ok, $data);
}


