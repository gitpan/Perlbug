#i_ok $Id: Cmd.pm,v 1.29 2001/09/18 13:37:49 richardf Exp $ 

=head1 NAME

Perlbug::Interface::Cmd - Command line interface to perlbug database.

=cut

package Perlbug::Interface::Cmd;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.29 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
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

	my $self = Perlbug::Base->new(@_);

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
	my $prompt = ' > ';
	my $cnt = 1;
	my $i_total = 0;
	my $help = qq|h = help, quit = quit\n|;
	print qq|
Perlbug Database Cmd Interface $Perlbug::VERSION ($data[0]$flag -> $data[6]):
------------------------------
$help
1 $prompt|;
	READ:
	while (<>) {
		# print "READ cnt($cnt) prompt($prompt) total($i_total)\n";
		chomp(my $in = $_); $in =~ s/^\s*//o;
		if ($in =~ /^\!\s*(\d+)\s*$/o) {# HIST
			($in) = $self->history($1);
		} elsif ($in =~ /.+/o) { 		# COMMAND 
			# print "in($in)\n";
		} else {						# ZIP
			print "Please input a command: \n$cnt $prompt";
			next READ; 
		}
		$self->history($cnt, $in);
		last READ if $in =~ /^(quit|exit)$/io;
		# -------------------------------------------------------------------------------
		$i_total += my $i_num = $self->process($in);
		print "$cnt $prompt"; 
		$cnt++;
	}
	print "Bye bye!\n";
	return $i_total;
}


=item process

Processes the command given, gets and truncates the results, calls scroll

	my @res = $o_cmd->process($line); # internally printed!

=cut

sub process {
	my $self = shift;
	my $line = shift;

	my $h_cmds = $self->parse_input("-$line");
	my @res = ();
	if (ref($h_cmds) ne 'HASH') {
		$res[0] = "Command line($line) parse failure($h_cmds) - try 'h'\n";
	} else {
		@res = $self->process_commands($h_cmds);
		if (!((scalar(@res) >= 1))) { # && (length(join('', @res)) >= 1))) {
			$res[0] = "Command($line) failed to produce any results(@res) - try 'h'\n";
		} 
	}
	@res = $self->scroll(@res);

	return @res;
}


=item input2args

Handles command-line, calls B<SUPER::input2args()>

	my $args = $o_cmd->input2args($cmd, $args);

=cut

sub input2args {
	my $self = shift;
	my $cmd  = shift;
	my $arg  = shift || '';
	
	my $ret = $self->SUPER::input2args($cmd, $arg);

	my $wanted = $self->return_type($cmd);

	if ($wanted eq 'HASH') {
		$$ret{'sourceaddr'} ||= $self->isadmin.'@'.$self->system('hostname');
		if ($cmd eq 'G') {
			($$ret{'name'}) = $1 if ($$ret{'opts'} =~ /^(\w+)/o);
			($$ret{'description'}) = $1 if ($$ret{'body'} =~ /(.+)/mso);
		} elsif ($cmd eq 'U') {
			my @args = split(/\s+/, $arg);	
			$ret = {
				'userid'		=> $args[0],
				'password'		=> $args[1],
				'name'			=> $args[2],
				'address'		=> $args[3],
				'match_address'	=> $args[4],
			};
		}
	}

	return $ret;
}


=item scroll

Scroll the available data if necessary.

=cut

sub scroll {
	my $self  = shift;
	my $i_num = my @data = @_;

	my $i_max = $self->{'attr'}{'lines'} || 35;
	my $compl = join("\n", @data);
	my $i_cnt = ($compl =~ tr/\n/\n/);
	
	if (!($i_cnt > $i_max)) {
		print @data, "\n";
	} else {
		print "Showing $i_cnt data lines in $i_max line chunks\n";
		my $i_chunk = 0;
		CHUNK:
		foreach my $chunk (@data) {
			next CHUNK unless $chunk;
			$i_chunk++;
			my @stuff = map { "$_\n" } split("\n", $chunk);
			print "$i_chunk of ".@data." - press ENTER or any other key to cancel\n";
			DATA:
			while (@stuff) {
				my $res = <>; # handle ENTER(30)|SPACE(1) ?
				chomp $res;
				last CHUNK if $res =~ /.+/o;
				print splice(@stuff, 0, $i_max), "\n";
				last DATA unless @stuff;
				print scalar(@stuff)." lines remaining ...\n";
			}
		}

	}

	$self->debug(2, "items($i_num)") if $Perlbug::DEBUG;

	return @data;
}


=item history

History mechanism accessor

	my @history = $o_cmd->history($i_index, $cmd);

=cut

sub history {
	my $self = shift;
	my $indx = shift;
	my $cmd  = shift || '';
	my @hist = (); 
	if ($indx =~ /^\s*\d+\s*$/o) {
		if ($cmd =~ /^(.+)$/o) {
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
	my $args = shift;
	my @args = (ref($args) eq 'HASH') ? %{$args} : (); 

	my $res = $self->SUPER::doh({
        '!' => 'shell escape - repeat third command			(!3)',     # A
		'H' => 'History listing, use exclamation mark to repeat cmd: (!3)',
		@args
	});

	return $res;
}


=item doH

History of commands

=cut

sub doH {
	my $self = shift;
	my $h_args = shift;

	my $history = '';
	my @keys = $self->history('keys');
	foreach my $key (sort { $a <=> $b } @keys) { 
		next unless $key =~ /.+/o;
		my ($cmd) = $self->history($key);
		$history .= sprintf('%-6d', $key)."$cmd\n";
	}

	return $history;
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
