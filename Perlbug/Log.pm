# Perlbug Logging and file accessor
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Log.pm,v 1.49 2001/03/22 08:33:51 perlbug Exp $
# 
# TODO: 
# 
# debug(0, ...) -> error();
#

=head1 NAME

Perlbug::Log - Module for generic logging/debugging functions to all Perlbug.

=cut

package Perlbug::Log;
use strict;
use vars qw($VERSION);
$VERSION = do { my @r = (q$Revision: 1.49 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1;

use Carp;
use Data::Dumper;
# use Devel::Trace;
use FindBin;
use lib "$FindBin::Bin/..";
use FileHandle;
use Shell qw(chmod);

# $Devel::Trace::TRACE = 0;

my $LOG_COUNTER = 0;
my $FILE_OPEN   = 0;
my $LOG 		= '';
my $FATAL		= 0;
my $VERBOSE     = 0;
my $CARP		= 0;
my $carp		= 0;
my $i_ERRS		= 0;
my $i_MAX		= 1;
$Perlbug::Debug = 0;


=head1 DESCRIPTION

Expected to be called from sub-classes, this needs some more work to cater 
comfortably for non-method calls.

Debug level can be modified via the environment variable: B<Perlbug_Debug> 

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

    my $obj = Perlbug::Log->new('log' => $log, 'tmp => $tmp, 'debug' => 2);

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
    my $o_conf= shift; 
	if (!ref($o_conf)) {
		croak("Log requires Perlbug::Config object($o_conf)!");	
	}
	my $sep = $o_conf->system('separator');
	my $self = bless({
		'_file' 	=> {
			'handle' => '',
			'status' => '',
			'target' => '',
		}
		'_regex'	=> '^(.+)'.$sep.'?([\w_]*)\.(\w+)', 	# ext
	}, $class);

	my $rex = $self->{'_regex'};
	TGT:
    foreach my $tgt ($self->files) {
    	my $target = $o_conf->current("${tgt}_file"); 
		if ($target !~ /$rex$/) { 
	    	croak("Log tgt($tgt) doesn't match($rex) -> target($target)");
     	} else {
			my ($dir, $file) = ($1, $2.'.'.$3);
	    	if (!($dir =~ /\w+/ && -d $dir && -w _)) {
       			croak("Log can't log to $tgt dir($dir): $!");
	    	} else {
				$self->open($tgt, $target);
			}
        }
    }  
	$i_ERRS = 0;
	$i_MAX  = $o_conf->system('max_errors') || $i_MAX;
    $LOG 	= $o_conf->current('log_file');

	$Perlbug::Debug = $ENV{'Perlbug_Debug'} || $o_conf->current('debug') || $Perlbug::Debug;
	$Perlbug::Debug = '01x' if $Perlbug::Debug =~ /^1$/;
	$Perlbug::Debug = '012sX' if $Perlbug::Debug =~ /^2$/;
	$Perlbug::Debug = '0123csSX' if $Perlbug::Debug =~ /^3$/;
	$Perlbug::Debug = '01234cCsSxXtT' if $Perlbug::Debug =~ /^4$/;
	# $Devel::Trace::TRACE = 1 if $Perlbug::Debug =~ /T/;

	$CARP++ if $Perlbug::Debug =~ /C/;
	$carp++ if $Perlbug::Debug =~ /c/;
    $self->set_user($o_conf->system('user')); # ...
	$self->debug(0, "INIT ($$) scr($0), debug($Perlbug::Debug) $self");
    return $self;
}


=item files

Return files based on key (or all)

	my @files = $o_log->files();

=cut

sub files {
	my $self = shift;
	my $pat  = shift || '.+';

	my @files = grep(/^$pat$/, @{$self->{'_files'}});

	return @files;
}


=item handle 

Return handle based on key 

	my $fh = $o_log->handle('log');

=cut

sub handle {
	my $self = shift;
	my $tgt  = shift || 'log';

	my $fh = $self->{'_handle'}{$tgt};

	return $fh;
}


=item DESTROY

Cleanup log and tmp files.

=cut

sub DESTROY {
    my $self = shift;
	foreach my $tgt ($self->files()) {
		undef $self->handle($tgt) if $tgt;
	}
}


=item debug

This is in B<flux> at the moment, please be warned!

Debug method, logs to L</log_file>, with configurable levels of tracking:

Controlled by C<$ENV{'Perlbug_Debug'} || $Perlbug::Debug

	0 = login, object, function (basic)		
	1 = decisions							(sets x) 
	2 = data feedback from within methods 	(sets i, x, X)
	3 = more than you want					(sets C, I, s, S, O, X)

	# a = AUTOLOAD methods
	# c = print to STDOUT as it goes (good for command-line debugging)
	# C = Carp to STDERR as it goes (with caller) 
	m = method names
	M = Method names with package data 
	s = sql statements (num rows affected)
	S = SQL returns values (dump)
	x = execute statements (ignore SELECTs)

	Where a capital letter is given:
		the data is Dumper'd if it's a reference, the result of a sql query, or an object

    $pb->debug("duff usage");                			# undefined second arg (treated as level 0)
    $pb->debug(0, 		"always tracked");        		# debug off
    $pb->debug(1, 		"tracked if $debug =~ /[01]/");	# debug on = decisions
    $pb->debug(2, 		"tracked if $debug =~ /[012]/");# debug on = talkative  

	$pb-, 	"tracked if $debug =~ /[oO]/'); # output from methods 	> data out

	A useful combination for the command line may be to set C<$ENV{'Perlbug_Debug'}> 'cs'

=cut

sub debug { 
    my $self = shift;
    my $flag = shift;
	my $debug = $Perlbug::Debug || '';

    if (!defined($flag)) {
        $self->logg("XXX: debug called with DUFF args($self, $flag, data(@_)");
	} else {
		my $DATA = '';
        if ($flag =~ /^([aAsS0123xX])$/) {
			if (($flag =~ /^(\d)$/i && $debug >= $flag) || ($debug =~ /$flag/)) {
				if ($debug =~ /[mM]/) {
					my @caller = ();
					CALLER:
					foreach my $i (0..4) {
						@caller = caller($i);
						last CALLER if $caller[3] !~ /debug/i;
					}
					my $caller = (($debug =~ /M/) ? "$caller[0]::$caller[3]" : "$caller[3]");
					$caller =~ s/^(?:\w+::)+(\w+)$/$1/; # Perlbug::Base::get_list
					$DATA .= "$caller: "; 
				}
			}
			if ($flag =~ /^(\d)$/i && $debug >= $flag) {
					$DATA .= "@_".(($flag >= 2) ? "<- flag($flag)" : '');
			} elsif ($debug =~ /$flag/) {
					$DATA .= "@_";
			}     
		}
		$self->logg($DATA) if $DATA;
    }
}
 

sub _debug { # quiet
	my $self = shift;
	return $self->logg(@_);
}


=item error

Handles error messages

	print $o_log->error($msg);

=cut

sub error {
	my $self = shift;
	$i_ERRS++;
	my $errs = "Error [$i_ERRS]: ".join(' ', @_)."<br>\n";
	$self->debug(0, $errs);
	carp($errs) if $CARP; 
	confess("Max($i_MAX) errors exceeded: ".$errs) if $i_ERRS >= $i_MAX;
}


=item fatal

Deals with a fatal condition by logging and dieing, traps dies to come out here:

	&do_this or $o_log->fatal($message);

=cut

sub fatal { #
	my $self = shift;
	$self->error(@_);
	confess(@_);
	exit(1); # :-)
}


=item logg

Logs args to log file

	$o_log->logg('Done something');

=cut

sub logg { #
    my $self = shift;
    # warn "Perlbug::Log::logg(@_)" if $Perlbug::Debug =~ /4/;
    my @args = @_;
	unshift(@args, (ref($self)) ? '' : $self); # trim obj and position left side
    my $data = substr("[$LOG_COUNTER] ", 0, 15).join(' ', @args, "\n");  # uninitialised value???
    if (length($data) >= 25600) {
        $data = "Excessive data length(".length($data).") called!\n"; 
    }
	my $fh = $self->fh('log', '+>>', 0766);
	if (defined $fh) {
		flock($fh, 2);
		$fh->seek(0, 2); # just in case it's been moved by someone else
		print $fh $data;
		flock($fh, 8); 
		print $data if $carp;
		carp($data) if $CARP;
	} else {
		carp("logg couldn't log($data) to undefined fh($fh)");
	}
    $LOG_COUNTER++;
}


=item fh

Define and return filehandles, keyed by 3 character string for our own purposes, otherwise the file name sitting in the system('text') dir.

	$o_log->fh($file, '+>>', 0755);

=cut

sub fh { 
    my $self = shift;
    my $arg  = shift;
    my $ctl  = shift || '+>>' || '<'; 
    if ($arg =~ /^[\w_]+$/) {   
        my $FH = $self->{"_${arg}_fh"};               # <-
		if (!((defined($FH)) && (ref($FH)) && ($FH->isa('FileHandle')))) { # OK
        	my $file = $self->{"_${arg}_file"}; 
	    	if ($file !~ /\w+/) { # 
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
                $self->{"_${arg}_fh"} = $fh;          # <-
                $FILE_OPEN++;
            } else {                # not OK
                croak("Log::fh($arg) -> can't define filehandle($fh) for file($file) with ctl($ctl) $!");
            }
        }
    } else {
		return new FileHandle($arg, $ctl);  
    }	 
    return $self->{"_${arg}_fh"}; 
}


=item append 

Storage area (file) for results from queries, returns the FH.

	my $pos = $log->append('res', 'store this stuff'); 
	
	# $pos is position in file

=cut

sub append { 
    my $self = shift;
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
			flock($fh, 2); # lock
	        $fh->seek(0, 2);
	        print $fh $data;
	        $pos = $fh->tell;
			flock($fh, 8); # unlock
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

First we look in site, then we look in docs.

    my $a_data = $log->read('res');

=cut

sub read {
    my $self = shift;
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
    # return "";  # disable
    my ($priority) = ($_[0] =~ /^\d+$/) ? $_[0] : 12;
	$self->debug(2, "priority'ing ($priority)");
	my $pre = getpriority(0, 0);
	setpriority(0, 0, $priority);
	my $post = getpriority(0, 0);
	$self->debug(2, "Priority: pre ($pre), post ($post)");
	return $self;
}


=item set_user

Sets the given user to the runner of this script.

=cut
    
sub set_user {
    my $self = shift; # ignored
    my $user = shift;
    my $oname  = getpwuid($<); 
    my $original = qq|orig($oname, $<, [$(])|;
    my @data = getpwnam($user);
    ($>, $), $<, $() = ($data[2], $data[3], $data[2], $data[3]);
    my $pname  = getpwuid($>); 
    my $post = qq|curr($pname, $<, [$(])|;
	$self->debug(2, "user($user) original($original) post($post)");
	return $self;
}


=item copy

Copy this to there

    $ok = $log->copy($file1, $file2);    
    
    @file1_data = $log->copy($file1, $file2);

=cut

sub copy {
    my $self = shift;
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


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999 2000

=cut

1;
# 

