# Perlbug Formatterter of tickets, messages, overview, etc.
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Formatter.pm,v 1.4 2001/02/08 15:52:48 perlbug Exp $
#
# TODO: author with note, test, patch, etc.
#       move formats to each Object
# 


=head1 NAME

Perlbug::Formatter - Formats for all interfaces to perlbug database.

Migrating out into Object module.

=cut

package Perlbug::Formatter;
$VERSION = do { my @r = (q$Revision: 1.4 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 

use Carp;
use CGI;
use HTML::Entities;
use Data::Dumper;
use FileHandle;
$|=1;

my $DEBUG   = 2;
my %fmt     = (); # FMT?


=head1 DESCRIPTION

Different formats which can be applied to the data returned from the perlbug database via l<Perlbug> (l<Web>, l<Email> and l<Cmd>) interfaces: B<aAhHl>

If html is required, C<-f h> should be used.  The first letter following the C<-f> switch is the only one used to define which format to use for all results emanating from a single email, C<-f h> being set by default for a web call.

Specific objects supported include: Bugs, Messages, Users, Groups, Patches, Tests and Notes.

Currently this is not relevant for the C<-q> (sql query) switch, as there is little value in attempting to second guess what may be called for in sql statements.  

=head1 SYNOPSIS

	my $o_fmt = Perlbug::Formatter->new;
	
	my %data = (
		'some'	=> 'data',
		'other'	=> 'stuff',
	);
	
	my $str = $o_fmt->fmt(\%data);

	print $str; # 'some=data\nother=stuff\n'


=head1 METHODS

=over 4

=item new

Create new Perlbug::Formatter object:

	my $do = Perlbug::Formatter->new();

=cut

sub new { 
    my $proto = shift;
   	my $class = ref($proto) || $proto; 
   	my $self = {
   	    'user_formats'  => {},
   	    'o_email'       => '',
   	    'o_web'         => '',
		'lengths'		=> {},
		'formats'       => [aAhHlL],
	};
   	bless($self, $class);
}


=item context

Set context ascii or html, sets pre- and post- values

=cut

sub context {
	my $self = shift;
	$self->debug('IN', @_);
	my $arg = shift;
	if (defined($arg) and $arg =~ /^(a|h|l)$/i) {
		$self->debug(1, "setting context($arg)");
		$self->current('format', $arg);
		if ($arg =~ /^[hHL]$/) { # h H L
			$self->{'_line_break'} = "<br>\n";
			$self->{'_pre'}  = '<pre>';
			$self->{'_post'} = '</pre>';
		} else { 			# a A l
			$self->{'_line_break'} = "\n";
			$self->{'_pre'}  = '';
			$self->{'_post'} = '';
		} 
	}
	$self->debug('OUT', $self->current('format'));
	return $self->current('format');
}

=item line_break

Return the current line-break

=cut

sub line_break {
	my $self = shift;
	$self->debug('IN', @_);
	$self->debug('OUT', $self->{'_line_break'});
	return $self->{'_line_break'};
}

=item pre

Return the current pre-setting

=cut

sub pre {
	my $self = shift;
	$self->debug('IN', @_);
	$self->debug('OUT', $self->{'_pre'});
	return $self->{'_pre'};
}

=item pre

Return the current post-setting

=cut

sub post {
	my $self = shift;
	$self->debug('IN', @_);
	$self->debug('OUT', $self->{'_post'});
	return $self->{'_post'};
}


=item fmt

Default printout (of given hash, or anything) - very basic formatter of simple data.
    
    %data = (
        'this' => 'that',
        'here' => [qw(there up down turnaround)],
    );
    
	print $pb->fmt(\%data);

this=that
here=there up down turnaround

=cut

sub fmt { 
    my $self = shift; 
    $self->debug('IN', @_);
    my $input  = shift;
    my $format = shift || $self->current('format') || 'a';
    # return undef unless defined $input;
	my $br = ($format =~ /h/i) ? "<br>\n": "\n";
	# $self->debug(3, "br($br)");
    my $form = '';
	if (ref($input) eq 'HASH') { # only go one deep...
	    my %h = %{$input};
	    foreach my $h (keys %h) {
	        next unless $h =~ /^\w+$/;
	        my $val = (ref($h{$h}) eq 'ARRAY') ? "@{$h{$h}}" : $h{$h} ;
	        $form .= $h.'='.$val.$br;
	    }
	} elsif (ref($input) eq 'ARRAY') {
	    $form = join(' ', @{$input});
	} else {
	    $form = $input.$br;
	}
	$self->debug('OUT', $form);
    return $form;
}


=item _fmt_sql

Formatter sql queries

=cut

sub _fmt_sql { 
    my $self = shift; 
    # $self->debug(3, "Perlbug::Formatter::fmt_sql(@_)");
    my $input  = shift;
    my $format = shift || $self->current('format') || 'a';
    return undef unless defined $input;
	my $br = ($format =~ /h/i) ? "<br>\n": "\n";
	# $self->debug(3, "br($br)");
    my $form = '';
	#  --------------------------------------------------------------------------
	if (ref($input) eq 'HASH') { # only go one deep...
	    my %h = %{$input};
		# ASSIGN
		foreach my $h (keys %h) {
	        next unless $h =~ /^\w+$/;
	        my $key = $h;
			my $val = (ref($h{$h}) eq 'ARRAY') ? "@{$h{$h}}" : $h{$h};
			$form .= $h.'='.$val.$br; # assign
	    }
	} else {
	  #  $form = $input.$br;
	  $self->debug(0, "fmt_sql($input) didn't get a hashref!");
	}
	# --------------------------------------------------------------------------
	# $self->debug(3, "Returning($form)");
    return $form;
}


=item format_data

Formatters this, and writes (via a format) to results file.

If it recognises the object via: bug(id), message(id), patch(id), note(id), user(id) the appropriate formatting is applied.

	my $res = $format->format_data(\%this); 

=cut

sub format_data { 
    my $self = shift;
    $self->debug('IN', @_);
    my $h_ref  = shift;
    return undef unless ref($h_ref) eq 'HASH';
    my $format = shift || $self->current('format') || 'a'; 
	$self->current('format', $format);
	my %tgt = %{$h_ref};
	# redundant mapping info, while new (2.28) database structure
	# could be retained in case of strange mapping of names and unique ids again? 
	my %map = (
		'bugid'		=> 'B', #  "  
		#'flag'      => 'F', # flag 
		'messageid' => 'M', # message
		'groupid'   => 'G', # group
		'noteid'    => 'N', # note
		'patchid'   => 'P', # patch
		'testid'    => 'T', # test
		'userid'    => 'U', # user
	  # 'overview'  => 'O', # -
	  # 'schema'    => 'S', # -
	);
	my $tgt = '';
	my $id  = '';
	MAP:
	foreach my $key (keys %map) {
		if (defined($tgt{$key})) {
			if ($tgt{$key} =~ /\w+/) {
				$id = $tgt{$key};
				$tgt = ucfirst(substr($key, 0, (length($key) - 2))); 
				last MAP;
			}
		}
	}
	# rjsf
	my $object = 'Perlbug::'.$tgt;
	if ($tgt =~ /\w+/) {
		my $o_obj = $object->new($self)->read($id); # overview/schema!!!
		return $o_obj->format($format); 			# html versions 
	} else {
		print "Unrecognised data structure: ".Dumper(\%tgt)."<br>\n";
		return '';
	}
	# rjsf
	# ================================================================= # 
	$self->debug(3, "Formatting($tgt): ref($h_ref) via format($format)");
	my $ok = 1;
	if ($tgt !~ /\w+/) {
		$ok = 0;
		my $err = "Formatter target($tgt) not found for $h_ref: ".Dumper($h_ref);
		$self->debug(0, $err);
		$self->result($err."-> no target data found?");
	} else { 
		if ($format =~ /^[hHL]$/) { # 
			my $targ = $tgt; $targ =~ s/id//gi;
			my $target = "format_${targ}_fields";
			%fmt = %{ $self->$target($h_ref, $format) };
			foreach my $k (keys %fmt) {
				if ($k =~ /msgbody|msgheader|subject/i) {
					$fmt{$k} = encode_entities($fmt{$k});
					$fmt{$k} = $self->pre.$fmt{$k}.$self->post unless $k eq 'subject';
				}
			}
		} else { # ascii
			%fmt = %{ $self->format_fields($h_ref, $format) };
		}
        if ($ok == 1) {
        	my $FORMAT = "FORMAT_$map{${tgt}}_$format"; 
			my $data = $fmt{'msgbody'} || "\n" x 700; # message|patch|note
			my $max = $data =~ tr/\n/\n/;
			$ok = $self->format_this('res', $FORMAT, $max + 500); # big enough?
		}
	}
    $self->debug('OUT', $ok);
	return $ok;
}


=item format_this

Wrapper for calls to filehandle, local data.

    my $res = $obj->format_this('res', "FORMAT_$type_$format", $max);

    # $res = ''

=cut

sub format_this {
    my $self = shift;
    $self->debug(3, "Perlbug::Formatter::format_this(@_)");
    my $format_file = shift;
    my $format_name = shift;
    my $max         = shift;
	my $h_fmt       = shift || ''; # used only for direct calls!
	%fmt = (ref($h_fmt) eq 'HASH') ? %{$h_fmt} : %fmt; 
    $self->_current_target(\%fmt);
	my $ok = 1;
    $max += 128;
    my $fh = $self->fh($format_file);
	if (defined $fh) {
        my $FORMAT = "$format_name";
        $fh->format_name($FORMAT);
        $fh->format_lines_per_page($max);
        $self->debug(3, "FH ($fh) defined, FORMATing ($FORMAT) with ()...");
        eval { write $fh; };
        if ($@) {
            $ok = 0;
            $self->debug(0, "Formatter write failure: $@");
            # carp("format_this($format_file, $format_name, $max) write failure: $@");
        } else {
            my $pos = $fh->tell;
            $ok = ($pos >= 0) ? 1 : 0;
			$self->debug(4, "Formatter write($pos) OK?($ok)"); # hint as to stored or not.
        }
    } else {
        $ok = 0;
        $self->debug(0, "Can't write to undefined fh ($fh) $!");
        carp("format_this($format_file, $format_name, $max) can't write to undefined fh ($fh) $!");
    }
    %fmt = (); # clean out
    return $ok;
}


=item _current_target

Any call which includes L<format_this()>, L<format_data> etc. will automatically set the _current_target to a copy of that data.  This can then be inspected from here.

	print Dumper($obj->_current_target);

=cut

sub _current_target {
	my $self = shift;
	$self->debug('IN', @_);
	my $tgt = shift;
	if (ref($tgt) eq 'HASH') {
		$self->debug(3, "Setting tgt($tgt)");
		%{$self->{'_current_target'}} = %{$tgt}; # copy it
	}
	$self->debug('OUT', $self->{'_current_target'});
	return $self->{'_current_target'};
}


=item start

Sets start header for results.
 
=cut

sub start { 
	return '';
    my $self    = shift;
    my $flag    = shift;
    my $format  = shift || $self->current('format') || 'a';
    $self->debug(3, "Section: $flag");
    my $start = '';
    if ($format eq 'a') {
        $start = "$flag: \n";
    } elsif ($format eq 'A') {
        $start = qq|

 ==============================================================================
 Section: $flag
 ------------------------------------------------------------------------------

|;
    } elsif ($format eq 'h') {
        $start = '<p>'; 
    } elsif ($format eq 'H') {
        $start = '<hr>'; 
    } else {
        $self->debug(0, "Unknown format options: '$format'");
    }
    $self->result($start, 1);
    return '';
}

sub finish {
	my $self = shift;
	return '';
}


=item format_patch_fields

Formatter individual patch entries for placement

    my $h_pat = $o_web->format_patch_fields($h_pat);

=cut

sub format_patch_fields {
    my $self = shift;
    my $h_pat= shift;
	return undef unless ref($h_pat) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my %pat = %{$h_pat};
	
    my $pid = $pat{'patchid'};
    ($pat{'patchid'})  = $self->href('pid', [$pid], $pid, '');
	$pat{'patchid'} =~ s/format\=h/format\=H/gi;
	
	($pat{'headers'}) = $self->href('pheader', [$pid], '(patch headers)');

    $pat{'toaddr'} = qq|<a href="mailto:$pat{'toaddr'}">$pat{'toaddr'}</a>|;
    $pat{'sourceaddr'} = qq|<a href="mailto:$pat{'sourceaddr'}">$pat{'sourceaddr'}</a>|;

	my @bids = (ref($pat{'bugids'}) eq 'ARRAY') ? @{$pat{'bugids'}} : ($pat{'bugids'});
    if (scalar @bids >= 1) {
   	    ($pat{'bugids'}) = join(', ', $self->href('bid', \@bids));
    } else {
 		$pat{'bugids'} = '';
	}
	
	my @cids = $self->get_list("SELECT changeid FROM tm_patch_changeid WHERE patchid='$pid'");	
	$pat{'changeid'} = (scalar(@cids) >= 1) ? join(', ', $self->href('cid', \@cids)) : '';

    if ($self->isadmin && $self->current('format') ne 'L') {
		$pat{'changeid'} 	= $cgi->textfield(-'name' => $pid.'_changeid', -'value' => (@cids), -'size' => 22, -'maxlength' => 55, -'override' => 1);
		$pat{'select'}     	= $cgi->checkbox(-'name'=>'patchids', -'checked' => '', -'value'=> $pid, -'label' => '', -'override' => 1);
	}
	# print '<pre>'.Dumper(\%pat).'</pre>';
	return \%pat;
}


=item format_test_fields

Formatter individual test entries for placement

    my $h_test = $o_web->format_test_fields($h_test);

=cut

sub format_test_fields {
    my $self = shift;
    my $h_test= shift;
	return undef unless ref($h_test) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my %test = %{$h_test};
	
    my $testid = $test{'testid'};
    ($test{'testid'})  = $self->href('tid', [$test{'testid'}], $test{'testid'}, '');
	$test{'testid'} =~ s/format\=h/format\=H/gi;
	
	($test{'headers'}) = $self->href('theader', [$testid], '(test headers)');

    $test{'toaddr'} = qq|<a href="mailto:$test{'toaddr'}">$test{'toaddr'}</a>|;
    $test{'sourceaddr'} = qq|<a href="mailto:$test{'sourceaddr'}">$test{'sourceaddr'}</a>|;
	
	my @bids = (ref($test{'bugids'}) eq 'ARRAY') ? @{$test{'bugids'}} : ($test{'bugids'});
    if (scalar @bids >= 1) {
   	    ($test{'bugids'}) = join(', ', $self->href('bid', \@bids));
    } else {
 		$test{'bugids'} = '';
	}
	
    if ($self->isadmin && $self->current('format') ne 'L') {
		$test{'select'}     = $cgi->checkbox(-'name'=>'tests', -'checked' => '', -'value'=> $testid, -'label' => '', -'override' => 1);
	}
	# print '<pre>'.Dumper(\%test).'</pre>';
	return \%test;
}


=item format_note_fields

Formatter individual note entries for placement

    my $h_msg = $o_web->format_note_fields($h_msg);

=cut

sub format_note_fields {
    my $self = shift;
    my $h_note= shift;
    return undef unless ref($h_note) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my %note = %{$h_note};
	my $nid = $note{'noteid'};

	($note{'headers'}) = $self->href('nheader', [$note{'noteid'}], '(note headers)');

    my @bids = (ref($note{'bugids'}) eq 'ARRAY') ? @{$note{'bugids'}} : ($note{'bugids'});
    if (scalar @bids >= 1) {
   	    ($note{'bugids'}) = join(', ', $self->href('bid', \@bids));
    } else {
 		$note{'bugids'} = '';
	}
	
	# ($note{'bugid'})  = $self->href('bid', [$note{'bugid'}], $note{'bugid'}, '');
	($note{'noteid'}) = $self->href('nid', [$note{'noteid'}]);
    $note{'sourceaddr'} =~ tr/\"/\'/;
	if ($self->isadmin && $self->current('format') ne 'L') {
		$note{'select'} = $cgi->checkbox(-'name'=>'notes', -'checked' => '', -'value'=> $nid, -'label' => '', -'override' => 1);
	}
	
	# print '<pre>'.Dumper(\%note).'</pre>';
    return \%note;
}


=item href

Return list of perlbug.cgi?req=id&... hyperlinks to given list). 

Maintains format, rng etc.

    my @links = $o_web->href('bid', \@bids, 'visible element of link', [subject hint], [\@boldids]);

=cut

sub href {
    my $self    = shift;
    $self->debug('IN', @_);
    my $key     = shift;
    my $a_items = shift;
    my $title   = shift || '';
    my $subject = shift || '';
    return undef unless (ref($a_items) eq 'ARRAY');
    my $cgi = $self->url;
    my @links = ();
 	my $fmt = 'H' || $self->current('format') || 'h'; # ?
	# self->cgi('trim') # ?
    my $trim = (ref($CGI) && $CGI->can('trim') && $CGI->param('trim') =~ /^(\d+)$/) ? $1 : 25;
    ITEM:
	foreach my $val (@{$a_items}) {
		next ITEM unless defined($val) and $val =~ /\w+/;
        my $vis = ($title =~ /\w+/) ? $title : $val;
	    $subject =~ s/'/\\'/g;
		my $status = ($subject =~ /\w+/) ? qq|onMouseOver="status='$subject'"| : '';
		$self->debug(3, "status($status), cgi($cgi), key($key), val($val), format($fmt), trim($trim), status($status), vis($vis)");
		my $link = qq|<a href="$cgi?req=$key&$key=$val&range=$$&format=$fmt"&trim=$trim $status>$vis</a>|;
        $self->debug(4, "link: '$link'");
        push (@links, $link);
    }
	$self->debug('OUT', @links);
	return @links;
    return wantarray ? $links[0] : @links;
}


=item mailto

Return mailto: for a particular ticket

    my $mailto = $o_web->mailto($h_tkt); 

=cut

sub mailto { 
    my $self   = shift;
    my $h_tkt  = shift;    
    $self->debug(3, "mailto($h_tkt)");
    return undef unless ref($h_tkt) eq 'HASH';
    my %tkt = %{$h_tkt};
    my $subject = $tkt{'subject'} || '';
    if ($subject =~ /\w+/) {
        # $subject = "\@subject=$subject"; 
    } 
    # Is this safe enough?
    my $reply = ($tkt{'osname'} =~ /^(\w+)$/) ? $tkt{'osname'} : 'generic'; 
    my $list = $self->forward($reply);
    my $mailto = qq|<a href="mailto:$list">reply</a>|;
    return $mailto;
}


=item popup

Returns appropriate (cached) popup with optional default value inserted.

    my $popup = $web->popup('status', $unique_id, $default);

	$self->debug(3, "Admin ($1) of bug ($id) called.");
	$tkt{'category'}   = $self->popup('category', 	$tkt{'category'}, $id.'_category');
	$tkt{'osname'}     = $self->popup('osname', 	$id.'_osname',    $tkt{'osname'});
	$tkt{'select'}     = $cgi->checkbox(-'name'=>'bugid', -'checked' => '', -'value'=> $id);
	$tkt{'severity'}   = $self->popup('severity', 	$id.'_severity',   $tkt{'severity'});
	$tkt{'status'}     = $self->popup('status', 	$id.'_status',     $tkt{'status'});

=cut

sub popup {
    my $self 	= shift;
    my $flag 	= shift;
	my $uqid	= shift;
	my $default = shift || '';
	my $onchange= shift || '';
	my $ok 		= 1;
    $self->debug(3, "popup: typeofflag($flag), uniqueid($uqid), default($default)");
	if (($flag !~ /^\w+$/) || ($uqid !~ /\w+/)) {
		$ok = 0;
		$self->debug(0, "popup($flag, $uqid, [$default]) given invalid args!");
	}
	my $cgi   = $self->{'CGI'};
	my %flags = $self->all_flags;
	my @flags = keys %flags;
    if (!grep(/^$flag$/, @flags)) {
		$ok = 0;
		$self->debug(0, "popup-flag($flag) not found amongst available flag types: '@flags'");
    }
    my $popup = '';
	if ($ok == 1) {
		$self->{'popup'}{$flag} = ''; # for now
		my @options = ('', sort($self->flags($flag)));
		$popup = $cgi->popup_menu( -'name' => $uqid, -'values' => \@options, -'default' => $default);
        # $self->debug(3, "Generated popup ($popup)");
    	$self->{'popup'}{$flag} = $popup;   # store the current version (without name, and without selection
	}
    return $self->{'popup'}{$flag};     # return it
}


# FORMATS: a, A, h, H, l, L 
# -----------------------------------------------------------------------------
# 

=item FORMAT_B_l

Lean ascii format for tickets:

=cut

format FORMAT_B_l_TOP =
@<<<<<<
$fmt{'_pre'}   
BugID          Status       Severity     Category     Osname     Fixed     Msgs
@<<<<<<
$fmt{'_post'}
.


format FORMAT_B_l =  
@<<<<<<
$fmt{'_pre'}                                   
@<<<<<<<<<<<<< @<<<<<<<<<<< @<<<<<<<<<<< @<<<<<<<<<<< @<<<<<<<<< @<<<<<<<< @<<<<
$fmt{'bugid'}, $fmt{'status'}, $fmt{'severity'}, $fmt{'category'}, $fmt{'osname'}, $fmt{'fixed'}, $fmt{'i_mids'}
@<<<<<<
$fmt{'_post'}
.

format FORMAT_B_a_TOP =
.

format FORMAT_B_a =
@<<<<<<
$fmt{'_pre'} 
------------------------------------------------------------------------------- 
Subject:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'subject'}                          
BugID  :    @<<<<<<<<<<<<<<<                            Status:    @<<<<<<<<<<< 
			$fmt{'bugid'},                                         $fmt{'status'}
Created:    @<<<<<<<<<<<<<<<<<<<<                       Category:  @<<<<<<<<<<<   
            $fmt{'created'},                                       $fmt{'category'}
Version:    @<<<<<<<<<<<<<<<<<<<<                       Severity:  @<<<<<<<<<<<                  
            $fmt{'version'},                                     $fmt{'severity'}
Fixed in:   @<<<<<<<<<<<<<<<<<<<<                       Os:        @<<<<<<<<<<<
            $fmt{'fixed'},                                         $fmt{'osname'}
Patch Ids:  @<<<<<<<<<<<                                
            $fmt{'patches'}                                        
Admins:     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<     
            $fmt{'admins'},                                                   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'admins'}   
Sourceaddr: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'sourceaddr'}                                           
MessageIDs: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messages'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messages'}   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messages'}    
NoteIDs:    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'notes'}    
PatchIDs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'patches'}    
ChangeIDs:  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'changes'}    
TestIDs:    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'tests'}  
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_B_A

Default ASCII format for bugs:

...

=cut

format FORMAT_B_A_TOP =
.

format FORMAT_B_A =
------------------------------------------------------------------------------- 
@<<<<<<
$fmt{'_pre'} 
------------------------------------------------------------------------------- 
Subject:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'subject'}                          
BugID  :    @<<<<<<<<<<<<<<<                            Status:    @<<<<<<<<<<< 
			$fmt{'bugid'},                                         $fmt{'status'}
Created:    @<<<<<<<<<<<<<<<<<<<<                       Category:  @<<<<<<<<<<<   
            $fmt{'created'},                                       $fmt{'category'}
Version:    @<<<<<<<<<<<<<<<<<<<<                       Severity:  @<<<<<<<<<<<                  
            $fmt{'version'},                                     $fmt{'severity'}
Fixed in:   @<<<<<<<<<<<<<<<<<<<<                       Os:        @<<<<<<<<<<<
            $fmt{'fixed'},                                         $fmt{'osname'}
Patch Ids:  @<<<<<<<<<<<                                
            $fmt{'patches'} 
Admins:     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'admins'}   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'admins'}   
ParentIDs: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'parents'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'parents'}   
ChildrenIDs: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'children'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'parents'}    
MessageIDs: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messages'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messages'}   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messages'}  
Ccs:        ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'ccs'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'ccs'}     
NotesIDs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'notes'}  
PatchIDs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'patches'}   
ChangeIDs:  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'changes'}   
TestIDs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'tests'} 
Messagebody:
@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.

=item FORMAT_B_L

Lean html format for tickets:

=cut

format FORMAT_B_L_TOP =
<tr>
<td>BugID</td><td>Status</td><td>Severity</td><td>Category</td><td>Osname</td><td>Fixed</td><td>PatchIDs</td><td>ChangeIds</td><td>TestIds</td><td>NoteIDs</td>
</tr>
.


format FORMAT_B_L =  
<tr><td>
@*
$fmt{'bugid'}
&nbsp;</td><td>
@*
$fmt{'status'}
&nbsp;</td><td>
@*
$fmt{'severity'}
&nbsp;</td><td>
@*
$fmt{'category'}
&nbsp;</td><td>
@*
$fmt{'osname'}
&nbsp;</td><td>
@*
$fmt{'fixed'}
&nbsp;</td><td>
@*
$fmt{'patches'}
&nbsp;</td><td>
@*
$fmt{'changes'}
&nbsp;</td><td>
@*
$fmt{'tests'}
&nbsp;</td><td>
@*
$fmt{'notes'}
&nbsp;</td>
</tr>
.


=item FORMAT_B_h

Html minimal format:
...

=cut

format FORMAT_B_h_TOP =
<tr>
<td>&nbsp;</td>
<td><b>BugID  </b></td>
<td><b>Version</b></td>
<td><b>Status</b></td>
<td><b>Category</b></td>
<td><b>Severity</b></td>
<td><b>OS</b></td>
<td><b>Subject</b></td>
<td><b>Patches</b></td>
<td><b>Changes</b></td>
<td><b>Tests</b></td>
<td><b>Notes</b></td>
<td><b>Fixed in</b></td>
</tr>
.


format FORMAT_B_h =
<tr><td colspan=2 width=70>&nbsp;
@*
$fmt{'select'}
&nbsp;
@*
$fmt{'bugid'}
@*
$fmt{'history'}
</td><td>&nbsp;
@*
$fmt{'version'}
</td><td>&nbsp;
@*
$fmt{'status'}
</td><td>&nbsp;
@*
$fmt{'category'}
</td><td>&nbsp;
@*
$fmt{'severity'}
</td><td>&nbsp;
@*
$fmt{'osname'}
</td><td>&nbsp;
@*
$fmt{'subject'}
</td><td>&nbsp;
@*
$fmt{'patches'}
</td><td>&nbsp;
@*
$fmt{'changes'}
</td><td>&nbsp;
@*
$fmt{'tests'}
</td><td>&nbsp;
@*
$fmt{'notes'}
</td><td>&nbsp;
@*
$fmt{'fixed'}
</td>
</tr>

.

# <tr><td colspan=16><hr></td></tr>


=item FORMAT_B_H

Html, tabled in block format:
...

=cut

format FORMAT_B_H_TOP =
<p>
.


format FORMAT_B_H =
<table border=1 width=100%><tr>
<td><b>BugID</b></td><td><b>Version</b></td><td><b>Created</b></td><td><b>Fixed In</b></td>
</tr>
<tr><td> 
@*
$fmt{'select'}
&nbsp;
@*
$fmt{'bugid'}
@*
$fmt{'history'}
&nbsp;
</td><td>
@*
$fmt{'version'}
&nbsp;</td><td>
@*
$fmt{'created'}
&nbsp;</td><td>
@*
$fmt{'fixed'}
&nbsp;</td></tr>
<tr><td><b>Status:</b><br>
@*
$fmt{'status'};
&nbsp;</td><td><b>Category:</b><br>
@*
$fmt{'category'}
&nbsp;</td><td><b>Severity:</b><br>
@*
$fmt{'severity'}
&nbsp;</td><td><b>OS:</b><br>
@*
$fmt{'osname'};
&nbsp;</td></tr>
<tr><td><b>Sourceaddr:</b></td><td colspan=3>
@*
$fmt{'sourceaddr'}
&nbsp;<td></tr>
<tr><td><b>Subject:</b></td><td colspan=3>
@*
$fmt{'subject'}
&nbsp;</td></tr>
<tr><td><b>Administrators:</b></td><td colspan=3>
@*
$fmt{'admins'}
&nbsp;</td></tr>
<tr><td><b>Parent IDs:</b></td><td>
@*
$fmt{'parents'}
&nbsp;</td><td><b>Child IDs:</b></td><td>
@*
$fmt{'children'}
&nbsp;</td></tr>
<tr><td><b>Message IDs:</b></td><td colspan=3>
@*
$fmt{'messages'}
&nbsp;</td></tr>
<tr><td><b>Ccs:</b></td><td colspan=3>
@*
$fmt{'ccs'}
&nbsp;</td></tr>
<tr>
<td><b>Note Ids:</b><br>
@*
$fmt{'notes'}
&nbsp;</td>
<td><b>Patch IDs:</b><br>
@*
$fmt{'patches'}
&nbsp;</td>
<td><b>Change IDs:</b><br>
@*
$fmt{'changes'}
&nbsp;</td>
<td><b>Test Ids:</b><br>
@*
$fmt{'tests'}
&nbsp;</td>
</tr>
<tr><td colspan=4>
@*
$fmt{'newstuff'}
&nbsp;</td></tr>
</table>
<table border=1 width=100%><tr><td colspan=4>
@*
$fmt{'msgbody'}
&nbsp;</td></tr>
<tr><td colspan=4>
@*
$fmt{'buttons'}
</td></tr></table>
<br>
.


=item FORMAT_M_A

Messages block ASCII format.

=cut

format FORMAT_M_A_TOP =

.

format FORMAT_M_A =
@<<<<<<
$fmt{'_pre'}
MessageID   BugID     
-------------------------------------------------------------------------------
@<<<<<<<<<  @<<<<<<<<<<<<<    
$fmt{'messageid'}, $fmt{'bugids'} 

@*
$fmt{'msgheader'}

@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_M_h

Messages in list html format.

=cut

format FORMAT_M_h_TOP =
<p>
.

format FORMAT_M_h =
<table border=1 width=100%>
<tr><td width=25%><b>Messageid</b></td><td><b>Bug ID</b></td><td><b>Source address</b></td><td><b>Created</b></td></tr>
<tr><td>
@*
$fmt{'messageid'}
&nbsp;
@*
$fmt{'headers'}
</td><td>     
@*
$fmt{'bugids'}
</td><td>
@*
$fmt{'sourceaddr'}
</td><td>
@*
$fmt{'created'}
</td></tr></table>
<table border=1 width=100%><tr><td colspan=4><b>Messagebody:</b></td></tr><tr><td colspan=4>
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_M_H

Messages in block html format. 

=cut

format FORMAT_M_H_TOP =
<p>
.

format FORMAT_M_H =
<table border=1 width=100%>
<tr><td width=25%><b>Messageid</b></td><td><b>Bug ID</b></td><td><b>Created</b></td></tr>
<tr><td>
@*
$fmt{'messageid'}
&nbsp;
@*
$fmt{'headers'}
</td><td>     
@*
$fmt{'bugids'}
</td><td>
@<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'created'}
</td></tr><tr><td><b>Source address:</b></td><td colspan=4>
@*
$fmt{'sourceaddr'}
</td></tr></table>
<table border=1 width=100%>
<tr><td colspan=4><b>Messagebody:</b></td></tr><tr><td colspan=4>
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_U_l

User list format.

=cut

format FORMAT_U_l_TOP =
@<<<<<<
$fmt{'_pre'}
Name                          Active UserID       Bugs       
@<<<<<<
$fmt{'_post'}
.

format FORMAT_U_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<  @<<<<<<<<<<  @<<<<<<<<
$fmt{'name'}, $fmt{'active'}, $fmt{'userid'}, $fmt{'bugs'} 
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_U_a

User ascii format.

=cut

format FORMAT_U_a_TOP =
Name                          Active UserID       Bugs      
.

format FORMAT_U_a =
-------------------------------------------------------------------------------
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<  @<<<<<<<<<<  @<<<<<<<< 
$fmt{'name'}, $fmt{'active'}, $fmt{'userid'}, $fmt{'bugs'}
Address:       @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'address'} 
Match_address: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'match_address'}
Groups:        @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'groups'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_U_A

User ASCII format.

=cut

format FORMAT_U_A_TOP =
Name                          Active UserID       Bugs      
.

format FORMAT_U_A =
-------------------------------------------------------------------------------
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<  @<<<<<<<<<<  @<<<<<<<< 
$fmt{'name'}, $fmt{'active'}, $fmt{'userid'}, $fmt{'i_bug_ids'}
Address:       @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'address'} 
Match_address: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'match_address'}
Groups:	
~~	^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'group_names'}
Bugids:
~~	^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'bug_ids'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_U_h

User in list html format.

=cut

format FORMAT_U_h_TOP =
</table><table><tr><td colspan=8 width=100%><hr></td></tr>
<tr><td width=35><b>Name</b></td><td width=15><b>Active?</b></td><td><b>Bugs</b></td><td><b>Address</b></td><td><b>Password</b></td><td><b>Match Address</b></td><td><b>Groups</b></td></tr>
.


format FORMAT_U_h =
<tr><td colspan=8><hr></td></tr>
<tr><td>
@*
$fmt{'select'}
&nbsp;
@*
$fmt{'name'}
</td><td>
@*
$fmt{'active'}
</td><td>
@*
$fmt{'bugs'}
&nbsp;</td><td>
@*
$fmt{'address'}
&nbsp;</td><td>
@*
$fmt{'password_update'}
@*
$fmt{'password'}
&nbsp;</td><td>
@*
$fmt{'match_address'}
&nbsp;</td><td>
@*
$fmt{'groups'}
&nbsp;</td></tr>
.


=item FORMAT_H_l

History list format.

=cut

format FORMAT_H_l_TOP =
@<<<<<<
$fmt{'_pre'}
LogID   Admin         Type ObjectId        Event
@<<<<<<
$fmt{'_post'}
.

format FORMAT_H_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<  @<<<<<<<<<<<  @<   @<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
$fmt{'logid'}, $fmt{'userid'}, $fmt{'objecttype'}, $fmt{'objectid'}, $fmt{'event'} 
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_H_a

History list format.

=cut

format FORMAT_H_a_TOP =
LogID   Admin         Type ObjectId        Event
.

format FORMAT_H_a =
-------------------------------------------------------------------------------
@<<<<<<
$fmt{'_pre'}
@<<<<<  @<<<<<<<<<<<  @<   @<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
$fmt{'logid'}, $fmt{'userid'}, $fmt{'objecttype'}, $fmt{'objectid'}, $fmt{'event'} 
@*
$fmt{'event'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_H_h

History in list html format.

=cut

format FORMAT_H_h_TOP =
<tr><td colspan=8 width=100%><hr></td></tr>
<tr><td width=35><b>Logid</b></td><td width=15><b>Admin</b></td><td><b>Type</b></td><td><b>ObjectId</b></td><td><b>Event</b></td></tr>
.


format FORMAT_H_h =
<tr><td colspan=8><hr></td></tr>
<tr><td>
@*
$fmt{'logid'}
&nbsp;
@*
$fmt{'userid'}
</td><td>
@*
$fmt{'objecttype'}
</td><td>
@*
$fmt{'objectid'}
&nbsp;</td><td>
@*
$fmt{'event'}
&nbsp;</td></tr>
.


=item FORMAT_N_l

Note lean format.

=cut

format FORMAT_N_l_TOP =
@<<<<<<
$fmt{'_pre'}
NoteID      Created         BugID                 
@<<<<<<
$fmt{'_post'}
.

format FORMAT_N_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<  @<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<   
$fmt{'noteid'}, $fmt{'created'}, $fmt{'bugids'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_N_a

Note list format.

=cut

format FORMAT_N_a_TOP =

.

format FORMAT_N_a =
@<<<<<<
$fmt{'_pre'}
NoteID      Created         BugID                 
-------------------------------------------------------------------------------
@<<<<<<<<<  @<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<   
$fmt{'noteid'}, $fmt{'created'}, $fmt{'bugids'}

@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.

# Message body suppressed (try 'M' or 'T')


=item FORMAT_N_A

Note block ASCII format.

=cut

format FORMAT_N_A_TOP =

.

format FORMAT_N_A =
@<<<<<<
$fmt{'_pre'}
NoteID      Created         BugID     
-------------------------------------------------------------------------------
@<<<<<<<<<  @<<<<<<<<<<<<<  @<<<<<<<<<<  
$fmt{'noteid'}, $fmt{'created'}, $fmt{'bugids'} 

@*
$fmt{'msgheader'}

@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_N_h

Note in list html format.

=cut

format FORMAT_N_h_TOP =
<p>
.

format FORMAT_N_h =
<table border=1 width=100%>
<tr><td width=25%><b>Note ID</b></td><td><b>Bug ID</b></td><td><b>Created</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'noteid'}
@*
$fmt{'headers'}
</td><td> &nbsp;    
@*
$fmt{'bugids'}
</td><td>&nbsp;
@*
$fmt{'created'}
</td></tr><tr><tr><td colspan=3>
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_N_H

Note in block html format. 

=cut

format FORMAT_N_H_TOP =
<p>
.

format FORMAT_N_H =
<table border=1 width=100%>
<tr><td width=25%><b>Note ID</b></td><td><b>Bug ID</b></td><td><b>Created</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'noteid'}
</td><td>&nbsp;
@*
$fmt{'bugids'}
</td><td>&nbsp;
@<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'created'}
</td></tr><tr><td colspan=4>
&nbsp;
@*
$fmt{'msgheader'}
</td>
<tr><td colspan=4>
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_P_l

Patch lean format.

=cut

format FORMAT_P_l_TOP =
@<<<<<<
$fmt{'_pre'}
PatchID      BugIDs                                ChangeID       Version   
@<<<<<<
$fmt{'_post'}    
.

format FORMAT_P_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  @<<<<<<<<<<<<
$fmt{'patchid'}, $fmt{'bugids'}, $fmt{'changeid'}, $fmt{'fixed'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_P_a

Patch list format.

=cut

format FORMAT_P_a_TOP =

.

format FORMAT_P_a =
@<<<<<<
$fmt{'_pre'}
PatchID      BugIDs                                ChangeID       Version                
-------------------------------------------------------------------------------
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  @<<<<<<<<<<<<
$fmt{'patchid'}, $fmt{'bugids'}, $fmt{'changeid'}, $fmt{'version'}

@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_P_A

Patch block ASCII format.

=cut

format FORMAT_P_A_TOP =

.

format FORMAT_P_A =
@<<<<<<
$fmt{'_pre'}
PatchID      BugIDs                                ChangeID       Version                
-------------------------------------------------------------------------------
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  @<<<<<<<<<<<<
$fmt{'patchid'}, $fmt{'bugids'}, $fmt{'changeid'}, $fmt{'fixed'}

@*
$fmt{'msgheader'}

@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_P_h

Note in list html format.

=cut

format FORMAT_P_h_TOP =
<p>
.
   
format FORMAT_P_h =
<table border=1 width=100%>
<tr><td width=25%><b>Patch ID</b></td><td><b>Bug IDs</b></td><td><b>Change ID</b></td><td><b>Version</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'select'}
@*
$fmt{'patchid'}
@*
$fmt{'headers'}
</td><td>&nbsp;
@*
$fmt{'bugids'}
</td><td>&nbsp;
@*
$fmt{'changeid'}
</td><td>&nbsp;
@*
$fmt{'fixed'}
</td></tr><tr><td colspan=4>&nbsp;
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_P_H

Patch in block html format

=cut

format FORMAT_P_H_TOP =
<p>
.

format FORMAT_P_H =
<table border=1 width=100%>
<tr><td width=25%><b>Patch ID</b></td><td><b>Bug IDs</b></td><td><b>Change ID</b></td><td><b>Version</b></td><td><b>Created</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'select'}
@*
$fmt{'patchid'} 
</td><td>&nbsp;
@*
$fmt{'bugids'}
</td><td>&nbsp;
@*
$fmt{'changeid'}
</td><td>&nbsp;
@*
$fmt{'fixed'}
</td><td>&nbsp;
@*
$fmt{'created'}
</td></tr><tr><td colspan=5>&nbsp;
@*
$fmt{'msgheader'}
</td></tr><tr><td colspan=5>&nbsp;
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_T_l

Test lean format.

=cut

format FORMAT_T_l_TOP =
@<<<<<<
$fmt{'_pre'}
TestID      BugIDs                                Version      
@<<<<<<
$fmt{'_post'}    
.

format FORMAT_T_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  
$fmt{'testid'}, $fmt{'bugids'}, $fmt{'version'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_T_a

Test list format.

=cut

format FORMAT_T_a_TOP =

.

format FORMAT_T_a =
@<<<<<<
$fmt{'_pre'} 
TestID      BugIDs                                Version                 
-------------------------------------------------------------------------------
@<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<
$fmt{'testid'}, $fmt{'bugids'}, $fmt{'version'}

@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_T_A

Test block ASCII format.

=cut

format FORMAT_T_A_TOP =

.

format FORMAT_T_A =
@<<<<<<
$fmt{'_pre'}
TestID      BugIDs                                Version                 
-------------------------------------------------------------------------------
@<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<
$fmt{'testid'}, $fmt{'bugids'}, $fmt{'version'}

@*
$fmt{'msgheader'}

@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_T_h

Test in list html format.

=cut

format FORMAT_T_h_TOP =
<p>
.
   
format FORMAT_T_h =
<table border=1 width=100%>
<tr><td width=25%><b>Test ID</b></td><td><b>Bug IDs</b></td><td><b>Version</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'testid'}
@*
$fmt{'headers'}
</td><td>&nbsp;
@*
$fmt{'bugids'}
</td><td>&nbsp;
@*
$fmt{'version'}
</td></tr>
<tr><td colspan=3>&nbsp;
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_T_H

Test in block html format

=cut

format FORMAT_T_H_TOP =
<p>
.

format FORMAT_T_H =
<table border=1 width=100%>
<tr><td width=25%><b>Test ID</b></td><td><b>Bug IDs</b></td><td><b>Version</b></td><td><b>Created</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'testid'} 
</td><td>
@*
$fmt{'bugids'}
</td><td>&nbsp;
@*
$fmt{'version'}
</td><td>&nbsp;
@*
$fmt{'created'}
</td></tr>
<tr><td colspan=4>&nbsp;
@*
$fmt{'msgheader'}
</td></tr><tr><td colspan=4>&nbsp;
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.


=item FORMAT_G_l

Group list format.

=cut

format FORMAT_G_l_TOP =
@<<<<<<
$fmt{'_pre'}
Name                          Admins   Bugs       Addresses 
@<<<<<<
$fmt{'_post'}
.

format FORMAT_G_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<  @<<<<<<<<  @<<<<<<<<
$fmt{'name'}, $fmt{'i_userids'}, $fmt{'i_bugids'}, $fmt{'i_addresses'} 
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_G_a

Group ascii format.

=cut

format FORMAT_G_a_TOP =
Name                          Admins   Bugs       Addresses 
.

format FORMAT_G_a =
@<<<<<<
$fmt{'_pre'}
-------------------------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<  @<<<<<<<<  @<<<<<<<<
$fmt{'name'}, $fmt{'i_userids'}, $fmt{'i_bugids'}, $fmt{'i_addresses'} 
Admins: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $fmt{'userids'} 
Bugs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $fmt{'bugids'}    
Addrs:  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $fmt{'addresses'}    
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_G_A

Group ascii format.

=cut

format FORMAT_G_A_TOP =
Name                          Admins   Bugs       Addresses 
.

format FORMAT_G_A =
@<<<<<<
$fmt{'_pre'}
-------------------------------------------------------------------------------
@<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<  @<<<<<<<<  @<<<<<<<<
$fmt{'name'}, $fmt{'i_userids'}, $fmt{'i_bugids'}, $fmt{'i_addresses'} 
Description: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
	    $fmt{'description'}
Admins: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $fmt{'userids'} 
Bugs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $fmt{'bugids'}    
Addrs:  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        $fmt{'addresses'}    

.


=item FORMAT_G_h

Group in list html format.

=cut

format FORMAT_G_h_TOP =
</table><table>
<tr><td colspan=8 width=100%><hr></td></tr>
.


format FORMAT_G_h =
<tr><td colspan=8><hr></td></tr>
<tr><td>
@*
$fmt{'select'}
&nbsp;
@*
$fmt{'name'}
</td><td colspan=6><b>description</b>&nbsp;<br>
@*
$fmt{'description'}
</td></tr>
<tr><td><b>Admins</b>&nbsp;(
@*
$fmt{'i_userids'}
)</td><td colspan=7>
@*
$fmt{'userids'}
</td></tr>
<tr><td><b>Bugs</b>&nbsp;(
@*
$fmt{'i_bugids'}
)</td></tr>
<tr><td><b>Addresses</b>&nbsp;(
@*
$fmt{'i_addresses'}
)</td><td colspan=7>
@*
$fmt{'addresses'}
</td></tr>
.



=item FORMAT_G_H

Group in list html format.

=cut

format FORMAT_G_H_TOP =
</table><table>
<tr><td colspan=8 width=100%><hr></td></tr>
.

format FORMAT_G_H =
<tr><td colspan=8><hr></td></tr>
<tr><td>
@*
$fmt{'select'}
&nbsp;
@*
$fmt{'name'}
</td><td colspan=6><b>Description</b>&nbsp;
@*
$fmt{'description'}
</td></tr>
<tr><td colspan=8>&nbsp;</td></tr>
<tr><td><b>Admins</b>&nbsp;(
@*
$fmt{'i_userids'}
)</td><td colspan=7>
@*
$fmt{'userids'}
</td></tr>
<tr><td><b>Bugs</b>&nbsp;(
@*
$fmt{'i_bugids'}
)</td><td colspan=7>
@*
$fmt{'bugids'}
</td></tr>
<tr><td><b>Addresses</b>&nbsp;(
@*
$fmt{'i_addresses'}
)</td><td colspan=7>
@*
$fmt{'addresses'}
</td></tr>
<tr><td colspan=7>
@*
$fmt{'addaddress'}
</td></tr>
.


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999

=cut

1;
