# $Id: Test.pm,v 1.1 2001/09/18 13:37:49 richardf Exp $ 

=head1 NAME

Perlbug::Test- Perlbug testing module

=cut

use Test; # plan, ok, notok

package Perlbug::Test;
$VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 

use Carp;
use Data::Dumper;
use Exporter;
use strict;
use vars qw(@EXPORT @ISA $AUTOLOAD);
@ISA = qw(Exporter);
@EXPORT = qw(output);
$|=1;


=head1 DESCRIPTION

Utility functions for Perlbug test scripts, several wrappers 
for the email side of things...

Output is seen from B<output()> when C<TEST_VERBOSE> is set to B<1>, 
or when the script is being run directly.

Will set mailing to 0, meaning mails will be printed, rather than sent.

Set the current admin to the userid of the local B<bugmaster>.

=head1 SYNOPSIS

	use Perlbug::Base;
	use Perlbug::Test; # calls Test;

	my $o_email = Perlbug::Base->new; 
	my $o_test  = Perlbug::Test->new($o_base);

	plan('todo' => 1); 

	my %header  = ('To' => 'perlbug@perl.org');
	my $o_int   = $o_email->setup_int(\%header, 'mail body perl');

	my ($switch, $msg) = $o_email->parse_mail($o_int);
	if ($switch eq 'B') {
		ok($test);
		output("passed");
	} else {
		notok($test);
		output("failed".Dumper($o_int));
	}

=cut


=head1 METHODS

=over 4

=item new

Create new Perlbug::Test object.

Sets current(isatest=>1, admin=>$bugmaster):

    my $o_test = Perlbug::Test->new();              # generic

	my $o_email_test = Perlbug::Test->new($o_email); # guess :-)

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_arg = shift || '';
	my $self  = {};

	if (!(ref($o_arg) && ($o_arg->isa('Perlbug::Config') || $o_arg->can('conf')))) {
		Perlbug::Config->error(__PACKAGE__."->new($o_arg) requires a configurable object!");
	} else {
		$o_arg->current({'admin'   => $o_arg->system('bugmaster')}); 
		$o_arg->current({'fatal' => 0});
		$o_arg->current({'isatest' => 1});
		my $switches = $o_arg->system('user_switches').$o_arg->system('admin_switches');
		$o_arg->current({'switches'   => $switches});
		my ($INREPLYTO, $INREPLYTOBUGID) = ('', '');
		if ($o_arg->can('get_list')) {
			my $inreplyto = "SELECT max(email_msgid) FROM pb_bug WHERE email_msgid LIKE '%_\@_%'";
			($INREPLYTO)  = $o_arg->get_list($inreplyto);
			my $inreplytobugid = "SELECT bugid FROM pb_bug WHERE email_msgid LIKE '".$o_arg->db->quote($INREPLYTO)."'";
			($INREPLYTOBUGID) = $o_arg->get_list($inreplytobugid);
		}
		my ($MESSAGEID)  = $o_arg->get_rand_msgid if $o_arg->can('get_rand_msgid');

		my $BUGID = '19870502.007';
		$self = {
			'admin'		=> 'richard.foley@rfi.net',
			'base'		=> $o_arg,
			'bugid'     => $BUGID,
			'bugdb'     => 'bugdb@perl.org',
			'domain'    => 'perl.org',
			'DOMAIN'    => 'bugs.perl.org',
			'from'      => 'perlbugtrontest.run@rfi.net',
			'fulladdr'  => '"Perlbugtron" <perlbugtrontest.run@rfi.net>',
			'inreplyto' => $INREPLYTO || '',
			'irep' 		=> $INREPLYTOBUGID || '',
			'isadmin'   => 'perlbug',
			'messageid' => $MESSAGEID || '',
			'ref'       => 'X-Placeholder: perlbug test run',
			'replyto'   => 'perlbugtrontest.run@rfi.net',
			'subject'   => 'some irrelevant subject matter',
			'body'      => qq|some irrelevant body matter\n---\nsig\n|,
		};
	}		

    bless($self, $class);
}


sub xbase {
	my $self = shift;
	return $self->{'base'} || '';
}


=item output

prints given args with newline, warns if $Perlbug::DEBUG set

	output("message"); 

=cut

sub output { 
	my $self = ref($_[0]) ? shift : '';
	$Perlbug::iLOG++;
	print "[$Perlbug::iLOG] @_\n";
	# ($Perlbug::DEBUG !~ /^[\s0]*$/) ? carp "@_" : print "@_\n"; 
}


=item compare
 
Compare two arrays: returns 1 if identical, 0 if not.
 
    my $identical = $o_test->compare(\@arry1, \@arry2);
 
=cut
 
sub compare {
    my $self = shift;   
    my ($first, $second) = @_;
	local $^W = 0;  # silence spurious -w undef complaints
	return 0 unless @$first == @$second;
	for (my $i = 0; $i < @$first; $i++) {
        return 0 if $first->[$i] ne $second->[$i];
	}
	return 1;
}
   

=back


=head1 Utilities

=over 4

Provides mapping for default email content, passes back up to $o_email.

=item target

	my $random_target_address = $o_test->target

=cut

sub target {
	my $self = shift;

	my @target = $self->base->target;

	my $target = $target[rand(@target)];

	return $target;
}


=item forward

	my $random_forward_address = $o_test->forward

=cut

sub forward {
	my $self = shift;

	my @forward = $self->base->forward;

	my $forward = $forward[rand(@forward)];

	return $forward;
}

=back


=head1 AUTOLOAD

Tends to return member variables or, (where this is not supported), 
wraps any unhandlable calls to $o_arg->$meth(), where $o_arg is the 
Perlbug::Interface::Xxx->new object given by B<new()> (see above);

=item bugdb

	my $bugdb = $o_test->email('bugdb');

=item bugid

	my $test_bugid = $o_test->bugid

=item domain

	my $test_domain = $o_test->domain

=item body

	my $test_body = $o_test->body

=item etc.

and so on

=cut


sub AUTOLOAD {
	my $self = shift;

	my $meth = $AutoLoader::AUTOLOAD = $AUTOLOAD;

    return if $meth =~ /::DESTROY$/io; 
    $meth =~ s/^(.*):://o;
	
	return $self->{$meth} || $self->{'base'}->$meth(@_);
}


# ___________________________________
# 
# from here down WILL be redundant...
# ___________________________________
#

=head1 REDUNDANT

=over 4

=item iseven

Return 0(odd) or 1(even) based on last number of given filename

	my $num = iseven($filename);

=cut

sub iseven {
	my $self = shift;
	my $file = shift;
	my $stat = ($file =~ /[02468](\.\w+)*$/o) ? 1 : 0;
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
	my $stat = ($file =~ /[13579](\.[a-zA-Z]+)*$/o) ? 1 : 0;
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
		if (!($tag =~ /\w+/o && $line =~ /\w+/o)) {
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
				if ($elem =~ /^([\w_-]+)?\:\s*(.+)\s*$/o) { # To: regex\@here\.com
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

Richard Foley perlbug@rfi.net 2000 2001

=cut

# 
1;

