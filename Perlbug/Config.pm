# Perlbug configuration data
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Config.pm,v 1.40 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Config - Perlbug Configuration data handler

=cut

package Perlbug::Config;
use strict;
use vars(qw($VERSION @ISA $AUTOLOAD));
$VERSION = do { my @r = (q$Revision: 1.40 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Config_DEBUG'} || $Perlbug::Config::DEBUG || '';
$|=1;

use Carp;
use Data::Dumper;
use FileHandle;
use Perlbug; # for DEBUG

my $CONFIG = $ENV{'Perlbug_Config'} = $ENV{'Perlbug_Config'} || $Perlbug::Config || 
	'/home/perlbug/config/Configuration'; # <-- !!! CHANGE THIS !!!


=head1 DESCRIPTION

Configuration data for the Perlbug bug tracking system.

Be sure to set the 'Perlbug_SiteConfig' environment variable to the correct site configuration file, and/or fix the line at the top of this module.

Set methods are provided only for L<current()> parameters, the rest are all gettable only, and settable only from the configuration file.

=head1 SYNOPSIS

	my $o_conf = Perlbug::Config->new;

	my $format = $o_conf->current('format');
	
	my $debug = $o_conf->current('debug');	
	

=head1 METHODS

=over 4

=item new

Create new Config object with all prefs set.

    my $conf = Perlbug::Config->new;

=cut

sub new {
    my $ref 	= shift;
    my $class 	= ref($ref) || $ref;
	my $self = { '_config' => '' };
    bless($self, $class);

    my $h_data = $self->get_config_data($CONFIG);
    $self->{'_config'} = $h_data = $self->update_data($h_data);
    $self->prime_data($h_data);
    $self->set_alarm($h_data);
	croak("suspect Perlbug::Config data: ".Dumper($self->{'_config'})) 
		unless keys %{$self->{'_config'}} >= 7; # ?

	$DEBUG = $Perlbug::DEBUG || $DEBUG;
	return $self;
}


=item get_config_data

Retrieve data from site configuration file

    my ($ok, $h_data) = get_config_data($config_file_location);

=cut

sub get_config_data {
	my $self = shift;
    my $file = shift;

	my $h_data = {};

    if (!(-e $file && -r _)) {
		croak("Can't read file($file) for config data: $!");
	} else {
		$h_data = do $file;
		croak("Duff data($h_data) from file($file)!") unless ref($h_data) eq 'HASH';
	}
	
	return $h_data;
}


=item update_data

Update config data structure for current/local environment

	my ($ok, $h_data) = &update_data(\%data);

=cut

sub update_data (\%) {
	my $self = shift;
	my $prefs = shift;

	if (ref($prefs) ne 'HASH') {
		croak("Duff prefs($prefs) given to update_data");
	} else {
		my $TYPE  = ($0 =~ /\W_{0,1}(?:perl)*bug\.{0,1}(cgi|cron|db|fix|graph|hist|mail|obj|tk|tron)$/)
			? $1 : 'xxx';	

		my $DATE = &get_date;
		my $spooldir = $$prefs{'DIRECTORY'}{'spool'};

		$$prefs{'CURRENT'}{'log_file'} = $spooldir.'/logs/'   .$TYPE.'_'.$DATE.'.log';  # guess :-) 
		$$prefs{'CURRENT'}{'tmp_file'} = $spooldir.'/temp/'   .$TYPE.'_'.$DATE.'_'.$$.'.tmp';    

		$$prefs{'CURRENT'}{'admin'}    =  '';    
		my $current = $ENV{'Perlbug_DEBUG'} || $Perlbug::DEBUG || $$prefs{'CURRENT'}{'debug'};
		$$prefs{'CURRENT'}{'debug'}    = $Perlbug::DEBUG = $ENV{'Perlbug_DEBUG'} = $current;
		$ENV{'PATH'}                   = $$prefs{'SYSTEM'}{'path'};
	}

	return $prefs;
}


=item prime_data

Prime config data structure

    my ($ok, $h_data) = prime_data(\%data);

=cut

sub prime_data (\%) {
	my $self = shift;
    my $data = shift;
	
	foreach my $key (keys %{$data}) {
		my $call = lc($key);
		$call =~ s/^_(\w+)$/$1/;
		$self->$call(); # prime
	}
	
    return $data;
}


=item set_alarm

Sets Perlbug alarm process so we don't go on for ever :-)

=cut

sub set_alarm (\%) {
	my $self = shift;
    my $h_ref = shift; 
    my $set = ($0 =~ /.+?bug(db|fix|obj|tk)$/) # hist? 
		? ($$h_ref{'SYSTEM'}{'timeout_interactive'} || 30)
		: ($$h_ref{'SYSTEM'}{'timeout_auto'} || 13); 	  
    eval { alarm($set) }; 
    $SIG{'ALRM'} = sub { 
        my $title = $$h_ref{'SYSTEM'}{'title'} || 'Perlbug(tron)';
        my $addr  = $$h_ref{'SYSTEM'}{'maintainer'} || 'perlbug@rfi.net';
        my $from  = $$h_ref{'EMAIL'}{'from'} || 'perlbugtron@bugs.perl.org'; 
        my $alert = "$title ($$) timing out($set) (@_) $!";
		carp($alert);
        my $mail = qq|From: $title <$from>
To: "$title maintainer" <$addr>
Subject: $title timing out!

$0 timed out for some reason:
	$alert
	ARGV(@ARGV)
Ciao
|;
        open(SENDMAIL, "|/usr/lib/sendmail -t") or croak("Timeout can't fork a sendmail: $!\n");
        print SENDMAIL $mail;
        close(SENDMAIL) or croak("Timeout sendmail didn't close nicely :-(");      
		print $alert;
        kill('HUP', -$$);
    };
    return 1;
}


=head2 UTILITIES

Certain utility methods are available against the configuration object


=item get_date

Returns common date for use throughout Perlbug.

	my $date = get_date;     # -> 19980815 - 20010728

=cut

sub get_date { 
	my $self = shift;
    my @time  = localtime(time);
    my $year  = $time[5] + 1900; 
    my $month = sprintf('%02d', $time[4] + 1); 
    my $day   = sprintf('%02d', $time[3]);
    return $year.$month.$day;
}


=item get_keys

Return list of Config keys of given key

	my @keys = $o_conf->get_keys('current'); 	# have a look

=cut

sub get_keys {
	my $self = shift;
	my $tgt  = shift;

	my @data = keys %{$self->{'_config'}{uc($tgt)}};
	return @data;
}


=item get_vals

Return list of Config values of given key

	my @vals = $o_conf->get_vals('current'); 	# have a look

=cut

sub get_vals {
    my $self = shift;
	my $tgt  = shift;

	my @data = map { (ref($_) eq 'ARRAY') ? @{$_} : ($_) } values %{$self->{'_config'}{uc($tgt)}};

	return @data;
}


=item get_all

Return mapping of each Config key=val

	print $o_conf->get_all('current'); # -> context=ascii ...

=cut

sub get_all {
    my $self = shift;
	my $tgt  = shift;

	my %conf = %{$self->{'_config'}{uc($tgt)}};

	my @data = map { "$_=$conf{$_}" } keys %conf; 

	return @data;
}


=item get_config

Return textual representation of config data

	print $o_conf->get_config('system');

=cut

sub get_config {
    my $self = shift;
	my $tgt  = shift;

	my @keys = map { lc($_) } keys %{$self->{'_config'}};
	my $ret  = $self->system('title')." $tgt configuration data: \n"; 

	if (!($tgt =~ /\w+/ && grep(/^$tgt$/, @keys))) {
		$ret .= "Unrecognised($tgt) - use one of the following criteria: \n\t@keys\n";
	} else {
		my %conf = %{$self->{'_config'}{uc($tgt)}};
		my ($length) = reverse sort { $a <=> $b } map { length($_) } keys %conf; 
		foreach my $key (keys %conf) {
			$ret .= $key.(' ' x ($length - length($key))).' = '.(
				(ref($conf{$key}) eq 'ARRAY') 
					? join(', ', @{$conf{$key}})
					: $conf{$key}
			)."\n";
		}
	}
	# print "given($tgt) returning($ret)\n";

	return $ret;
}


=head1 ACCESSORS

Accessor methods are provided for the following configuration data structures:

		CURRENT SYSTEM DATABASE DIRECTORY 
		TARGET FORWARD FEEDBACK
		EMAIL WEB
		DEFAULT GROUP SEVERITY STATUS VERSION

Retrieve the value:

	my $user = $o_config->system('user');

	my $target = $o_config->target('generic');

Note that B<current> is the only one available for modification, and 
that it returns keys of succesful updates (note the hashref).

	my $attr = $self->current('format'); 			# get

	my @keys = $self->current();					# get

	my $data = $self->current({'format' => 'h'});	# set $data = 'format'

	my @data = $self->current(						# set @data = qw(format context)
		{'format' => 'a', 'context'	=> 'html'}
	); 	

=cut

sub target {
    my $self = shift;
	my $tgt  = shift || '';
	my @ret  = @{$self->{'_config'}{'FORWARD'}{'generic'}};
    @ret = @{$self->{'_config'}{'TARGET'}{$tgt}} if $self->{'_config'}{'TARGET'}{$tgt};
	return @ret;
}

sub forward {
    my $self = shift;
	my $fwd  = shift || '';
	my @ret  = @{$self->{'_config'}{'FORWARD'}{'generic'}};
    @ret = @{$self->{'_config'}{'FORWARD'}{$fwd}} if $self->{'_config'}{'FORWARD'}{$fwd};
	return @ret;
}

sub AUTOLOAD { # operational
	my $self = shift;
	my $get  = shift;	# get || { set => 'this' }

	my $meth = $AutoLoader::AUTOLOAD = $AUTOLOAD;

    return if $meth =~ /::DESTROY$/; 
	$meth = uc($meth);
    $meth =~ s/^(.*):://;
	my $pkg = ref($self);
	my @ret = ();

	# TARGET FORWARD taken care of above
	my $valid = join('|', qw( 
		CURRENT SYSTEM DATABASE DIRECTORY 
		FEEDBACK EMAIL WEB
		DEFAULT GROUP SEVERITY STATUS VERSION
	));

	if ($meth !~ /^($valid)$/) { # not one of ours :-)
		confess("$pkg->$meth(@_) called with a duff method($AUTOLOAD)!  \nTry: 'perldoc $pkg'");
	} else { 
		no strict 'refs';
		*{$AUTOLOAD} = sub {
			my $self = shift;
			my $get  = shift;	# get || { set => 'this' }
			my @ret = ();

			if (ref($self->{'_config'}{$meth}) ne 'HASH') {
				confess("invalid config($pkg) structure($meth): ".Dumper($self));
			} else {	
				my @keys = @ret = keys %{$self->{'_config'}{$meth}}; 			# all 
				if (defined($get)) {			 					#
					if (ref($get) ne 'HASH') { 						# get ...
						@ret = ($self->{'_config'}{$meth}{$get});	#  
					} else {										# set ...
						if ($meth !~ /^current$/i) { 				# current 
							confess("structure($meth) not settable: ".Dumper($get));
						} else {
							my $keys = join('|', @keys);
							@ret = ();
							SET:
							foreach my $key (keys %{$get}) {
								if ($key !~ /^($keys)$/) {
									confess("unrecognised key($key) in $meth structure($keys)!");
								} else {
									if ($key =~ /^(\w{3})_file$/) { # setting new file?
										undef $self->{'_config'}{$meth}{$1.'_fh'};
									}
									$self->{'_config'}{$meth}{$key} = $$get{$key}; # 
									push(@ret, $$get{$key});		# 
								}
							}
						}
					}
				}
			}
			return wantarray ? @ret : $ret[0];
		}			
    }
	return wantarray ? @ret : $ret[0];
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 1999 2000 2001

=cut

1;

