# Perlbug Fileging and file accessor
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: File.pm,v 1.5 2001/04/21 20:48:48 perlbug Exp $
# 

=head1 NAME

Perlbug::File - Module for generic file access functions Perlbug.

=cut

package Perlbug::File;
use strict;
use vars qw($VERSION);
$VERSION = do { my @r = (q$Revision: 1.5 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_File_DEBUG'} || $Perlbug::File::DEBUG || '';
$| = 1;

use Carp;
use Data::Dumper;
use FileHandle;
use Shell qw(chmod);



=head1 DESCRIPTION

Simple file access module, handling checking readability, locking and unlocking, etc. transparently for caller


=head1 SYNOPSIS

	my $o_file = Perlbug::File->new('/tmp/abc.xyz', '+>>', '0755');
	
	$o_file->append("data");
	
	my $a_data = $o_file->read();
	
	print $a_data; # 'other data\nOK\n'


=head1 METHODS

=over 4

=item new

Create new Perlbug::File object, requires a filename with optional permissions

    my $o_file = Perlbug::File->new($file, [['+>>'], '0755']);

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
    my $file  = shift || 'undefined_File_name'; 
	my $perm  = shift || '+>>';
	my $num   = shift || '0755';

	my $sep   = quotemeta('/');
	my $self = bless({
		'_handle' => undef,							# GLOB(...)
		'_name'   => '',							# /tmp/here/there.etc
		'_regex'  => '^(.+)('.$sep.')([\w\.])+', 	# ext
		'_status' => '',							# open/locked/closed/...
	}, $class);

	my $rex = $self->{'_regex'};
	if ($file !~ /$rex$/) { 
		$self->error("File($file) doesn't match($rex)");
	} else {
		my ($dir, $tgt) = ($1, $3);
		if (!($dir =~ /\w+/ && -d $dir && -r _)) {
			$self->error("file can't attach to dir($dir) file($tgt): $!");
		} else {
			$self->{'_name'} = $file;
			$self = $self->open($file, $perm, $num); # create or append
		}
	}	

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 
	return $self;
}


=item error

Errors are croaked out, as we probably have a problem with the file in question :-)

	$o_file->error("File is not open") unless $o_file->status eq 'open';

=cut

sub error {
	my $self = shift;
	
	my $dump = Dumper($self);
	croak "@_, \nPerlbug::File::error($dump)\n";

	die(@_);
	exit;
}


=item open

Open the file, returns self

	$o_file = $o_file->open($file, $perm, $num);

=cut

sub open {
    my $self = shift;
	my $file = shift;
	my $perm = shift;
	my $num  = shift;

	my $fh = $self->handle($self->fh($file, $perm, $num));
	if (!$fh) {
		$self->error("no handle returned!");
	} else {
		$self->status('open');
	}

	return $self;
}


=item handle 

Get and set handle

	my $handle = $o_file->handle;

=cut

sub handle {
	my $self   = shift;
	my $handle = shift || $self->{'_handle'};

	$self->error("no handle($handle) found") unless $handle;

	$self->{'_handle'} = $handle;

	return $self->{'_handle'};
}


=item status

Get and set status flag

	my $status = $o_file->status;

=cut

sub status {
	my $self = shift;
	my $status = shift || $self->{'_status'};

	$self->{'_status'} = $status;

	return $self->{'_status'};
}


=item close 

Close the file, returns self

	$o_file = $o_file->close();

=cut

sub close {
    my $self = shift;
	my $fh = $self->handle;

	if ($fh) {
		$fh->flush;
		flock($fh, 8) or $self->error("Can't unlock fh($fh): $!"); # unlock it
		$self->status('unlocked');
		$fh->close() if ref($fh);
		$self->status('closed');
	}

	undef $self->{'_handle'};

	return $self;
}


=item DESTROY

Cleanup open files.

=cut

sub x_DESTROY {
    my $self = shift;
	$self->close() if defined($self) && $self->can('close');
}


=item fh

Create a new filehandle

	my $fh = $o_file->fh($file, '+>>', 0755);

=cut

sub fh { 
    my $self = shift;
    my $file = shift;
    my $ctl  = shift || '+>>' || '<'; 
	my $num  = shift || '';

	my $fh   = undef;

    if ($file !~ /\w+/) {   
		$self->error("inappropriate file($file) given");
    } else {
		$fh = new FileHandle($file, $ctl, $num);
		if (!(defined $fh)) {      # OK
			$self->error("can't define filehandle($fh) for file($file) with ctl($ctl): $!");
        } else {
			# $fh->autoflush(1);  # 
		}
   	} 

    return $fh;
}


=item append 

Append data to file 

	my $o_file = $o_file->append('store this stuff'); 

=cut

sub append { 
    my $self = shift;
    my $data = shift;

	my $fh = $self->handle;
	my $pos  = '';

	if (!defined($fh)) {
		$self->error("can't append to fh($fh)");
	} else {
		flock($fh, 2) or $self->error("Can't lock fh($fh): $!"); # lock it
		$self->status('locked'); 
		$fh->seek(0, 2);
		print $fh $data;
		flock($fh, 8) or $self->error("Can't unlock fh($fh): $!"); # lock it
		$self->status('unlocked'); 
		$pos = $fh->tell;
    }

    return $self;
}


=item read

Return the file contents

    print $o_file->read(); # array from $fh->getlines

=cut

sub read {
    my $self = shift;
	my $fh = $self->handle;
	my @data = ();

	if (!defined($fh)) {
		$self->error("can't read from fh($fh)");
	} else {
		$fh->flush;
		$fh->seek(0, 0);
		@data = $fh->getlines; 
    }
	return @data;
}


=item print 

print the file contents, wrapper for L<read()>

	$o_file = $o_file->print();

=cut

sub print {
    my $self = shift;

	print $self->read();

	return $self;
}


=item truncate

Truncate this file

    my $o_file = $o_file->truncate();

=cut

sub truncate {
    my $self = shift;
	my $fh = $self->handle;

	if (!defined($fh)) {
		$self->error("can't truncate fh($fh)");
	} else {
		$fh->seek(0, 2);
		$fh->seek(0, 0);
		$fh->truncate(0);
		$fh->seek(0, 8);
    }
	return $self;
}


=item copy

Copy this to there

    @file1_data = $o_file->copy($file1, $file2, '0766');

=cut

sub copy {
    my $self = shift;
    my $orig = shift;
    my $targ = shift;
	my $perm = shift || '0766';
    my @data = ();
    
    
    # FILEHANDLES
    # my $oldfh = new FileHandle($orig, '<');
	# my $newfh = new FileHandle($targ, '+>', $perm);
    my $oldfh = $self->fh($orig, '<');
	my $newfh = $self->fh($targ, '+>', $perm);

	if (!(defined($oldfh)) || (!defined($newfh))) {
	    $self->error("Filehandle failures for copy: orig($orig -> '$oldfh'), targ($targ -> '$newfh')");
    } else {
		flock($oldfh, 2);
		flock($newfh, 2);
		LINE:
        while (<$oldfh>) {
            # s/\b(p)earl\b/${1}erl/i;
            if (print $newfh $_) {
                push(@data, $_); # see what was copied
            } else {
                $self->error("can't write to target($targ) fh($newfh): $!");
                last LINE;
            }
        }
		flock($oldfh, 8);
		flock($newfh, 8);
    }
    
    # CLEAN UP
    CORE::close($oldfh) if defined $oldfh;
    CORE::close($newfh) if defined $newfh;

    return @data;
}


=item link

link this to there

    $ok = $o_file->link($source, $target, [-f]);    

=cut

sub link {
    my $self = shift;
    my $orig = shift;
    my $targ = shift;
	my $mod  = shift || ''; # -f?
	my $res  = 0;
    
    
	if (! -e $orig) {
		$self->error("orig($orig) doesn't exist to link to targ($targ) from: $!");
	} else {
		my $cmd = "ln $mod -s $orig $targ";
		$res = system($cmd); 	# doit
		if ($res == 1 || ! -l $targ) {
			$self->error("link($cmd) failed($res): $!");
		} 
	}
    
    return !$res;
}


=item syntax_check

Check syntax on given file

    $ok = $self->syntax_check("$dir/$file.tmp");

=cut

sub _syntax_check {
    my $self = shift;
    my $file = shift;
    my $ok = 0;
    
    # ARGS
    if ($file =~ /\w+/) {
        $self->error("requires a file($file) to syntax check");
	} else {
        if (-f $file) {
			$ok = 1;
		} else {	
            $self->error("File ($file) doesn't exist for syntax check");
        }
    }
    
    if ($ok == 1) {
        eval { 
            require "$file";
        };
        if ($@) {
			$ok = 0;
            $self->error("Syntax problem with '$file': $@");
        }
    }
    
    return $ok;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999 2000 2001

=cut

1;


