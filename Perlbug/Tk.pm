# $Id: Tk.pm,v 1.1 2000/06/28 13:51:34 perlbug Exp perlbug $ 

=head1 NAME

Perlbug::Tk - perlTk interface to perlbug database - currently placeholder only.

=cut

package Perlbug::Tk;
use Data::Dumper;
use File::Spec; 
use Getopt::Std;
use lib File::Spec->updir;
use Perlbug::Base;
use Tk;
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

perlTK interface to perlbug database.

=head1 SYNOPSIS

    use Perlbug::Tk;

    my $o_perlbug = Perlbug::Tk->new;    

    my $result = $o_perlbug->cmd; 

    print $result; # == 1 (hopefully :-)


=head1 METHODS

=over 4

=item new

Create new Perlbug::Tk object:

    my $pb = Perlbug::Tk->new();

=cut

sub new {
    my $class = shift;
	my $arg   = shift;
	my $self = Perlbug::Base->new(@_);
	$self->{'attr'}{'history'} = {};
	$self->{'attr'}{'pending_ids'} = [];
	$self->{'attr'}{'pending_type'} = 't'; # t m u 
	$self->{'attr'}{'lines'} = 25; 
	$self->{'history'} = {};
	# $self->{'DATABASE'}{'host'} = $ARG{'h'};
	# $self->{'CURRENT'}{'hst_file'} = my $hist = $self->directory('perlbug').'/.bugdb';
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
	$Perlbug::User = getpwuid($<);
	$self->check_user($Perlbug::User);
	my @data = getpwnam($Perlbug::User);
	my $ok = 1;
	my $prompt = ' > ';
	my $cnt = 1;
	my $help = qq|h = help, quit = quit\n|;
	print qq|
Perlbug Database Cmd Interface ($data[6]):
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
			$in = $in; # ?
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
	return $ok;
}


=item process

Processes the command given, gets and truncates the results, calls scroll

=cut

sub process {
	my $self = shift;
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
	return $i_ok;
}


=item scroll

Scroll the available data if necessary.

=cut

sub scroll {
	my $self = shift;
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
			my $res = <>;
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
	return $i_ok;
}


=item pending

Return the pending ids from a previous query

=cut

sub pending {
	my $self = shift;
	return @{$self->{'pending_ids'}};
}


=item history

History mechanism accessor
`
=cut

sub history {
	my $self = shift;
	my $indx = shift;
	my $cmd  = shift;
	my @hist = (); 
	if ($indx =~ /^\s*\d+\s*$/) {
		if ($cmd =~ /^(.+)$/) {
			$self->{'history'}{$indx} = $cmd;
			# my $ok = $self->append('hst', "$indx $cmd");
			# print "ok($ok)\n";
		}
		@hist = ($self->{'history'}{$indx});
	} elsif ($indx eq 'keys') {
		@hist = keys %{$self->{'history'}};
	} else { # default to values
		@hist = values %{$self->{'history'}};
	} 
	return @hist;
}


=item doh

Wraps help message

=cut

sub doh {
	my $self = shift;
	return $self->SUPER::doh(
		'H' => 'History mechanism - repeats third cmd (!3)',
	);
}


=item doH

History of commands

=cut

sub doH {
	my $self = shift;
	my $i_ok = 1;
	my $history = '';
	my @keys = $self->history('keys');
	foreach my $key (sort { $a <=> $b } @keys) { 
		next unless $key =~ /.+/;
		my ($cmd) = $self->history($key);
		$history .= sprintf('%-6d', $key)."$cmd\n";
	}
	$self->result($history);
	return $i_ok;
}


=item parse_commands

Parses the subject and body of the email message into a command hash, hash 
is placed in $pb->result, returns ref to said hash:

    my $h_ref = $pb->parse_commands($sbj, $bdy);

=cut

sub parse_commands {
    my $self = shift;
    my $sbj  = shift;
    my $bdy  = shift;
    chomp($sbj, $bdy);
	my $ok   = 1;
	my %com = ();
    $self->{'commands'} = {};
	$self->debug(3, "parse_commands($sbj, $bdy)");
    if ($sbj !~ /\w+/) {
		$ok = 0;
		$self->debug(0, "parse_commands requires a subject($sbj)");
    } else {
		my @adminable = $self->get_switches('admin');
		my @cmds = $self->get_switches; # user?
    	my @coms = split '-', $sbj;
		$self->debug(3, "cmds(@cmds)=>coms(@coms)");
		# $DB::single=2;
    	SWITCH: 
    	foreach my $i (@coms) { 
        	next unless $i =~ /\w/;
			my ($com, $mand) = ('', ''); 
        	if ($i =~ /^\s*([@cmds])\s*(.*)$/) { # current
	        	($com, $mand) = ($1, $2);
			} else {
				next SWITCH;
			}
			# -> COM <-
			$mand =~ s/^\s*(.*)$/$1/g;
        	$mand =~ s/^(.*)\s*$/$1/g; 
        	$mand =~ s/[\s\n]+/ /g;
       		$mand =~ s/^(.*?)-+.*$/$1/s;
			# print "i($i) com($com) mand($mand)\n";
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
			if ($com =~ /^[i]$/) {                   		# BODY instructions
				$bdy =~ s/[\s\n]+/ /g;
       			$bdy =~ s/^\s*(.*?)\s*-+.*$/$1/s;
				@mand = ($bdy);
        	} elsif ($com =~ /^[dDhHIlLoOPZ]$/) {     		# MAY have parameter or just flagged.
         		if ($mand =~ /\w/) {
                	@mand = split('\s+', $mand);
            	} else {
                	@mand = (1);
            	}
        	} elsif ($com =~ /^[qQ]$/) {					# MUST have a parameter.
            	@mand = ($mand);
        	} elsif ($com =~ /^[aAbBcCefmprRsStTuxX]$/) {	# MUST have a parameter.
            	@mand = split('\s', $mand);
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
	if ($ok == 1) {
    	$self->{'commands'} = \%com; # ASSIGN
		if ($self->isadmin eq $self->system('bugmaster')) {
        	my $fmtd = $self->format(\%com);      # reference
        	$self->debug(1, "Commands at end of parse_mail: \n$fmtd");
    	}
		if (!(keys %com >= 1)) {
			$self->{'commands'} = undef;
		}
	}
    return $self->{'commands'};      
}


=item process_commands

Steps through hash created by L<parse_mail>, and executes each outstanding 
command, so long as the command has been allowed via L<switches>.
Returns valid == 1 or error message.

    my $outcome = $pb->process_commands($ref_to_hashed_commands);

=cut

sub process_commands { 
    my $self   = shift;
    my $h_cmds = shift;
    $self->debug(2, "process_commands($h_cmds)");
    $self->fatal("No commands($h_cmds) given to process_commands!") unless ref($h_cmds) eq 'HASH';
    my %cmd = %{$h_cmds}; 
	SWTCH:
    foreach my $swtch (keys %cmd) { 
        last SWTCH unless $swtch =~ /^\w$/;
        last SWTCH unless grep(/$swtch/, $self->get_switches);
		if ($self->can("do$swtch")) {
	        $self->do($swtch, $cmd{$swtch}); 
    	    $self->debug(2, "Process ($swtch, $cmd{$swtch}) completed, next...");
    	} else {
    	    $self->debug(0, "Unknown switch ($swtch) next...");
		}
	}
    return 1;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;

