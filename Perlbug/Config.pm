# Perlbug configuration data
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Config.pm,v 1.51 2001/12/01 15:24:41 richardf Exp $
#

=head1 NAME

Perlbug::Config - Perlbug Configuration data handler

=cut

package Perlbug::Config;
use strict;
use vars(qw($VERSION @ISA $AUTOLOAD));
$VERSION = do { my @r = (q$Revision: 1.51 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
# print map { $_=$ENV{$_} . "\n" } grep(/Perlbug/i, keys %ENV);
$|=1;

# use AutoLoader;
use Carp qw(carp cluck confess);
use Data::Dumper;
use FileHandle;
use Perlbug; 


=head1 DESCRIPTION

Configuration data for the Perlbug bug tracking system.

Be sure to set the 'Perlbug_CONFIG' environment variable to the correct site configuration file, and/or fix the line at the top of this module.

Set methods are provided only for L<current()> parameters, the rest are all gettable only, and settable only from the configuration file.

=head1 SYNOPSIS

	my $o_conf = Perlbug::Config->new($cfgfile);

	my $format = $o_conf->current('format');

	my $debug = $o_conf->current('debug');	


=head1 METHODS

=over 4

=item new

Create new Config object with all prefs set.

    my $conf = Perlbug::Config->new($cfg);

=cut

sub new {
    my $ref 	= shift;
    my $class 	= ref($ref) || $ref;
	my $cfg     = shift || '';

	my $self = { '_config' => '' };
    bless($self, $class);

    my $h_data = $self->get_config_data($cfg);
	$self->{'_config'} = $h_data;
    $h_data = $self->update_data($h_data);
    $self->prime_data($h_data);
	$self->relog if $Perlbug::DEBUG =~ /[dD]/;
    $self->set_alarm($h_data);
	$self->error(0, "suspect Perlbug::Config data: ".Dumper($self->{'_config'})) 
		unless keys %{$self->{'_config'}} >= 16; # ?

	return $self;
}


=item relog

Redirect log output to STDOUT (if $Perlbug_DEBUG =~ /[dD]/

	$o_conf->relog;

=cut

sub relog {
	my $self = shift; 

	no strict 'refs';
	*{'Perlbug::Base::logg'} = sub {
		my $self = shift;
		$Perlbug::i_LOG++;
		return print("[$Perlbug::i_LOG]", @_, "\n");
	}
}


=item error

confess or cluck or carp, dependent on $Perlbug::(DEBUG|FATAL) settings

	my $i_ok = $o_conf->error($err_msg);

=cut

sub error {
	my $self = shift;
	my $err  = shift;
	$err     = 'Error: '.$err."\n";
	my $i_ok = 0;

	# print "Config DEBUG($Perlbug::DEBUG) FATAL($Perlbug::FATAL)\n";
	$self->debug(0, $err) if $self->can('debug'); # if $Perlbug::DEBUG;
	if ($Perlbug::FATAL == 1) {
		# my @res = ($0 =~ /t\/\w+\.t$/) ? print($err) : confess($err);
		confess($err);
	} else {
		my @ignored = ($Perlbug::DEBUG =~ /[23]/o) 
			? cluck($err) 
			: print($err);
	}

	$i_ok;
}


=item get_config_data

Retrieve data from site configuration file

    my ($ok, $h_data) = get_config_data($config_file_location);

=cut

sub get_config_data {
	my $self = shift;
	my $file = (
		defined($ENV{'Perlbug_CONFIG'}) ? $ENV{'Perlbug_CONFIG'} : 
		defined($Perlbug::CONFIG) ? $Perlbug::CONFIG :
		defined($_[0]) ? shift : ''
	); 
	$Perlbug::CONFIG = $ENV{'Perlbug_CONFIG'} = $file;

	my $h_data = {};

    if (!($file =~ /\w+/o && -e $file && -r _)) {
		$self->error("Can't read file($file) for config data: $!");
	} else {
		$h_data = do $file;
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
	my $TYPE  = ($0 =~ /\W_{0,1}(?:perl)*bug\.{0,1}(cgi|cron|db|fix|graph|hist|mail|obj|tk|tron)$/o)
		? $1 : 'xxx';	

	my $DATE = &get_date;
	my $spooldir = $$prefs{'DIRECTORY'}{'spool'};

	$$prefs{'CURRENT'}{'log_file'} = $spooldir.'/logs/'   .$TYPE.'_'.$DATE.'.log';  # guess :-) 
    $$prefs{'CURRENT'}{'tmp_file'} = $spooldir.'/temp/'   .$TYPE.'_'.$DATE.'_'.$$.'.tmp';    

	$$prefs{'CURRENT'}{'admin'}    = '';    
	$ENV{'PATH'} = $$prefs{'SYSTEM'}{'path'};
	# $ENV{'PERL5LIB'} = $$prefs{'DIRECTORY'}{'root'} unless $ENV{'PERL5LIB'};

	$self->set_debug($Perlbug::DEBUG || $$prefs{'CURRENT'}{'debug'});
	$Perlbug::FATAL = $$prefs{'CURRENT'}{'fatal'};
	$prefs = $self->set_env($prefs);

	return $prefs;
}


=item set_debug

Set debug level, returns $o_conf, see L<Perlbug::Base::debug()>;

	my $debug = $o_conf->set_debug(2);

=cut

sub set_debug {
	my $self  = shift;
	my $input = shift;

	# $$prefs{'CURRENT'}{'debug'} = $debug ||= $Perlbug::DEBUG ||= $ENV{'Perlbug_DEBUG'} ||= '';
	my $debug = my $select = (
		defined($input) ? $input : 
		defined($ENV{'Perlbug_DEBUG'}) ? $ENV{'Perlbug_DEBUG'} : 
		defined($Perlbug::DEBUG) ? $Perlbug::DEBUG : ''
	); 

	$debug = '0'            if $debug =~ /^[\s0]*$/o;
	$debug = '01x'          if $debug =~ /^1$/o;
	$debug = '012msx'       if $debug =~ /^2$/o;
	$debug = '0123mMsSxX'   if $debug =~ /^3$/o;

	# print "selected($select) from [input($input), ENV($ENV{'Perlbug_DEBUG'}), DEBUG($Perlbug::DEBUG)] => output($debug)\n";
	$self->current({'debug' => $debug});
	$Perlbug::DEBUG = $ENV{'Perlbug_DEBUG'} = $debug;

	return $Perlbug::DEBUG;
}


=item set_env

Sets ENVIRONMENT and PACKAGE variables in config hash for reference

	my $prefs = $o_conf->set_env($prefs);

=cut

sub set_env {
	my $self  = shift;
	my $prefs = shift;

	foreach my $key (keys %ENV) {
		next unless $key =~ /^Perlbug_\w+$/o;
		$$prefs{'ENV'}{$key} = $ENV{$key};
	}

	no strict 'refs';	
	foreach my $key (keys %{Perlbug::}) {
		next unless $key =~ /^[A-Z]+$/o;
		next if $key =~ /^(BEGIN|EXPORT)/o;
		my $var = "Perlbug::$key";
		$$prefs{'VARS'}{$key} = $$var;
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
    my $set = ($0 =~ /.+?bug(cron|db|fix|hist|obj|tk)$/o) 
		? ($$h_ref{'SYSTEM'}{'timeout_interactive'} || 30)
		: ($$h_ref{'SYSTEM'}{'timeout_auto'} || 13); 	  
    eval { alarm($set) }; 
    $SIG{'ALRM'} = sub { 
        my $title = $$h_ref{'SYSTEM'}{'title'} || 'Perlbug(tron)';
        my $addr  = $$h_ref{'SYSTEM'}{'maintainer'} || 'perlbug@rfi.net';
        my $from  = $$h_ref{'EMAIL'}{'from'} || 'perlbugtron@bugs.perl.org'; 
        my $alert = "$title ($$) timing out($set) (@_) $!";
		$self->error($alert);
        my $mail = qq|From: $title <$from>
To: "$title maintainer" <$addr>
Subject: $title timing out!

$0 timed out for some reason:
	$alert
	ARGV(@ARGV)
Ciao
|;
        open(SENDMAIL, "|/usr/lib/sendmail -t") or $self->error("Timeout can't fork a sendmail: $!\n");
        print SENDMAIL $mail;
        close(SENDMAIL) or $self->error("Timeout sendmail didn't close nicely :-(");      
		print $alert;
        kill('HUP', -$$);
    };
    return 1;
}

=pod

=back

=head2 UTILITIES

Certain utility methods are available against the configuration object

=over 4

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

	my @data = map { $_, $conf{$_} } keys %conf; 

	return @data;
}


=item get_config

Return textual representation of config data

	print $o_conf->get_config('system');

=cut

sub get_config {
    my $self = shift;
	my $tgt  = shift;

	my @keys = sort map { lc($_) } keys %{$self->{'_config'}};
	my $ret  = $self->system('title')." $tgt configuration data: \n"; 

	if (!($tgt =~ /\w+/o && grep(/^$tgt$/, @keys))) {
		$ret .= "Unrecognised($tgt) - use one of the following criteria: \n\t@keys\n";
	} else {
		my %conf = (%{$self->{'_config'}{uc($tgt)}});
		my ($length) = reverse sort { $a <=> $b } map { length($_) } keys %conf; 
		foreach my $key (sort keys %conf) {
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

=pod

=back

=head1 ACCESSORS

Accessor methods are provided for the following configuration data structures:

		CURRENT SYSTEM DATABASE DIRECTORY 
		TARGET FORWARD FEEDBACK
		MESSAGE EMAIL WEB
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

	my @ret  = @{$self->{'_config'}{'TARGET'}{'generic'}};
    @ret     = @{$self->{'_config'}{'TARGET'}{$tgt}} if $self->{'_config'}{'TARGET'}{$tgt};

	return @ret;
}

sub forward {
    my $self = shift;
	my $fwd  = shift || '';

	my @ret  = @{$self->{'_config'}{'FORWARD'}{'generic'}};
    @ret     = @{$self->{'_config'}{'FORWARD'}{$fwd}} if $self->{'_config'}{'FORWARD'}{$fwd};

	return @ret;
}

my $VALID = join('|', qw( 
	CURRENT SYSTEM DATABASE DIRECTORY 
	LINK ENV FEEDBACK MESSAGE EMAIL WEB VARS
	DEFAULT GROUP SEVERITY STATUS VERSION
));

sub AUTOLOAD {
	my $self = shift;
	my $get  = shift;	# get || { set => 'this' }
	my $meth = $AutoLoader::AUTOLOAD = $AUTOLOAD;
    return if $meth =~ /::DESTROY$/o;

	$meth = uc($meth);
    $meth =~ s/^(.*):://o;
	my $pkg = ref($self);
	my @ret = ();

	if ($meth !~ /^($VALID)$/) { # not one of ours :-)
		$self->error("$pkg->$meth(@_) called with a duff method($AUTOLOAD)!  \nTry: 'perldoc $pkg'");
	} else { 
		no strict 'refs';
		*{$AUTOLOAD} = sub {
			my $self = shift;
			my $get  = shift;	# get || { set => 'this' }
			my @ret  = ();

			if (!defined($get)) {
				@ret = keys %{$self->{'_config'}{$meth}};
			} else {
				if (ref($get) ne 'HASH') { 						# get ...
					@ret = ($self->{'_config'}{$meth}{$get});	#  
				} else {										# set ...
					if ($meth !~ /^current$/i) { 				# current 
						$self->error("structure($meth) not settable: ".Dumper($get));
					} else {
						my $keys = join('|', keys %{$self->{'_config'}{"$meth"}}); 	# ref
						SET:
						foreach my $key (keys %{$get}) {
							if ($key !~ /^($keys)$/) {
								$self->error("unrecognised key($key) in $meth structure($keys)!");
							} else {
								if ($key =~ /^(\w{3})_file$/o) { # setting new file?
									undef $self->{'_config'}{$meth}{$1.'_fh'};
								}
								$self->{'_config'}{$meth}{$key} = $$get{$key}; # 
								push(@ret, $$get{$key});		# 
							}
						}
					}
				}
			}

			return wantarray ? @ret : $ret[0];
		}	# autoload
    }
	return wantarray ? @ret : $ret[0];
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 1999 2000 2001

=cut

1;

