# Perlbug configuration data
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Config.pm,v 1.23 2000/09/01 11:50:02 perlbug Exp perlbug $
#

=head1 NAME

Perlbug::Config - Perlbug Configuration data handler

=cut

package Perlbug::Config;
# use AutoLoader;
use Carp;
use Data::Dumper;
use FileHandle;
use File::Spec; 
use lib File::Spec->updir;
use vars qw($AUTOLOAD $VERSION);
$VERSION = 1.22;
use strict;
$|=1;

my $CONFIG = $ENV{'Perlbug_Config'} || '/home/perlbug/config/Configuration';


=head1 DESCRIPTION

Configuration data for the Perlbug bug tracking system.

Be sure to set the 'Perlbug_SiteConfig' environment variable to the correct site configuration file, and/or fix the line above.

Set methods are provided only for L<current()> parameters, the rest are all gettable only, and settable from the configuration file.

=head1 SYNOPSIS

	my $o_conf = Perlbug::Config->new;
	
	my $debug = $o_conf->current('debug');				# 0 or as set in Configuration file
	
	my $new_debug = $o_conf->current('debug', 2);		# 2 !

	my @current_data = $o_conf->get_keys('current'); 	# have a look


=head1 METHODS

=over 4

=item new

Create new Config object with all prefs set.

    my $conf = Perlbug::Config->new;

=cut

sub new {
    my $ref 	= shift;
	my $class 	= ref($ref) || $ref;
    my $self 	= undef;
    my ($ok, $prefs) = get_config_data($CONFIG);
    if ($ok == 1) {
		($ok, $prefs) = update_data(\%{$prefs});
		if ($ok == 1) {
			($ok, $self) = check_data(\%{$prefs});
		}
	}
	if (!$ok) {
		croak("suspect Perlbug::Config data: ".Dumper($self));
    }
    bless($self, $class);
}


=item get_config_data

Retrieve data from site configuration file

    my ($ok, $h_data) = get_config_data($config_file_location);

=cut

sub get_config_data ($) {
	my $file = (ref($_[0])) ? $_[1] : $_[0];
	# check \w+ read, ...
    my $fh 		= new FileHandle;
    my %data 	= ();
	my $ok 		= 1;
    if (defined($fh)) {
        if ($fh->open("< $file")) {
			my @data = $fh->getlines;
			foreach my $line (@data) {
				next if $line =~ /^\#/;
				next unless $line =~ /^\w+/; # 
				if ($line =~ /^
					(\w+)				# section 
					\s+
					([\w-]+)			# key
					\s+
					([\<\w_\.\@\=\/\'\"\%-\>]+)	# val
					\s+\#\s*
					(.*)				# comment
				$/x) {	# 3 space separated
	 				my ($sect, $key, $val, $comment) = ($1, $2, $3, $4);
					chomp($comment);
					$val =~ tr/%/ /;
					carp("sect($sect), key($key), val($val), comments($comment)\n");
					$data{uc($sect)}{$key} = $val;
					# $data{uc($sect)}{$key.'_comment'} = $comment; 
				} elsif ($line =~ /\,/) {
					# space? and comma space? separated
					my @bit = my ($sect, $key, $val, $comment) = split(/\s*,\s*/, $line, 4);
					chomp($comment);
					# carp("sect($sect), key($key), val($val), comments($comment)");
					$data{uc($sect)}{$key} = $val;
					# $data{uc($sect)}{$key.'_comment'} = $comment;
				} else {
					# $ok = 0;
					carp("Perlbug::Config found funny looking line ($line)?");	
				}
			}
	        	$fh->close;
			if (keys %data >= 1) { 
				# ok
        	} else {
			$ok = 0;
            		croak("Failed to retrieve config data from open file($file)");
        	}
        } else {
		$ok = 0;
		croak("Can't open file($file) with fh($fh): $!");
		}
    } else {
	$ok = 0;
	croak("Can't get filehandle($fh) for config data file($file)");
	}
	return ($ok, \%data);
}


=item update_data

Update config data structure for current/local environment

	my ($ok, $h_data) = &update_data(\%data);

=cut

sub update_data (\%) {
	my $prefs = shift;
	my $ok = 1;
	my $TYPE    = 'cmd';
	my %TYPE    = ( 'cmd' => 'cmd', 'cgi' => 'www', 'pl' => 'email' );
	if ($0 =~ /\.(pl|cgi)$/) {
    	$TYPE = $TYPE{$1};
	}
	my $DATE = &get_date;
	$$prefs{'CURRENT'}{'log_file'}  =  $TYPE.'_'.$DATE.'.log';  # guess :-) 
    $$prefs{'CURRENT'}{'res_file'}  =  $TYPE.'_'.$DATE.'_'.$$.'.res';   
    $$prefs{'CURRENT'}{'rng_file'}  =  $$.'.rng'; # www only    
    $$prefs{'CURRENT'}{'tmp_file'}  =  $TYPE.'_'.$DATE.'_'.$$.'.tmp';    
    $$prefs{'CURRENT'}{'rc_file'}   =  '.bugdb'; 
	$$prefs{'CURRENT'}{'date'}      =  $DATE;                          
	$$prefs{'CURRENT'}{'admin'}     =  '';    
	#$$prefs{'CURRENT'}{'pwd'}		= $ENV{'PWD'}; 
	#  
	$Perlbug::Debug = $ENV{'Perlbug_Debug'} = $$prefs{'CURRENT'}{'debug'} = 
		$Perlbug::Debug || $ENV{'Perlbug_Debug'} || $$prefs{'CURRENT'}{'debug'};                      
	# 
	(defined($$prefs{'SYSTEM'}{'path'})) && ($ENV{'PATH'} = $$prefs{'SYSTEM'}{'path'});
	if ($$prefs{'CURRENT'}{'debug'} >= 2) {
        # print STDERR Dumper($prefs);
    }
	return ($ok, $prefs);
}


=item check_data

Check config data structure

    my ($ok, $h_data) = check_data(\%data);

=cut

sub check_data (\%) {
    my $data = shift;
    my $ok = 1;
	#
	# placeholder
	#
	# carp("data given: ".Dumper($data));
    # return undef unless ref($data) eq 'HASH';
	# my %data = %{$data};
	#
    # check data structure
    #
    return ($ok, $data);
}


=item get_date

Returns common date for use throughout Perlbug.

	my $date = get_date;     # -> 19980815

=cut

sub get_date { 
    my @time  = localtime(time);
    my $year  = $time[5] + 1900; 
    my $month = sprintf('%02d', $time[4] + 1); 
    my $day   = sprintf('%02d', $time[3]);
    return $year.$month.$day;
}


=item get_keys

Return list of keys of given key, ignoring comment fields.

=cut

sub get_keys {
	my $self = shift;
	my %data = %{$self->{uc($_[0])}};
	my @data = ();
	foreach my $key (keys %data) {
		next if $key =~ /_comment$/;
		push(@data, $key);
	}
	return @data;
	return values %{$self->{uc($_[0])}};
}


=item get_vals

Return list of values of given key, ignoring comment fields.

=cut

sub get_vals {
    my $self = shift;
	my %data = %{$self->{uc($_[0])}};
	my @data = ();
	foreach my $key (keys %data) {
		next if $key =~ /_comment$/;
		push(@data, $data{$key});
	}
	return @data;
	return values %{$self->{uc($_[0])}};
}


=item dump

Returns prefs, via Data::Dumper for debugging, all if no argument given.

Be sure to call it in a list context:

    print $Conf->dump('system');

=cut

sub dump {
    my $self = shift;
    my @prefs = map { $self->{$_[0]} } grep(/uc($_[0])/, keys %{$self});
    return Dumper(\@prefs);
}

sub system {
    my $self = shift;
    return $self->{'SYSTEM'}{$_[0]};
}

sub directory {
    my $self = shift;
    return $self->{'DIRECTORY'}{$_[0]};
}

sub database {
    my $self = shift;
    return $self->{'DATABASE'}{$_[0]};
}


=item current

Current modifiable environment.

Get
    my $debuglevel = $o_obj->current('debug');

Set
    my $incremented = $o_obj->current('debug', $self->current('debug') + 1);

=cut

sub current {
    my $self = shift;
	# print "called current(@_)\n";
    my $args = shift;
    my $val  = shift;
    if (defined($val)) { # can set leer
        # other checks?
        if ($args =~ /^(\w{3})_file$/) { # setting new file?
			undef $self->{'CURRENT'}{$1.'_fh'};
		}
		$self->{'CURRENT'}{$args} = $val;
		# warn "setting current key($args) and val($val): (".$self->{'CURRENT'}{$args}.")";
    } 
	# warn "returning(".$self->{'CURRENT'}{$args}.")\n";
    return $self->{'CURRENT'}{$args};
}

=item methods

Access methods to data, non are directly modifiable, see the Configuration file.

	my $target_address = $o_obj->target('generic');

=cut

sub target {
    my $self = shift;
    return $self->{'TARGET'}{$_[0]} || $self->{'TARGET'}{'generic'};
}

sub forward {
    my $self = shift;
    return $self->{'FORWARD'}{$_[0]} || $self->{'FORWARD'}{'generic'};
}

sub email {
    my $self = shift;
    return $self->{'EMAIL'}{$_[0]};
}

sub web {
    my $self = shift;
    return $self->{'WEB'}{$_[0]};
}

sub default {
    my $self = shift;
    return $self->{'DEFAULT'}{$_[0]};
}

sub category {
    my $self = shift;
    return $self->{'CATEGORY'}{$_[0]};
}

sub osname {
    my $self = shift;
    return $self->{'OSNAME'}{$_[0]};
}

sub severity {
    my $self = shift;
    return $self->{'SEVERITY'}{$_[0]};
}

sub status {
    my $self = shift;
    return $self->{'STATUS'}{$_[0]};
}

sub version {
    my $self = shift;
    return $self->{'VERSION'}{$_[0]};
}

sub _AUTOLOAD { # my $host = $self->database('sqlhost');
    my $self = shift;
    my $meth = $AUTOLOAD;
	$AutoLoader::AUTOLOAD = $AUTOLOAD;
    return if $meth =~ /::DESTROY$/; 
    $meth =~ s/^(.*):://;
    my $key  = shift;
    my @valid = qw(current system database target email web category osname severity status version commands keys vals);
    if (!grep(/$meth/, @valid)) { # not one of ours :-)
        confess "Perlbug::Config->$meth(@_) called with a duff method($AUTOLOAD)!  Try: 'perldoc Perlbug::Config'";
    } 
    my $val = shift;                
    if ((defined $key) && (defined $val)) { # want to change
        if ($meth =~ /^current$/) {         # access control - OK
            $self->{uc($meth)}{$key} = $val;
        } else {							# not OK
            croak "Perlbug::Config->$meth(@_) not allowed to assign val($val) to key($key) ($<, $>)";
        }
    }
    return (defined $key) ? ($self->{uc($meth)}{$key}) : ($self->{uc($meth)});
}

=back


=head1 AUTHOR

Richard Foley perlbug@rfi.net 21.Oct.1999

=cut

1;

__END__
