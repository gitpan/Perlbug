#!/usr/bin/perl -w
# Email tests for Perlbug: get_forward, default, remap, get_header
# context, get_header
# Richard Foley RFI perlbug@rfi.net
# $Id: 76_Email.t,v 1.2 2000/08/02 08:25:13 perlbug Exp perlbug $
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
my $dir			= './t/testmails/get_headers';
my @expected	= (qw(default get_forward remap get_header_remap get_header_default)); 
my %installed	= ();
my $context		= '';

# Tests
# -----------------------------------------------------------------------------
my @tests = get_tests($dir, @expected);

# 1 DEFAULT 
$err = 0;
$test++; 
$context = 'default';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $o_hdr) = &get_data($test);
	my @res = ();
	if ($ok == 1) {
		TAG:
		foreach my $tag ($o_hdr->tags) { 
			last TAG unless $ok == 1;
			my @lines = $o_hdr->get($tag);
			my @res = $o_mail->$context($tag, @lines); # default
			chomp(@lines, @res);
			my $res = (scalar(@res) >= 1) ? 1 : 0;
			if (iseven($test)) { 	# should have result
				$ok = $res;
			} else {					# should be empty 
				$ok = 1 if $res == 0;
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
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}


# 2 GET_FORWARD
$err = 0;
# perl line mapping
$test++; 
$context = 'get_forward';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $o_hdr) = &get_data($test);
	my @res = ();
	if ($ok == 1) {
		TAG:
		foreach my $tag ($o_hdr->tags) { 
			last TAG unless $ok == 1;
			next TAG unless $tag =~ /^(To|Cc)$/i;
			my @lines = $o_hdr->get($tag);
			LINE:
			foreach my $line(@lines) {
				chomp($line);
				last TAG unless $ok == 1;
				my $res = $o_mail->get_forward($line); # get_forward
				if ($tag =~ /^To|Cc/i) {	
					if (iseven($test)) { # should remap
						$ok = (grep(/^$res$/, $o_mail->get_vals('forward'))) ? 1 : 0;
					} else {			 # should NOT remap
						$ok = ($res eq $o_mail->forward('generic')) ? 1 : 0;
					}
					output("$test tag($tag), line($line) failed -> $res -> ok($ok)") if $ok != 1;
				} else { # always keep it
					$ok = 1;
					# 
				}
				$err++ if $ok != 1;
			}
			output("$test tag($tag) failure: ok($ok)") if $ok != 1;
		}
	}
	if ($ok != 1) {
		$err++;
		output(uc($context)." test ($test) failed -> '@res'");
	}	
}
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}


# 3 REMAP
$err = 0;
# perl line mapping
$test++; 
$context = 'remap';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $o_hdr) = &get_data($test);
	my @res = ();
	if ($ok == 1) {
		TAG:
		foreach my $tag ($o_hdr->tags) { 
			last TAG unless $ok == 1;
			my @lines = $o_hdr->get($tag);
			my @res = $o_mail->$context($tag, @lines); # remap
			chomp(@lines, @res);
			my $res = (scalar(@res) >= 1) ? 1 : 0;
			if ($tag =~ /^To|Cc/i) {	
				RES:
				foreach my $res (@res) {
					last RES unless $ok == 1;
					if (iseven($test)) { # should remap
						$ok = (grep(/^$res$/, $o_mail->get_vals('forward'))) ? 1 : 0;
					} else {			 # should NOT remap
						$ok = (grep(/^$res$/, @lines)) ? 1 : 0;
					}
					output("$test($tag: @lines -> $res, @res) -> ok($ok)") if $ok != 1;
				}
			} else { # always keep it
				$ok = $res;
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
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}

# 4
# GET_HEADER_DEFAULT
$err = 0;
$test++; 
$context = 'get_header_default';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $o_orig) = &get_data($test);
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
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
}


# 5
# GET_HEADER_REMAP
$err = 0;
$test++; 
$context = 'get_header_remap';
foreach my $test (grep(/^$context/, @tests)) {
	my ($ok, $o_orig) = &get_data($test);
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
						if (iseven($test)) { # should remap
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
output("$context -> err($err)") if $err;
if ($err == 0) {	
	ok($test);
} else {
	notok($test);
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
			my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
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


