#i_ok $Id: Cmd.pm,v 1.25 2001/04/21 20:48:48 perlbug Exp $ 

=head1 NAME

Perlbug::Interface::Cmd - Command line interface to perlbug database.

=cut

package Perlbug::Interface::Cmd;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.25 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Interface_Cmd_DEBUG'} || $Perlbug::Interface::Cmd::DEBUG || '';
$|=1;

use Data::Dumper;
# use Getopt::Std;
use Perlbug::Base;
@ISA = qw(Perlbug::Base);

my %OPTS = (
    "h" => '', "t" => 0, 'd' => 0, 'p' => '', 'u' => '',
);
# getopts('htdpu:', \%ARG);      


=head1 DESCRIPTION

Command line interface to perlbug database.

=head1 SYNOPSIS

    use Perlbug::Interface::Cmd;

    my $o_perlbug = Perlbug::Interface::Cmd->new;    

    my $result = $o_perlbug->cmd; 

    print $result; # == 1 (hopefully :-)


=head1 METHODS

=over 4

=item new

Create new Perlbug::Interface::Cmd object:

    my $pb = Perlbug::Interface::Cmd->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	# my $arg   = shift;

	my $self = Perlbug::Base->new();
	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	$self->cgi('no_debug');
	$self->check_user($ENV{'LOGNAME'} || $Perlbug::User || 'generic');
	$self->{'attr'}{'history'} = {};
	$self->{'attr'}{'pending_ids'} = [];
	$self->{'attr'}{'pending_type'} = 't'; # t m u 
	$self->{'attr'}{'lines'} = 25; 
	$self->current({'context', 'text'});
	$self->{'_opts'} = \%OPTS;

    bless($self, $class);
}

=item opt

Command line arguments (if any) supplied to script

	print "verbose requested\n" if $o_cmd->opt('v');

=cut

sub opt {
	my $self = shift;
	my $key  = shift || '';

	my @args = ref($self->{'_opts'}{$key}) eq 'ARRAY' ? @{$self->{'_opts'}{$key}} : $self->{'_opts'}{$key};

	return @args;
}


=item cmd

Call the command line interface:
	
	$o_perlbug->cmd; 

=cut

sub cmd {
	my $self = shift;
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
		} elsif ($in =~ /.+/) { 		# COMMAND 
			# $in = $in; 
		} else {						# ZIP
			print "Please input a command: \n$cnt $prompt";
			next READ; 
		}
		$self->history($cnt, $in);
		last READ if $in =~ /^(quit|exit)$/;
		# -------------------------------------------------------------------------------
		# print "cmd: in($in)\n";
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

    # print "cmd: line($line)\n";

	my $h_cmds = $self->parse_commands($line, 'xxx'); # body could be file contents? 
	my @res = ();
	if (ref($h_cmds) ne 'HASH') {
		$res[0] = "Command line($line) parse failure($h_cmds) - try 'h'\n";
	} else {
		# $i_ok = $self->process_commands($h_cmds);
		@res = $self->process_commands($h_cmds);
		# if (@res >= 1) {
		#		$res[0] = "Command($line) process failure($i_ok) - try 'h'\n";
		# } else {
			# @res = $self->get_results;
			if (!((scalar(@res) >= 1) && (length(join('', @res)) >= 1))) {
				$res[0] = "Command($line) failed to produce any results(@res) - try 'h'\n";
			} 
			# $self->truncate('res') || print "failed to truncate res file\n";
		# }
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
	$self->debug(2, "cnt($cnt), scalar($scalar)") if $DEBUG;
	return $i_ok;
}


=item history

History mechanism accessor

=cut

sub history {
	my $self = shift;
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
	return @hist;
}


=item spec

Return specification

=cut

sub spec {
	my $self = shift;
	my ($dynamic) = $self->SUPER::spec; # Base
	my $perldoc = join('', $self->read('spec'));
	return $dynamic.$perldoc;
}


=item doh

Wraps and extends help message

=cut

sub doh {
	my $self = shift;
	my $res = $self->SUPER::doh(
        '!' => 'shell escape - repeat third command			(!3)',     # A
		'H' => 'History listing, use exclamation mark to repeat cmd: (!3)',
		@_,
	);
	return $res;
}


=item doH

History of commands

=cut

sub doH {
	my $self = shift;
	my $history = '';
	my @keys = $self->history('keys');
	foreach my $key (sort { $a <=> $b } @keys) { 
		next unless $key =~ /.+/;
		my ($cmd) = $self->history($key);
		$history .= sprintf('%-6d', $key)."$cmd\n";
	}
	return $history;
}


=item parse_commands

Parses the subject and body of the email message into a command hash, hash 
is placed in $pb->result, returns ref to said hash:

    my $h_ref = $pb->parse_commands($sbj, $bdy);

=cut

sub parse_commands { # migrate -> Do
    my $self = shift;
    my $sbj  = shift;
    my $bdy  = shift;
    chomp($sbj, $bdy);
	my $ok   = 1;
	my %com = ();
    $self->{'attr'}{'commands'} = {};
    if ($sbj !~ /\w+/) {
		$ok = 0;
		$self->error("requires a subject($sbj)");
    } else {
		my @adminable = $self->get_switches('admin');
		my @cmds = $self->get_switches; # user?
    	my @coms = split '-', $sbj;
		$self->debug(3, "cmds(@cmds)=>coms(@coms)") if $DEBUG;
		SWITCH: 
    	foreach my $i (@coms) { 
        	next unless $i =~ /\w|!/;
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
       		$mand =~ s/^(.*?)---+.*$/$1/s; 	# sig ?
			$self->debug(3, "i='$i' -> com($com) and mand($mand)") if $DEBUG;
        	next unless grep(/$com/, @cmds); 			# bit pedantic
        	if ($com =~ /^[@adminable]$/) {       			# CHECK admin status 
            	$self->debug(3, "Status ($com) checking.") if $DEBUG;
            	next SWITCH unless $self->isadmin;      
            	$self->debug(2, "Status ($com) checked (".$self->isadmin.') and approved.') if $DEBUG;      
        	} else {
            	$self->debug(3, "Status ($com) not necessary to check.") if $DEBUG;
        	}
			# -> MAND <-
        	my @mand;
			if ($com =~ /^[wVi]$/) {                   		# BODY instructions 
				@mand = ($bdy);
        	} elsif ($com =~ /^[dDfhHlLoQZz]$/) {     		# MAY have parameter or just flagged.
         		if ($mand =~ /\w/) {
                	@mand = ($mand);
            	} else {
                	@mand = (1);
            	}
        	} elsif ($com =~ /^[!aAbBcCegGIjJmnNpPqrRsStTuvxXy]$/) {	# MUST have a parameter.
            	@mand = ($mand);
        	} else {
            	$self->error("What's this ($com) and how did it get this far?");
        	}
        	$com{$com} = \@mand;
        	# -> ADMIN <-
			if (exists $com{'A'}) {                     	# append tids to $com{'t'}
            	$self->debug(3, "$com{'A'} requesting feedback via -t switch") if $DEBUG;
            	MAND:
            	foreach my $i (@mand) {
                	next MAND unless $self->ok($i);
                	push(@{$com{'t'}}, $i);             
            	}
        	} 
        	$self->debug(3, "com=$com=$com{$com}=@{$com{$com}}") if $DEBUG;
    	}
	}
	$self->{'commands'} = \%com;
    return \%com;      
}


=item process_commands

Steps through hash created by L<parse_commands>, and executes each outstanding 
command, so long as the command has been allowed via L<switches>.
Returns valid == 1 or error message.

    my @outcome = $pb->process_commands($ref_to_hashed_commands);

=cut

sub process_commands { 
    my $self   = shift;
    my $h_cmds = shift;
	my $body = shift || '';
    my @res = ();
    $self->error("No commands($h_cmds) given to process!") unless ref($h_cmds) eq 'HASH';
	$self->debug(2, "processing($h_cmds): ".Dumper($h_cmds)) if $DEBUG;
    my %cmd = %{$h_cmds}; 
	SWTCH:
    foreach my $swtch (keys %cmd) { 
        last SWTCH unless $swtch =~ /^\w$/;
        next SWTCH unless grep(/$swtch/, $self->get_switches);
		if ($self->can("do$swtch")) {
	        push(@res, $self->do($swtch, $cmd{$swtch}, $body)); 
    	    $self->debug(2, "Process ($swtch, $cmd{$swtch}) completed, next...") if $DEBUG;
    	} else {
    	    $self->debug(0, "Unknown switch ($swtch) next...") if $DEBUG;
		}
	}
    return @res;
}


=item scan

Scan for perl relevant data putting found or default switches in $h_data.
Looking for both group=docs and '\brunning\s*under\ssome\s*perl' style markers.

    my $h_data = $o_mail->scan($body);

=cut

sub scan { # bug body 
    my $self    = shift;
    my $body    = shift;

    # my %set     = ();
    my $ok      = 1;
    my $i_cnt   = 0;
	$self->debug(2, "Scanning mail (".length($body).")") if $DEBUG;
    my %flags = $self->all_flags;
	$flags{'category'}=$flags{'group'};
    my %data =  (); 

	my $o_vers = $self->object('version');
	my $vmatch = $o_vers->attr('match_oid');

	# scan($body);

	LINE:
    foreach my $line (split(/\n/, $body)) {         # look at each line for a type match
        $i_cnt++;
		next LINE unless $line =~ /\w+/;
		$self->debug(2, "LINE($line)") if $DEBUG;
		TYPE:
        foreach my $type (keys %flags) {     					# status, group, severity, version...
            $self->debug(2, "Type($type)") if $DEBUG;
			my @matches = $self->get_keys($type);               # SET from config file
            $self->debug(2, "Matches(@matches)") if $DEBUG;
            my @setindb = @{$flags{$type}} if ref($flags{$type}) eq 'ARRAY';
			SETINDB:
			foreach my $indb (@setindb) {                   	# open closed onhold, core docs patch, linux aix...
				next SETINDB unless $indb =~ /\w+/;
				next SETINDB if $type eq 'project' && $indb !~ /^perl\d+$/;
				next SETINDB if $type eq 'version' && $indb !~ /^$vmatch$/;
				if ($line =~ /\b$type=(3d)*$indb\b/i) {			# osname=(3d)*winnt|macos|aix|linux|...
					$data{$type}{$indb}++;
					$self->debug(2, "Bingo: flag($type=$indb)") if $DEBUG;
					next TYPE;
				}
			} 
			MATCH:
			foreach my $match (@matches) {                  	# \bperl|perl\b, success\s*report, et
				next MATCH unless $match =~ /\w+/;
				$self->debug(2, "Match($match)?") if $DEBUG;
				if ($line =~ /$match/i) {                   	# to what do we map?
					if ($type eq 'version') {               	# bodge for version
						$^W = 0;
						my $num = $1.$2.$3.$4.$5;				#
						$^W = 1;
						if ($num =~ /^$vmatch$/) {
							$data{$type}{$num}++;
							my $proj = $num;
							$proj =~ s/^(\d).*/$1/;
							$data{'project'}{"perl$proj"}++;
							$self->debug(1, "Bingo: line($line) version ($num) proj($proj)-> next LINE") if $DEBUG;
							next TYPE;
						}               
					} else { # attempt to set flags based on data found
						next MATCH unless $line =~ /=/;			# short circuit
						my $target = $self->$type($match);  	# open, closed, etc.
						if (grep(/^$target/i, @setindb)) {  	# do we have an assignation?
							$data{$type}{$target}++;
							$self->debug(1, "Bingo: target($target) -> next LINE") if $DEBUG;
							next TYPE;
						}
					}
				}
			}
		}
    }
	#foreach my $key (keys %data) {
	#	$data{$key} = [$self->default_flag($key)] unless ref($data{$key}) eq 'ARRAY'; 
	#}
    my $reg = scalar keys %data;
    $self->debug(2, "Scanned($ok) count($i_cnt), registered($reg): ".$self->dump(\%data)) if $DEBUG;  
    return \%data;
}


=item messageid_recognised  

Returns obj and ids for any given email Message-Id line

	my ($obj, $ids) = $self->messageid_recognised($messageid_line);

=cut

sub messageid_recognised {
	my $self   = shift;
	my $msg_id = shift;

	my $object = '';
	my @ids    = ();
	
	if ($msg_id !~ /(\<.+\>)/) {    # trim it
		$self->debug(0, "No MessageId($msg_id) given to check against");
	} else {
		my $msgid = $1;
		$msgid = $self->quote($1); # escape it
		$msgid =~ s/\'(.+)\'/$1/;  # unquote it
		my $messageid = "%Message-Id: $msgid%"; # with <...> brackets
		$self->debug(3, "looking at messageid($msg_id) -> ($msgid) -> ($messageid)") if $DEBUG;

		OBJ:
		foreach my $obj (grep(!/(parent|child)/i, $self->things('mail'))) {
			next OBJ unless $obj =~ /\w+/;
			my $o_obj = $self->object($obj);
			$self->debug(4, "looking at obj($obj) with $o_obj") if $DEBUG;
			@ids = $o_obj->ids("UPPER(header) LIKE UPPER('$messageid')");
        	if (scalar(@ids) >= 1) {
				$self->debug(2, "MessageId($msgid) belongs to obj($obj) ids(@ids)") if $DEBUG;	
				$object = $obj; # recognised
				last OBJ;
			}
		}				
	}
	return ($object, @ids);
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut

# 
1;

__END__

sub meth { # stub
	my $self = shift;
	my $i_ok = 1;
	# 
	# ...
	# 
	return $i_ok; 	
}
