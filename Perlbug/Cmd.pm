# $Id: Cmd.pm,v 1.15 2000/08/10 10:47:36 perlbug Exp perlbug $ 

=head1 NAME

Perlbug::Cmd - Command line interface to perlbug database.

=cut

package Perlbug::Cmd;
use Data::Dumper;
# use Getopt::Std;
use File::Spec; 
use lib File::Spec->updir;
use Perlbug::Base;
@ISA = qw(Perlbug::Base);
use strict;
use vars qw($VERSION);
$VERSION = 1.01;
$|=1;

my %ARG = (
    "h" => '', "t" => 0, 'd' => 0, 'p' => '', 'u' => '',
);
# getopts('htdpu:', \%ARG);      


=head1 DESCRIPTION

Command line interface to perlbug database.

=head1 SYNOPSIS

    use Perlbug::Cmd;

    my $o_perlbug = Perlbug::Cmd->new;    

    my $result = $o_perlbug->cmd; 

    print $result; # == 1 (hopefully :-)


=head1 METHODS

=over 4

=item new

Create new Perlbug::Cmd object:

    my $pb = Perlbug::Cmd->new();

=cut

sub new {
    my $class = shift;
	my $arg   = shift;
	my $self = Perlbug::Base->new(@_);
	$self->{'CGI'} = CGI->new('-nodebug');
	$self->check_user($ENV{'LOGNAME'} || $Perlbug::User || 'generic');
	$self->{'attr'}{'history'} = {};
	$self->{'attr'}{'pending_ids'} = [];
	$self->{'attr'}{'pending_type'} = 't'; # t m u 
	$self->{'attr'}{'lines'} = 25; 
	$self->context('a');
	# $self->{'DATABASE'}{'host'} = $ARG{'h'};
	# $self->{'CURRENT'}{'hst_file'} = my $hist = $self->directory('perlbug').'/.$self->system('resource');
	# if ((defined($hist)) && (-e $hist)) {  # reuse it
	# 	my $a_data = $self->read($hist);
	# } else {                                # create it
	# 	$self->create('hst', ''); 
	# }
    bless($self, $class);
}


=item cmd

Call the command line interface:
	
	$o_perlbug->cmd; 

=cut

sub cmd {
	my $self = shift;
	$self->debug('IN', @_);
	$Perlbug::User = getpwuid($<);
	my @data = getpwnam($Perlbug::User);
	my $flag = $self->isadmin ? '*' : '';
	my $ok = 1;
	my $prompt = ' > ';
	my $cnt = 1;
	my $help = qq|h = help, quit = quit\n|;
	print qq|
Perlbug Database Cmd Interface $Perlbug::VERSION ($data[0]$flag -> $data[6]):
------------------------------
$help
1 $prompt|;
	READ:
	while (<>) {
		last READ unless $ok == 1;
		my $in = $_;
		chomp($in);
		if ($in =~ /^\!\s*(\d+)\s*$/) {	# HIST
			my $ref = $1;
			($in) = $self->history($ref);
		} elsif ($in =~ /\w+/) { 		# COMMAND 
			# $in = $in; 
		} else {						# ZIP
			print "Please input a command: \n$cnt $prompt";
			next READ; 
		}
		$self->history($cnt, $in);
		last READ if $in =~ /^(quit|exit)$/;
		# -------------------------------------------------------------------------------
		$ok = $self->process($in);
		print "$cnt $prompt"; 
		$cnt++;
	}
	print "Bye bye!\n";
	$self->debug('OUT', $ok);
	return $ok;
}


=item process

Processes the command given, gets and truncates the results, calls scroll

=cut

sub process {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my $i_ok = 1;
	my $h_cmds = $self->parse_commands($line, ''); # body could be file contents? 
	my @res = ();
	if (ref($h_cmds) ne 'HASH') {
		$res[0] = "Command line($line) parse failure($h_cmds) - try 'h'\n";
	} else {
		$i_ok = $self->process_commands($h_cmds);
		if ($i_ok != 1) {
			$res[0] = "Command($line) process failure($i_ok) - try 'h'\n";
		} else {
			@res = $self->get_results;
			if (!((scalar(@res) >= 1) && (length(join('', @res)) >= 1))) {
				$res[0] = "Command($line) failed to produce any results(@res) - try 'h'\n";
			} 
			$self->truncate('res') || print "failed to truncate res file\n";
		}
	}
	$i_ok = $self->scroll(@res);
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item scroll

Scroll the available data if necessary.

=cut

sub scroll {
	my $self = shift;
	$self->debug('IN', length(@_));
	my @data = @_;
	my $scalar = scalar(@data);
	my $i_ok = 1;
	my $data = join("\n", @data);
	my $cnt = $data =~ tr/\n/\n/;
	if ($cnt != $scalar) {
		# sometimes we get it all in a big string, other times in an array!
		@data = map { "$_\n" } split("\n", $data[0]);
	}
	if (scalar(@data) >= $self->{'attr'}{'lines'}) {
		print "Press ENTER to show $cnt data lines in ".$self->{'attr'}{'lines'}." line chunks, press any other key to cancel:\n";
		DATA:
		while (@data) {
			my $res = <>; # handle ENTER(30)|SPACE(1)
			chomp $res;
			last DATA if $res =~ /.+/;
			my @page = splice(@data, 0, $self->{'attr'}{'lines'});
			print "@page\n";
			last DATA unless @data;
			print scalar(@data)." remaining ...\n";
		}
	} else {
		print "@data\n";
	}
	$self->debug(2, "cnt($cnt), scalar($scalar)");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item history

History mechanism accessor

=cut

sub history {
	my $self = shift;
	$self->debug('IN', @_);
	my $indx = shift;
	my $cmd  = shift;
	my @hist = (); 
	if ($indx =~ /^\s*\d+\s*$/) {
		if ($cmd =~ /^(.+)$/) {
			$self->{'attr'}{'history'}{$indx} = $cmd;
			# my $ok = $self->append('hst', "$indx $cmd");
			# print "ok($ok)\n";
		}
		@hist = ($self->{'attr'}{'history'}{$indx});
	} elsif ($indx eq 'keys') {
		@hist = keys %{$self->{'attr'}{'history'}};
	} else { # default to values
		@hist = values %{$self->{'attr'}{'history'}};
	} 
	$self->debug('OUT', @hist);
	return @hist;
}

sub _notify_cc {
	my $self = shift;
	# $self->debug(1, "Not notifying (@_)... ".$self->isadmin); 
}

=item doh

Wraps help message

=cut

sub doh {
	my $self = shift;
	$self->debug('IN', @_);
	my $res = $self->SUPER::doh(
		'H' => 'History mechanism - repeats third cmd (!3)',
		@_,
	);
	$self->debug('OUT', length($res));
}


=item doH

History of commands

=cut

sub doH {
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	# return $self->result($self->help);
	my $history = '';
	my @keys = $self->history('keys');
	foreach my $key (sort { $a <=> $b } @keys) { 
		next unless $key =~ /.+/;
		my ($cmd) = $self->history($key);
		$history .= sprintf('%-6d', $key)."$cmd\n";
	}
	$self->result($history);
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item parse_commands

Parses the subject and body of the email message into a command hash, hash 
is placed in $pb->result, returns ref to said hash:

    my $h_ref = $pb->parse_commands($sbj, $bdy);

=cut

sub parse_commands { # migrate -> Do
    my $self = shift;
	$self->debug('IN', @_);
    my $sbj  = shift;
    my $bdy  = shift;
    chomp($sbj, $bdy);
	my $ok   = 1;
	my %com = ();
    $self->{'attr'}{'commands'} = {};
    if ($sbj !~ /\w+/) {
		$ok = 0;
		$self->debug(0, "parse_commands requires a subject($sbj)");
    } else {
		my @adminable = $self->get_switches('admin');
		my @cmds = $self->get_switches; # user?
    	my @coms = split '-', $sbj;
		$self->debug(3, "cmds(@cmds)=>coms(@coms)");
		SWITCH: 
    	foreach my $i (@coms) { 
        	next unless $i =~ /\w/;
			my ($com, $mand) = ('', ''); 
        	if ($i =~ /^\s*([@cmds])\s*(.*)$/) { # current
	        	($com, $mand) = ($1, $2);
			} else {
				next SWITCH;
			}
			# -> COM <-						  strip
			$mand =~ s/^\s*(.*)$/$1/g; 		# front
        	$mand =~ s/^(.*)\s*$/$1/g; 		# back
        	$mand =~ s/[\s\n]+/ /g;    		# inbetween
       		$mand =~ s/^(.*?)-+.*$/$1/s; 	# sig ?
			$self->debug(3, "i='$i' -> com($com) and mand($mand)");
        	next unless grep(/$com/, @cmds); 			# bit pedantic
        	if ($com =~ /^[@adminable]$/) {       			# CHECK admin status 
            	$self->debug(3, "Status ($com) checking.");
            	next SWITCH unless $self->isadmin;      
            	$self->debug(2, "Status ($com) checked (".$self->isadmin.') and approved.');      
        	} else {
            	$self->debug(3, "Status ($com) not necessary to check.");
        	}
			# -> MAND <-
        	my @mand;
			# rjsf: should trash this 'body' bit!
			# 		and rationalise parse_commands with scan_header or somesuch
			if ($com =~ /^[wVi]$/) {                   		# BODY instructions 
				# $bdy =~ s/[\s\n]+/ /g;
       			# $bdy =~ s/^\s*(.*?)\s*-+.*$/$1/s;
				@mand = ($bdy);
        	} elsif ($com =~ /^[dDfhHlLoQZ]$/) {     		# MAY have parameter or just flagged.
         		if ($mand =~ /\w/) {
                	# @mand = split('\s+', $mand);
                	@mand = ($mand);
            	} else {
                	@mand = (1);
            	}
        	} elsif ($com =~ /^[q]$/) {						# MUST have a parameter.
            	@mand = ($mand);
        	} elsif ($com =~ /^[aAbBcCeImnNpPrRsStTuvxX]$/) {	# MUST have a parameter.
            	@mand = ($mand);
            	# @mand = split('\s', $mand);
        	} else {
            	$self->debug(0, "What's this ($com) and how did it get this far?");
        	}
        	$com{$com} = \@mand;
        	# -> ADMIN <-
			if (exists $com{'A'}) {                     	# append tids to $com{'t'}
            	$self->debug(3, "$com{'A'} requesting feedback via -t switch");
            	MAND:
            	foreach my $i (@mand) {
                	next MAND unless $self->ok($i);
                	push(@{$com{'t'}}, $i);             
            	}
        	} 
        	$self->debug(3, "com=$com=$com{$com}=@{$com{$com}}");
    	}
	}
	$self->debug('OUT', Dumper(\%com));
	$self->{'commands'} = \%com;
    return \%com;      
}


=item process_commands

Steps through hash created by L<parse_commands>, and executes each outstanding 
command, so long as the command has been allowed via L<switches>.
Returns valid == 1 or error message.

    my $outcome = $pb->process_commands($ref_to_hashed_commands);

=cut

sub process_commands { 
    my $self   = shift;
	$self->debug('IN', @_);
    my $h_cmds = shift;
    my $i_ok = 1;
	$self->debug(2, "process_commands($h_cmds)");
    $self->fatal("No commands($h_cmds) given to process_commands!") unless ref($h_cmds) eq 'HASH';
    my %cmd = %{$h_cmds}; 
	SWTCH:
    foreach my $swtch (keys %cmd) { 
        last SWTCH unless $swtch =~ /^\w$/;
        next SWTCH unless grep(/$swtch/, $self->get_switches);
		if ($self->can("do$swtch")) {
	        $self->do($swtch, $cmd{$swtch}); 
    	    $self->debug(2, "Process ($swtch, $cmd{$swtch}) completed, next...");
    	} else {
    	    $self->debug(0, "Unknown switch ($swtch) next...");
		}
	}
	$self->debug('OUT', $i_ok);
    return $i_ok;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;

__END__

sub meth { # stub
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	# 
	# ...
	# 
	$self->debug('OUT', $i_ok);
	return $i_ok; 	
}
