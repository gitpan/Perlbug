# $Id: TestBed.pm,v 1.9 2001/04/21 20:48:48 perlbug Exp $ 

=head1 NAME

Perlbug::TestBed - Perlbug testing module

=cut

package main;
use Test; # Harness plan, ok, notok

package Perlbug::TestBed;
$VERSION = do { my @r = (q$Revision: 1.9 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_TestBed_DEBUG'} || $Perlbug::TestBed::DEBUG|| '';

BEGIN { $|=1; }
use Data::Dumper;
use Exporter;
use Test; # Harness plan, ok, notok
use strict;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(output);
my $TESTS 		= 0; # ignored
my @EXPECTED 	= ();
my @TESTS 		= ();
my @BUGIDS      = ();
my $OK  		= 1;


=head1 DESCRIPTION

Utility functions for Perlbug test scripts, several wrappers for the email side of things...

Output is seen from C<output> when C<TEST_VERBOSE> is set to B<1>, or when the script is being run directly.

Note that files with B<odd> filenames (test_1, test_5, etc) are normally expected to succeed with the given function test, and B<even> names are expected to fail, thus giving a checkable failure.  

Names with only a zero, ie: my_test_0 are purely placeholders, and should be ignored.

	All tests sit in directories with only numbers for names.

	Testable per dir|file

		0 = placeholder
		1 = success
		2 = failure

There are a couple of email specific helper methods which require input from a particular set of tags, L<minet2args()>, L<minet2tagline()> and L<check_mail()>.


=head1 SYNOPSIS

    use Perlbug::TestBed;
	use TestBed;
	plan('todo' => 8); # will do nine(9)
	my $test = 0;
	
	my $o_test = Perlbug::TestBed->new('Email'); # currently ignored
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

Create new Perlbug::TestBed object:

    my $o_test = Perlbug::TestBed->new();              # generic

	my $o_email_test = Perlbug::TestBed->new('Email'); # guess :-)

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $args  = shift;
	my $self  = {
		'objects' => [],
	};
	if (ref($args)) {
		if ($args->can('current')) {
			$args->current({'isatest', 1});
			($DEBUG) = $args->current('debug') || $DEBUG;
		}
		push(@{$self->{'objects'}}, $args);
	}
	$DEBUG = $Perlbug::DEBUG || $DEBUG; 
    bless($self, $class);
}


=item output

prints given args

=cut

sub output { 
	# my $self = shift;
	print "@_\n";
	# warn "@_\n";
	# ($Perlbug::DEBUG >= 2) ? warn "@_" : print "@_\n"; 
}


=item iseven

Return 0(odd) or 1(even) based on last number of given filename

	my $num = iseven($filename);

=cut

sub iseven {
	my $self = shift;
	my $file = shift;
	my $stat = ($file =~ /[02468](\.\w+)*$/) ? 1 : 0;
	# output("iseven($file) ?-> $stat");
	return $stat;
}


=item isodd 

Return 1(odd) or 0(even) based on last number of given filename

	my $num = isodd($filename);

=cut

sub isodd {
	my $self = shift;
	my $file = shift;
	my $stat = ($file =~ /[13579](\.[a-zA-Z]+)*$/) ? 1 : 0;
	# output("isodd($file) ?-> $stat");
	return $stat;
}


=item okbyfilearg

Return 1(ok) or 0(not) based on filename and arg, where arg just has to be successful in some way.

	$i_isok = okbyfilearg('test0.tst', 1); # false (0) 

	$i_isok = okbyfilearg('test1.tst', 1); # true  (1) 

	$i_isok = okbyfilearg('test2.tst', 0); # true  (1)

	$i_isok = okbyfilearg('test3.tst', 0); # false (0)

=cut

sub okbyfilearg {
	my $self  = shift;
	my $file  = shift;
	my $arg   = shift || '';

	my $i_res = ($self->isodd($file)
		? ($arg ? 1 : 0)  
		: ($arg ? 0 : 1)
	);
	# print "Test: file($file) arg($arg) -> res($i_res)\n";

	return $i_res;
}


=item get_rand_msgid

Returns randomised recognisableid . processid . rand(time)

	my $it = get_rand_msgid();

=cut

sub get_rand_msgid {
	my $it = 'perlbugtron_'.$$.'_'.rand(time);
	return $it;
}


=item get_tests

Wraps getting test material filenames from test directory, incorporates test count and check that all expected types are found.

	my @tests = get_tests($t_dir, qw(this that and the other)); 

Fails if expected directory list or any files not found.

=cut

sub get_tests {
	my $self 	 = shift;
	my $dir  	 = shift; # './t/data/72/osname' ...
	my @tests    = ();
	my @notfound = ();
	
	# directory exists? 
	if (!-d $dir) {	
		output("dir($dir) not found: $!");
	} else {
		if (!opendir(DIR, $dir)) {
			output("Can't open dir($dir) $!");
		} else {
			@tests = sort grep{ /^\d+\.dat$/ && -f "$dir/$_"} readdir(DIR);
			close DIR;
		}
	}
	if (!scalar(@tests) >=1) {
		ok(0);
		output("Can't get testfiles(@tests) from dir($dir): $!");
	}
	return @tests;
}


=item file2minet

Return Mail Iinternet object from dir,file:

Or undef:

	my $o_int = file2minet($filename);

=cut

sub file2minet {
	my $self  = shift;
	my $file  = shift;
	my $o_int = '';
	my $FH = FileHandle->new("< $file");
    if (!defined($FH)) {
		undef $o_int;
        warn("FileHandle($FH) not defined for file ($file): $!");
	} else {	
        $o_int = Mail::Internet->new($FH);
        close $FH;
    	if (!defined($o_int)) {
			output("Mail($o_int) not retrieved");		
		}
    }
	return $o_int; 
}


=item minet2args

Wrapper to return args from Mail Internet object, ready for method L<check_mail(@args)>

Or ();

	my @args = minet2args($o_int); 	

=cut

sub minet2args {
	my $self 	= shift;
	my $o_int	= shift;
	my $i_ok 	= 1;
	my @args 	= ();
	
	if (!ref($o_int)) {
		$i_ok = 0;
		$self->error("No Mail Internet object($o_int) given!");
	} else {	
		# my ($o_hdr, $header, $body) = $self->splice($o_int);
		my @should 		= $o_int->get('X-Perlbug-Match') 	 	|| ();
		my @shouldnt 	= $o_int->get('X-Perlbug-MisMatch') 	|| ();
		my @shouldfail 	= $o_int->get('X-Perlbug-MalMatch') 	|| ();
		my $tag  		= $o_int->get('X-Perlbug-Tag') 			|| '';
		my $line 		= $o_int->get('X-Perlbug-Line')			|| '';
		if (!(scalar(@should) >= 1 && scalar(@shouldnt) >= 1 )) {
			 #  scalar(@shouldfail) >= 1)) { 
			 $i_ok = 0;
			 output("Missing checking headers from int($o_int)");
			 output(" should(@should), shouldnt(@shouldnt), shouldfail(@shouldfail)");
		} else { # tag, line sind occasional
			@args = (\@should, \@shouldnt, \@shouldfail, $tag, $line);
		}
	}	
	return @args;
}


=item minet2tagline

Returns X-Perlbug-Tag and X-Perlbug-Line headers from Mail Internet object:

Or ();
	
Instead of: 

	my ($o_hdr, $header, $body) = $self->splice($o_int);
	my $tag  = $o_hdr->get('X-Perlbug-Tag')  || '';
	my $line = $o_hdr->get('X-Perlbug-Line') || '';

You can:

	my ($tag, $line) = minet2tagline($o_int);

=cut

sub minet2tagline {
	my $self 	= shift;
	my $o_int	= shift;
	my @args 	= ();
	
	if (!ref($o_int)) {
		$self->error("No Mail Internet object($o_int) given!");
	} else {	
		my ($o_hdr, $header, $body) = $self->splice($o_int);
		my $tag  = $o_hdr->get('X-Perlbug-Tag')  || '';
		my $line = $o_hdr->get('X-Perlbug-Line') || '';
		if (!($tag =~ /\w+/ && $line =~ /\w+/)) {
			 output("Missing tag/line headers from int($o_int)");
			 output("tag($tag), line($line)");
		} else { # tag, line sind occasional
			@args = ($tag, $line);
		}
	}	
	return @args;
}


=item check_mail

Check headers against various given parameters, attempts to read all required lines/data.

	my ($o_hdr, $header, $body) = $o_mail->splice($o_int);
	my @should 	   = $o_hdr->get('X-Perlbug-Match');
	my @shouldnt   = $o_hdr->get('X-Perlbug-Match-Non');
	my @shouldfail = $o_hdr->get('X-Perlbug-Match-Bad');

	($i_ok, $feedback) = $o_bugmail->check_mail($o_new, $body, \@should, \@shouldnt, \@shouldfail); 
	
	warn "Mail check failure($i_ok): ($feedback)\n" unless $i_ok == 1;

=cut

sub check_mail { # test header lines
	my $self  = shift; # o_perlbug_mail

	my $o_hdr = shift; # Mail::Internet->header object
	my $body  = shift; # Mail::Internet->body string
	my $a_pos = shift; # should have
	my $a_neg = shift; # should not have
	my $a_bad = shift; # should fail

	my %data  = ('pos' => $a_pos, 'neg' => $a_neg, 'bad' => $a_bad);
	my $i_ok  = 1;   
	my $i_err = 0;   
	my $info  = '';
	
	if (ref($o_hdr) && defined($body) && ref($a_pos).ref($a_neg).ref($a_bad) eq 'ARRAYARRAYARRAY') {
		# print "All args OK(o_hdr($o_hdr), body(".length($body)."), a_pos($a_pos), a_neg($a_neg), a_bad($a_bad))\n";
	} else {
		$i_ok = 0;
		$info = "Duff args given to checkit: o_hdr($o_hdr), body(".length($body)."), a_pos($a_pos), a_neg($a_neg), a_bad($a_bad)";
	} 
	if ($i_ok == 1) {
		TYPE:
		foreach my $type (keys %data) {
			next TYPE unless ref($data{$type}) eq 'ARRAY';
			next TYPE unless scalar(@{$data{$type}}) >= 1;
			MATCH:	
			foreach my $elem (@{$data{$type}}) {
				chomp($elem);
				my $err  = 0;
				my @data = ();
				my ($scope, $regex) = ('', '');
				if ($elem =~ /^([\w_-]+)?\:\s*(.+)\s*$/) { # To: regex\@here\.com
					($scope, $regex) = ($1, $2);		# set SCOPE and MATCH
					chomp($scope, $regex);
				} else {
					$err++; 
					$info .= "Check_mail found no scope or regex in element($elem)\n";
				}
				if ($err == 0) {						# set TARGET DATA
					if ($scope eq 'Body') { 
						# push(@data, $body); 
						@data = ($body);
					} elsif (ref($o_hdr) and $o_hdr->can('get')) {	# Mail::Header
						@data = $o_hdr->get($scope);	
					} elsif (ref($o_hdr->{$scope}) eq 'ARRAY') {	# Mail::Send has no access methods
						@data = @{$o_hdr->{$scope}}; 	
					} else {
						$err++;
						$info .= "Check_mail failed to find the data for scope($scope)\n";
					}
					chomp(@data);
				}
				if ($err == 0) {						# DOIT neg, pos, bad
					if ($type eq 'neg') {
						$err++ if grep(/$regex/, @data);
					} elsif ($type eq 'bad') {
						$err++ if grep(/$regex/, @data);
					} elsif ($type eq 'pos') {
						$err++ unless grep(/$regex/, @data);
					} 
					# $err = !$err if $type eq 'bad'; # supposed to find it
					$info .= ($err == 0) ? "OK: " : "NOT OK: ";		
					$info .= "$type = scope($scope), regex($regex), data(@data)\n";
				}
				$i_err++ unless $err == 0;
     		}
		}
	}
	$i_ok = 0 unless $i_err == 0;


	return ($i_ok, "\n$info");
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;

