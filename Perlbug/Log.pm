# Perlbug Logging and file accessor
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Log.pm,v 1.31 2000/08/21 05:32:28 perlbug Exp $
# 

=head1 NAME

Perlbug::Log - Module for generic logging/debugging functions to all Perlbug.

=cut

package Perlbug::Log;
use Carp;
use Data::Dumper;
use FileHandle;
use Shell qw(chmod);
use File::Spec; 
use lib File::Spec->updir;
use strict;
use vars qw($VERSION);
$| = 1;

$VERSION    	= 1.28;
my $LOG_COUNTER = 0;
my $FILE_OPEN   = 0;
my $LOG 		= '';
my $FATAL		= 0;
my $INDENT  	= 0;
my $VERBOSE     = 0;
my $INIT        = '^((?:msi)\\[0\\].+?(INIT)\\s*'."($$))";
$Perlbug::Debug = $Perlbug::Debug || 2;

=head1 DESCRIPTION

Expected to be called from sub-classes, this needs some more work to cater 
comfortably for non-method calls.

=head1 SYNOPSIS

	my $o_log = Perlbug::Log->new('log' => $log, 'res' => $res);
	
	$o_log->append('res', "other data\n");
	
	$o_log->append('log', "some data\n");	
	
	$o_log->append('res', "OK\n");
	
	my $a_data = $o_log->read('res');
	
	print $a_data; # 'other data\nOK\n'


=head1 METHODS

=over 4

=item new

Create new Perlbug::Log object

    my $obj = Perlbug::Log->new('log' => $log, 'res' => $res, 'rng' => $rng, 'debug' => 2);

=cut

sub new {
    my $proto = shift;
	warn "Perlbug::Log::new(@_)" if $Perlbug::Debug >= 4;
    my $class = ref($proto) || $proto; 
    my $self  = { @_ }; 
	my $tgt = '';
    # should open and lock them here, and close them by DESTROY
    foreach $tgt (qw(log res rng tmp)) { # hst
        my $targ = $tgt.'_file';
    	my $target = $self->{$targ}; 
		my $rex = '^(.+)\/([\w_]+)\.(\w+)';
		if ($target =~ /$rex$/) { # only looking for those with an extension!
			my ($dir, $file) = ($1, $2.'.'.$3);
	    	if ($dir =~ /\w+/ && -d $dir && -w _) {
			    # OK
	    	} else {
       			croak("Can't log to $tgt dir($dir): $!");
	    	}
     	} else {
			# print Dumper($self);
	    	croak("Log '$targ' target doesn't look right ($rex) -> '$target'");
        }
    }  
    $LOG = $self->{'log_file'};
	$Perlbug::Debug = $self->{'debug'} || $Perlbug::Debug;
	bless($self, $class);
    $self->set_user($self->{'user'}); # ...
    return $self;
}


=item debug

Debug method, logs to L</log_file>, with different levels of tracking:

    $pb->debug('duff usage');                # undefined second arg (treated as level 0)
    $pb->debug(0, 'always tracked'));        # $Perlbug::Debug >= 0
    $pb->debug(1, 'tracked if debug >= 1');  # key calls 
	$pb->debug(2, 'tracked if debug >= 2');  # key calls plus data
	$pb->debug(3, 'tracked if debug >= 3');  # includes caller info etc.
	
	$pb->debug('in', 'args');    	# in|out 		(2++, (data 4++))
    $pb->debug('out', 'result');    # in|out,		(2++, (data 4++))
	

=cut

sub debug { 
    my $self = shift;
	warn "Perlbug::Log::debug(@_)" if $Perlbug::Debug >= 4;
    my $flag = shift;
    my @data = @_; 
	my @caller = ($Perlbug::Debug >= 1) ? caller(2) : ();  
	# caller(1)(main ../t/20_Log.t 110 Perlbug::Log::read 1 0)     
    if (defined($flag)) {
		# ----------------------------------------------------------------------
		my $pack = $caller[3] || '';
		my $func = $pack; $func =~ s/.+?::([\w_]+)$/$1/; # read
		my $indent = '  ' x $INDENT;		# so we can see it
        if ($flag =~ /^\d+$/) {				# DEBUG
	        if ($Perlbug::Debug >= $flag) { 		
		        if ($Perlbug::Debug >= 4) { 
					$self->logg($indent."$pack: @data"); 
		        } else {
					$self->logg($indent."$func: @data"); 
				}
		    }   									
        } elsif ($flag =~ /^(in|out)/i) { 	# IN|OUT
			--$INDENT if $flag =~ /out/i;
			if ($Perlbug::Debug >= 3) {			# 	
				my $arr = ($flag =~ /in/i) ? '->' : '<-';
				my $inout = ($Perlbug::Debug >= 4) ? "$arr $pack: @data" : "$arr $func";
				$indent = ' ' x $INDENT;
		        $self->logg($indent.$inout);
			} 			
			$INDENT++ if $flag =~ /in/i;
        } else {
			carp "XXX: debug($self, $flag) confused by flag($flag) from -> @caller";
		}         
    	# ----------------------------------------------------------------------
    } else {
        $self->logg( "XXX: debug($self, $flag) called with duff args from -> @caller");
    }
}


sub get_init {
	return $INIT;
}


=item fatal

Deals with a fatal condition by logging and dieing, traps dies to come out here:

	&do_this or $pb->fatal($message);

=cut

sub fatal { 
	my $msg = "Dieing (fatal(@_)\n";
	carp($msg);
	$FATAL++;
	&logg(bless({},'Perlbug::Log'), $msg);
	die($msg);
}


=item logg

Logs args to log file, which is either 'pb_19980822', or pb_backup_log.
Expected to be used via L</debug>.

	&do_this($self, 'x') and $pb->logg('Done that');

=cut

sub logg { #
    my $self = shift;
    warn "Perlbug::Log::logg(@_)" if $Perlbug::Debug >= 4;
    my @args = @_;
	unshift(@args, (ref($self)) ? '' : $self); # trim obj and position left side
    my $data = "[$LOG_COUNTER] ".join(' ', @args);  # uninitialised value???
    if (length($data) >= 25600) {
        # unsupported excessive data tracking
        my @caller = caller(1);
        $data = "Excessive data length(".length($data).") called from: @caller"; 
    }
	# if ($Perlbug::Test::Verbose == 1) { # ?
	#  	print STDOUT "$data\n";
	# } else {
	    my $fh = $self->fh('log', '+>>', 0766);
    	if (defined $fh) {
			flock($fh, 2);
        	$fh->seek(0, 2); # just in case it's been moved by someone else
        	print $fh "$data\n";
			flock($fh, 8); 
    	} else {
        	carp("logg couldn't log($data) to undefined fh($fh)");
    	}
	# }
    $LOG_COUNTER++;
}


=item fh

Define and return filehandles, keyed by 3 character string for our own purposes, otherwise the file name sitting in the system('text') dir.

	$o_log->fh($file, '+>>', 0755);

=cut

sub fh { 
    my $self = shift;
	warn "Perlbug::Log::fh(@_)" if $Perlbug::Debug >= 4;
    my $arg  = shift;
    my $ctl  = shift || '+>>' || '<'; 
    if ($arg =~ /^[\w_]+$/) {   
        my $FH = $self->{$arg.'_fh'};               # <-
		if ((defined($FH)) && (ref($FH)) && ($FH->isa('FileHandle'))) { # OK
	    	#
 		} else {
        	my $file = $self->{$arg.'_file'}; 
	    	if ($file =~ /\w+/) { # OK - used before...
				# 
            } else { # looks like it may be a site-specific file or a fatal log?
	        	my $tgt = ($FATAL >= 1) ? $LOG : $arg;
				if (-e $tgt && -f _) { 	# OK - site spec ?
	       	    	$self->{$arg.'_file'} = $tgt;   
				} else {				# give up
	     	    	croak("Log::fh($arg) can't locate target($tgt) file.");
	        	}
	    	} 
            my $fh = new FileHandle($file, $ctl);
            if (defined $fh) {      # OK
                $fh->autoflush(1);  # 
                $self->{$arg.'_fh'} = $fh;          # <-
                $FILE_OPEN++;
            } else {                # not OK
                croak("Log::fh($arg) -> can't define filehandle($fh) for file($file) with ctl($ctl) $!");
            }
        }
    } else {
		return new FileHandle($arg, $ctl);  
    }	 
	# carp "fh($arg) -> ".$self->{$arg.'_fh'}; # rjsf
    return $self->{$arg.'_fh'}; 
}

sub setresult {
    my $self  = shift;
    $self->debug('IN', @_);
	my $targ = shift || '';
	my $i_ok = 1;
	# $self->truncate('res'); # get results should do this?
	if ($targ =~ /\w+/) { # -> temp?
		$self->debug(0, "setting fh to temp");
	    $self->{'orig_res_fh'} = $self->{'res_fh'};
	    $self->{'orig_res_file'} = $self->{'res_file'};
	    $self->{'res_fh'} = ''; 
		$self->{'res_file'} = $targ; 								# <-
		$self->debug(1, "setting fh for targ($targ)");
	} else { # eq '' -> res
	    $self->debug(0, "reseting fh to results");
	    $self->{'res_fh'} = $self->{'orig_res_fh'};
	    my $targ = $self->{'res_file'} = $self->{'orig_res_file'};	# <-
		$self->debug(1, "resetting fh for results ($targ)");
	} 
	$self->debug('OUT', $i_ok);
	return $i_ok
}


=item append 

Storage area (file) for results from queries, returns the FH.

	my $pos = $log->append('res', 'store this stuff'); 
	
	# $pos is position in file

=cut

sub append { 
    my $self = shift;
	warn "Perlbug::Log::append(@_)" if $Perlbug::Debug >= 4;
    my $file = shift;
    my $data = shift;
    my $perm = shift || '0766';
	my $pos  = '';
	if ($file !~ /^\w{3,4}$/) { # log res rng todo
        $self->debug(0, "Can't append to unrecognised key: '$file'");
   	} else {
	    $self->debug(4, 'result storing '.$data); 
	    my $fh = $self->fh($file, '+>>', $perm);
	    if (defined $fh) {
			flock($fh, 2);
	        $fh->seek(0, 2);
	        print $fh $data;
	        $pos = $fh->tell;
			flock($fh, 8);
	        # unless (chmod(0766, $file)) {
			# 	$self->debug(2, "Can't modify file($file) permissions: $!");
			# }
			$self->debug(3, "Depth into '$file' file ($pos)"); # hint as to stored or not.
	    } else {
	        $self->debug(0, "Didn't get a $file filehandle($fh) to append to. $!");
	    }
    }
    return $pos;
}


=item read

Return the results of the queries from this session.

    my $a_data = $log->read('res');

=cut

sub read {
    my $self = shift;
	warn "Perlbug::Log::read(@_)" if $Perlbug::Debug >= 4;
    my $file = shift;
    my @data = ();      
    if ($file !~ /\w+/) {
        $self->debug(0, "Can't read from '$file'");
    } else {
	    my $fh = $self->fh($file, '<');
		if (defined($fh)) {
	        # $fh->flush;
	        $fh->seek(0, 0);
	        @data = $fh->getlines; 
	    	$self->debug(2, "Read '".@data."' $file lines");
		} else {
	        $self->debug(0, "Unable to open $file file ($fh) for read: $!");
	    }
		if (!scalar @data >= 1) {
			$self->debug(1, "read($file) -> data($#data) looks short!");
		}
    }
	return \@data;
}


=item truncate

Truncate this file

    my $i_ok = $log->truncate('res');

=cut

sub truncate {
    my $self = shift;
	warn "Perlbug::Log::truncate(@_)" if $Perlbug::Debug >= 4;
    my $file = shift;
    my $i_ok = 1;      
    if ($file !~ /^\w+$/) {
		$i_ok = 0;
        $self->debug(0, "Can't truncate '$file'");
    } else {
	    my $fh = $self->fh($file, '+<');
	    if (defined($fh)) {
	        $fh->seek(0, 2);
	        # $fh->flush;
	        $fh->seek(0, 0);
			$fh->truncate(0);
	        $fh->seek(0, 8);
	        $self->debug(2, "Truncated $file");
		} else {
			$i_ok = 0;
	        $self->debug(0, "Unable to truncate file($file): $!");
	    }
    }
	return $i_ok;
}


=item prioritise

Set priority nicer by given integer, or by 12.

=cut

sub prioritise {
    my $self = shift;
	warn "Perlbug::Log::prioritise(@_)" if $Perlbug::Debug >= 4;
    # return "";  # disable
    my ($priority) = ($_[0] =~ /^\d+$/) ? $_[0] : 12;
	$self->debug(2, "priority'ing ($priority)");
	my $pre = getpriority(0, 0);
	setpriority(0, 0, $priority);
	my $post = getpriority(0, 0);
	$self->debug(0, "Priority: pre ($pre), post ($post)");
}


=item set_user

Sets the given user to the runner of this script.

=cut
    
sub set_user {
    my $self = shift; # ignored
	warn "Perlbug::Log::set_user(@_)" if $Perlbug::Debug >= 4;
    my $user = shift;
    my $oname  = getpwuid($<); 
    my $original = qq|orig($oname, $<, [$(])|;
    my @data = getpwnam($user);
    ($>, $), $<, $() = ($data[2], $data[3], $data[2], $data[3]);
    my $pname  = getpwuid($>); 
    my $post = qq|curr($pname, $<, [$(])|;
	$self->debug(0, "INIT ($$) scr($0), debug($Perlbug::Debug):, user($user)"); # -> $original, $post");
}


=item copy

Copy this to there

    $ok = $log->copy($file1, $file2);    
    
    @file1_data = $log->copy($file1, $file2);

=cut

sub copy {
    my $self = shift;
	warn "Perlbug::Log::copy(@_)" if $Perlbug::Debug >= 4;
    my $orig = shift;
    my $targ = shift;
	my $perm = shift || '0766';
    my @data = ();
    my $ok   = 1;
    
    $self->debug(0, "copy called with orig($orig) and target($targ) and perms($perm)");
    
    # FILEHANDLES
    my $oldfh = new FileHandle($orig, '<');
	my $newfh = new FileHandle($targ, '+>', $perm);
	if (!(defined($oldfh)) || (!defined($newfh))) {
	    $ok = 0;
	    $self->debug(0, "Filehandle failures for copy: orig($orig -> '$oldfh'), targ($targ -> '$newfh')");
    }
   
    # TRANSFER DATA
    if ($ok == 1) {
		flock($newfh, 2);
        while (<$oldfh>) {
            # s/\b(p)earl\b/${1}erl/i;
            if (print $newfh $_) {
                push(@data, $_); # see what was copied
            } else {
                $ok = 0;
                $self->debug(0, "can't write to $targ: $!");
                last;
            }
        }
		flock($newfh, 8);
    }
    
    # CLEAN UP
    close($oldfh) if defined $oldfh;
    close($newfh) if defined $newfh;

    # FEEDBACK
    if ($ok == 1) {
        $self->debug(1, "Copy ok($ok)");
    } else {
        $self->debug(0, "Copy($orig, $targ) failed($ok)");
    }
    
    return (wantarray ? @data : $ok);
}


=item link

link this to there

    $ok = $log->link($source, $target, [-f]);    

=cut

sub link {
    my $self = shift;
	warn "Perlbug::Log::link(@_)" if $Perlbug::Debug >= 4;
    my $orig = shift;
    my $targ = shift;
	my $mod  = shift || ''; # -f?
    my $ok   = 1;
    
    $self->debug(0, "link called with orig($orig) and target($targ)");
    
	if ($ok == 1) {	
		if (! -e $orig) {
			$self->debug(0, "Link failure: original($orig) doesn't exist to link from: $!");
		} else {
			my $cmd = "ln $mod -s $orig $targ";
			my $res = system($cmd); 	# doit
			if ($res == 1 || ! -l $targ) {
				$self->debug(0, "Link($cmd) failed($res): $!");
			} else {
				$self->debug(0, "Link($cmd) success");
			}
		} 
	}
    
    # FEEDBACK
    if ($ok == 1) {
        $self->debug(1, "Link ok($ok)");
    } else {
        $self->debug(0, "Link($orig, $targ) failed($ok)");
    }
    
    return $ok;
}


=item create

Create new file with this data:

    $ok = $self->create("$dir/$file.tmp", $data);

=cut

sub create {
    my $self = shift;
	warn "Perlbug::Log::create(@_)" if $Perlbug::Debug >= 4;
    my $file = shift;
    my $data = shift;
	my $perm = shift || '0766';
    my $ok = 1;
    
    # ARGS
    if (($file =~ /\w+/) && ($data =~ /\w+/)) {
        $self->debug(0, "create called with file($file) and data(".length($data).", perm($perm))");
    } else {
        $ok = 0;
        $self->debug(0, "Duff args given to create($file, $data, $perm)");
    }
    
    # OPEN
    if ($ok == 1) {
    	my $fh = new FileHandle($file, '>', $perm);
        if (defined ($fh)) {
			flock($fh, 2);
            print $fh $data;
			flock($fh, 8);
        } else {
            $ok = 0;
            $self->debug(0, "Undefined target filehandle ($fh): $!");
        }
    }
    
    return $ok;
}


=item syntax_check

Check syntax on given file

    $ok = $self->syntax_check("$dir/$file.tmp");

=cut

sub _syntax_check {
    my $self = shift;
	warn "Perlbug::Log::syntax_check(@_)" if $Perlbug::Debug >= 4;
    my $file = shift;
    my $ok = 1;
    
    # ARGS
    if ($file =~ /\w+/) {
        $self->debug(0, "syntax_check called with file($file)");
        if (!-f $file) {
            $ok = 0;
            $self->debug(0, "File ($file) doesn't exist");
        }
    } else {
        $ok = 0;
        $self->debug(0, "Duff args given to syntax_check($file)");
    }
    
    if ($ok == 1) {
        eval { 
            require "$file";
        };
        if ($@) {
            $ok = 0;
            $self->debug(0, "Syntax problem with '$file': $@");
        } else {
            $self->debug(0, "Syntax looks OK for '$file': $@");  
        }
    }
    
    return $ok;
}


=item DESTROY

Cleanup log and result files.

=cut

sub DESTROY {
    my $self = shift;
    my $i_ok = map { undef $self->{"${_}_fh"} } qw(log hst res rng tmp);
}

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999 2000

=cut

1;
# 

