# $Id: Testing.pm,v 1.1 2000/08/10 10:48:27 perlbug Exp perlbug $ 

=head1 NAME

Perlbug::Testing - Perlbug testing module

=cut

package Perlbug::Testing;
BEGIN { $|=1; }
use Data::Dumper;
use Exporter;
use Test;
use File::Spec; 
use lib File::Spec->updir;
use strict;
use vars qw($VERSION @EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(get_tests plan ok notok output iseven getnow); 
$VERSION = 1.03;
my $TESTS 		= 0; # ignored
my @EXPECTED 	= ();
my @TESTS 		= ();
my @BUGIDS      = ();
my $OK  		= 1;


=head1 DESCRIPTION

Utility functions for Perlbug test scripts.

If run within a 'make test' sequence, the prints will normally only appear from the C<todo>, C<ok> and C<notOK> calls.

Output is seen from C<output> when C<TEST_VERBOSE> is set to B<1>, or when the script is being run directly.

Note that files with iseven(filename)s (test_2, test_8, etc) are normally expected to succeed with the given function test, and odd names are expected to fail, thus giving a checkable failure.  

Names with only a zero, ie: my_test_0 are purely placeholders, and should be ignored.

=head1 SYNOPSIS

    use Perlbug::Testing;
	use Testing;
	plan('todo' => 8); # will do nine(9)
	my $test = 0;
	
	my $o_test = Perlbug::Testing->new('Email'); # currently ignored
	my @tests = get_tests('testmails/head2head', qw(this that etc));
	
	my ($i_ok, $data) = $o_test->check_header(*STDIN); # for example
	if ($i_ok == 1) { # == 1 (hopefully :-) || 0 :-(
		ok($test);
	} else {
		notok($test);
	}
	
	output($test, 'data');
	output("done test($test)");
	

=head1 METHODS

=over 4

=item new

Create new Perlbug::Testing object:

    my $o_test = Perlbug::Testing->new();				# generic

	my $o_email_test = Perlbug::Testing->new('Email'); # guess :-)

=cut

sub new {
    my $class = shift;
	my $self  = {};
    bless($self, $class);
}

sub notok {
	ok(0);
	$OK = 0;
}

=item output

prints given args

=cut

sub output { 
	print "@_\n"; 
}

=item iseven

Return 0(odd) or 1(even) based on last number of given filename

	my $num = iseven($filename);

=cut

sub iseven {
	my $file = shift;
	return ($file =~ /^.+[02468]$/) ? 1 : 0;
}

sub getnow {
	my $it = 'perlbugtron_'.$$.'_'.rand(time);
	return $it;
}

=item get_tests

Wraps getting test material from test directory, incorporates test count.

	my @test = get_tests($t_dir, qw(this that and the other));

=cut

sub get_tests {
	my $dir  	 = shift; # './t/testmails/bugdb' ...
	my @expected = @_;	  # 
	my @tests    = ();
	my @notfound = ();
	my $expected = join('|', @expected);
	
	# directory exists? 
	if (!-d $dir) {	
		notok;
		output("dir($dir) not found: $!");
	} else {
		if (!opendir(DIR, $dir)) {
			notok;
			output("Can't open dir($dir) $!");
		} else {
			@tests = grep{ /^($expected).*?\d+$/ && -f "$dir/$_"} readdir(DIR);
			close DIR;
			if (!(scalar(@tests) >= 1)) {
				notok;
				output("Can't get testfiles(@tests) from dir($dir) $!");
			} else {
				foreach my $test (@expected) {
					if (grep(/^$test/, @tests)) {
						# found
					} else {
						push(@notfound, $test);
					}
				}
				if (scalar(@tests) >= 1 && scalar(@notfound) == 0) {
					# ok(1); silent?
				} else {
					notok;
					output("Test files expected (@expected), not found (@notfound)");
				} 
			}
		}
	}
	if ($OK != 1) {
		@tests = ();
		output("get_test($dir, w/files) failure!");
    	exit(0); # clean
	}
	return @tests;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;

__END__

sub _get_data { # get mail, data, scan, return data
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
			my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
			my @should 		= $o_hdr->get('X-Perlbug-Match') 	 || ();
			my @shouldnt 	= $o_hdr->get('X-Perlbug-Match-Non') || ();
			my @shouldfail 	= $o_hdr->get('X-Perlbug-Match-Bad') || ();
			my $tag  		= $o_hdr->get('X-Perlbug-Tag') || '';
			my $line 		= $o_hdr->get('X-Perlbug-Line')|| '';
			if ($tag !~ /\w+/ || $line !~ /\w+/) {
				$ok = 0;
				$data = "No tag($tag) or line($line) found for test($file)";
			} else {
				($ok, my @ret) = $o_mail->$meth($tag, $line);
				if ($ok == 1) {
					$o_hdr->replace($tag, @ret);
					($ok, $data) = $o_mail->check_mail($o_hdr, $body, \@should, \@shouldnt, \@shouldfail);
				} else {
					$data = "Failure in $meth(@ret)";
				}
			}
		} else {
			output("Mail($o_int) not retrieved");		
		}
	} else {
        output("FileHandle($FH) not defined for file ($file): $!");
    }
	return ($ok, $data);
}
