# Perlbug Formatter of tickets, messages, overview, etc.
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Format.pm,v 1.27 2000/08/10 10:45:37 perlbug Exp perlbug $
#
# 


=head1 NAME

Perlbug::Format - Formats for email interface to perlbug database.

=cut

package Perlbug::Format;
use Carp;
use CGI;
use HTML::Entities;
use Data::Dumper;
use FileHandle;
use vars qw($VERSION);
$VERSION = 1.27;
$|=1;

my $DEBUG   = 2;
my %fmt     = (); # FMT?


=head1 DESCRIPTION

Different formats which can be applied to the data returned from the perlbug database via l<Perlbug> (l<Web>, l<Email> and l<Cmd>) interfaces: B<aAhHl>

If html is required, C<-f h> should be used.  The first letter following the C<-f> switch is the only one used to define which format to use for all results emanating from a single email, C<-f h> being set by default for a web call.

Specific objects supported include: Bugs, Messages, Users, Patches, Tests and Notes.

Currently this is not relevant for the C<-q> (sql query) switch, as there is little value in attempting to second guess what may be called for in sql statements.  

=head1 SYNOPSIS

	my $o_fmt = Perlbug::Format->new;
	
	my %data = (
		'some'	=> 'data',
		'other'	=> 'stuff',
	);
	
	my $str = $o_fmt->fmt(\%data);

	print $str; # 'some=data\nother=stuff\n'

=head1 FORMATS

    a ascii short - minimal listings default for mail interface
    
    A ASCII long  - maximal block style listings

    h html short  - minimal listings default for web interface
     
    H HTML short  - maximal block style listings

	l lean list   - ascii but purely for parsing minimal data
	
	L lean HTML   - like l, but with html links - yek
	

=head1 METHODS

=over 4

=item new

Create new Perlbug::Format object:

	my $do = Perlbug::Format->new();

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
		if ($arg =~ /h/i) { # h H
			$self->{'_line_break'} = "<br>\n";
			$self->{'_pre'}  = '<pre>';
			$self->{'_post'} = '</pre>';
		} else { 			# a A l
			$self->{'_line_break'} = "\n";
			$self->{'_pre'}  = '';
			$self->{'_post'} = '';
		} 
		$self->result(''); # context(".$self->current('format').") set");
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
    return undef unless defined $input;
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

Format sql queries

=cut

sub _fmt_sql { 
    my $self = shift; 
    # $self->debug(3, "Perlbug::Format::fmt_sql(@_)");
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

Formats this, and writes (via a format) to results file.

If it recognises the object via: bug(id), message(id), patch(id), note(id), user(id) the appropriate formatting is applied.

	my $res = $format->format_data(\%this); 

=cut

sub format_data { 
    my $self = shift;
    $self->debug('IN', @_);
    my $h_ref  = shift;
    return undef unless ref($h_ref) eq 'HASH';
    my $format = $shift || $self->current('format') || 'a'; 
	my %tgt = %{$h_ref};
	my %map = ( 
		'bug'       => 'B', # bug :-\
		'ticketid'	=> 'B', 
		'status'	=> 'B', 
		'severity'  => 'B',
		'category'  => 'B',
		'osname'    => 'B',
		'destaddr'  => 'B', 
		'messageid' => 'M', # messageid
		'userid'    => 'U', # userid
		'patchid'   => 'P', # patchid
		'noteid'    => 'N', # noteid
		'testid'    => 'T', # testid
		# 'overview'  => 'O', # 
		# 'schema'    => 'S', # table
	);
	my $tgt = '';
	MAP:
	foreach my $key (keys %map) {
		if (defined($tgt{$key})) {
			if ($tgt{$key} =~ /\w+/) {
				$tgt = ($key =~ /status|severity|category|osname|destaddr/i) ? 'bug' : $key;
				$self->debug(3, "found target($tgt)");
				last MAP;
			}
		}
	}
	$self->debug(3, "Formatting($tgt): ref($h_ref) via format($format)");
	my $ok = 1;
	if ($tgt !~ /\w+/) {
		$ok = 0;
		my $err = "Format target($tgt) not found for $h_ref: ".Dumper($h_ref);
		$self->debug(0, $err);
		$self->result($err."-> nothing found?");
	} else { 
		if ($format =~ /^[hHL]$/) { # 
			my $targ = $tgt; $targ =~ s/id//gi;
			my $target = "format_${targ}_fields";
			%fmt = %{ $self->$target($h_ref) };
			foreach my $k (keys %fmt) {
				if ($k =~ /msgbody|msgheader|subject/i) {
					$fmt{$k} = $self->pre.encode_entities($fmt{$k}).$self->post;
				}
			}
		} else { # ascii
			%fmt = %{ $self->format_fields($h_ref) };
		}
		if ($ok == 1) {
        	my $FORMAT = "FORMAT_$map{${tgt}}_$format"; 
			my $data = $fmt{'msgbody'} || "\n" x 700; # message|patch|note
			my $max = $data =~ tr/\n/\n/;
        	# print Dumper(\%fmt);
			$ok = $self->format_this('res', $FORMAT, $max + 500); # big enough?
		}
	}
    $self->debug('OUT', $ok);
	return $ok;
}


=item format_fields

Format individual entries for output, handles bugs, messages, users, patches, tests, notes

    my $h_tkt = $o_perlbug->format_fields($h_tkt);

=cut

sub format_fields {
    my $self = shift;
    my $h_ref= shift;
    return undef unless ref($h_ref) eq 'HASH';
    my %ref = %{$h_ref};
	foreach my $key (keys %ref) {
        if (ref($ref{$key}) eq 'ARRAY') { # ?
			if (scalar(@{$ref{$key}}) >= 1) {
	            $ref{$key} = join(' ', @{$ref{$key}});
    		} else {
				$ref{$key} = '';
			}
	    } else {
			$ref{$key} = '' unless defined($ref{$key});
			$ref{$key} = '' unless $ref{$key} =~ /\w+/;
		}
    }
	$ref{'_line_break'} = $self->line_break;
	$ref{'_pre'}  		= $self->pre;
	$ref{'_post'} 		= $self->post;
    return \%ref;
}


=item schema

Schema for database, should allow the database to format this for us ...

=cut

sub schema {
    my $self = shift;
	$self->debug(3, "Format::schema(@_)");
    my $ref  = shift;
    return undef unless ref($ref) eq 'HASH';
    my %table = %{$ref}; 
    my $format = shift || $self->current('format') || 'a'; 
    my $ok = 1;
    # my $table = $self->format(\%table);
	if ($format =~ /^[aAhH]$/) { 
        #shouldn't be handled here!
        my ($pre, $post) = ($format =~ /^h|H$/) ? ('<pre>', '</pre>') : ('', '');
	    foreach my $t (keys %table) { #tm_users...
	        my $top = qq(\nTABLENAME ($t) 
FieldName       Type                Null    Key     Default
-------------------------------------------------------------------------------
);
            $self->result($pre.$top.$post, 0);
            next unless $t =~ /^tm_\w+$/; 
            $self->debug(3, "t=$t");
			# $self->result($self->pre);
            foreach my $f (keys %{$table{$t}}) {
                #$self->debug("f=$f", 3);
	       	 	$fmt{'Field'}     = $table{$t}{$f}{'Field'};
		        $fmt{'Type'}      = $table{$t}{$f}{'Type'};
		        $fmt{'Null'}      = $table{$t}{$f}{'Null'};
		        $fmt{'Key'}       = $table{$t}{$f}{'Key'};
		        $fmt{'Default'}   = $table{$t}{$f}{'Default'};
                $ok = $self->format_this('res', "FORMAT_S_$format"); 
				# $self->result($res);
			}
            # $self->result($self->post);
		}
	} else {
	    $ok = 0;
		$self->debug(2, "Unprepared format ($format) being passed to Perlbug::format");
		$stuff = $self->format($ref);
	}
	$self->debug(4, "Schema format ($format) done ($ok)");
	return $ok; 
}


=item overview

Formating for overview.

        $fmt{'bugs'} = $data{'bugs'};

=cut

sub overview {
    my $self = shift;
	$self->debug('IN', @_);
    my $ref  = shift;
    my $format = shift || $self->current('format') || 'a';
    $format = 'a' if $format =~ /[aAl]/; # temp
	my $cgi = $self->current('url');
    my $ok = 1;
    if (ref($ref) ne 'HASH') {       #duff old style.
        # Straight scalar.
        $self->result($self->format($ref));
    } else {  
        %fmt = %{$ref}; # short cut...
        # DATA
        no strict 'refs'; 
        my %flags = $self->all_flags;
        my $href 	= "a href=\"$cgi?req=query";
		$fmt{'graph'}{'dates'} = 'Age: &nbsp;';
		# $fmt{'graph'}{'dates'} = qq|<a href="perlbug.cgi?req=graph&graph=dates">Dates:&nbsp;<br></a>|;
		$fmt{'graph'}{'admins'} = qq|<a href="perlbug.cgi?req=graph&graph=admins">Admins:&nbsp;</a>$fmt{'administrators'}|;
        foreach my $flag (keys %flags) {
	        my @types = @{$flags{$flag}};
			$fmt{'graph'}{$flag} = qq|<a href="perlbug.cgi?req=graph&graph=$flag">|.ucfirst($flag).':&nbsp;<br></a>';
	        foreach my $type (@types) {
	            $self->debug(3, "Overview ($format) flag($flag), type($type)");
                if ($format =~ /^[hH]$/) { 	# HTML
					$format = 'h'; # no H support yet
	                $fmt{$type} = qq|<$href&$flag=$type">$fmt{$flag}{$type}</a>|;
	                if (($fmt{$flag}{'Open'}{$type} =~ /^(\d+)$/) && ($flag ne 'status')) {
	                    $fmt{$type} .= qq|&nbsp;(<$href&$flag=$type&status=open">$fmt{$flag}{'Open'}{$type}</a>)|;
	                }
	            } else {                	# ASCII
	                $fmt{$type} = "$fmt{$flag}{$type}";
	                if (($flag ne 'status') && defined($fmt{$flag}{'Open'}{$type}) && ($fmt{$flag}{'Open'}{$type} =~ /^(\d+)$/)) {
	                    $fmt{$type} .= "($fmt{$flag}{'Open'}{$type})";
	                } 
				}
	            $self->debug(4, "...fmt_type($fmt{$type})");
	        }
	    }
		$fmt{'ratio_t2a'} .= " ($fmt{'ratio_o2a'})"; 
		%fmt = %{$self->format_fields(\%fmt)};
		$ok = $self->format_this('res',  "FORMAT_O_$format"); 
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
    $self->debug(3, "Perlbug::Format::format_this(@_)");
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
		# print "file($format_file), name($format_name), fh($fh)\n";
        eval { write $fh; };
        if ($@) {
            $ok = 0;
            $self->debug(0, "Format write failure: $@");
            # carp("format_this($format_file, $format_name, $max) write failure: $@");
        } else {
            my $pos = $fh->tell;
            # $ok = ($pos >= 1) ? 1 : 0;
			$self->debug(4, "Format write($pos) OK?($ok)"); # hint as to stored or not.
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


# format WWW fields
# -------------------------------------------------------------------------------

=item format_bug_fields

Format individual bug entries for placement

    my $h_tkt = $o_web->format_bug_fields($h_tkt);

=cut

sub format_bug_fields {
    my $self = shift;
    my $h_tkt= shift;
    return undef unless ref($h_tkt) eq 'HASH';
    $self->debug(3, $self->dump($h_tkt));
    my $cgi = $self->{'CGI'};
    my $url = $self->url;
    my %tkt = %{$h_tkt};
    my $bid = $tkt{'ticketid'}; # save for tid usage
    # ------------------
	
    # admins
    my @f_admins = ();
    my @admins = @{$tkt{'admins'}} if ref($tkt{'admins'}) eq 'ARRAY';
    $self->debug(3, "admins: '@admins'");
    my @active = $self->active_admins;
    if ($self->current('format') eq 'H') {
	    if (scalar @admins >= 1) {
        	foreach my $adm (@admins) {      
		    	next unless grep(/^$adm$/, @active); 
            	my %admin = %{ $self->user_data($adm) };
				# my $h_admin = $self->format_user_fields(\%admin);
				# my $o_addr = Mail::Address->parse($admin{'address'});
				# my $addr = ref($o_addr) ? $o_addr->format : $admin{'address'};
		    	my $admin = qq|<a href="mailto:$admin{'address'}">$admin{'name'}</a>|;
				push(@f_admins, $admin);
            }
	    }
    }
    $tkt{'admins'} = join(', ', @f_admins);

	# messages
    my @mids = (ref($tkt{'messageids'}) eq 'ARRAY') ? @{$tkt{'messageids'}} : ($tkt{'messageids'});
    if (scalar @mids >= 1) {
   	    ($tkt{'messageids'})  = join(', ', $self->href('mid', \@mids));
    } else {
		$tkt{'messageids'} = ''; 
	}
    ($tkt{'history'}) = $self->href('hist', [$tkt{'ticketid'}], 'History');

	# notes
    my @nids = (ref($tkt{'notes'}) eq 'ARRAY') ? @{$tkt{'notes'}} : ($tkt{'notes'});
	$tkt{'notes'} = ''; 
    if (scalar @nids >= 1) {
   	    ($tkt{'notes'})  = join(', ', $self->href('nid', \@nids));
		# NOTE:
		my @notes = $self->get_data("SELECT * FROM tm_notes WHERE ticketid = '$bid'");
		#foreach my $n (@notes) {
		#	next NOTE unless ref($n) eq 'HASH';
		#	my %n = %$n;
		#	my ($href) = $self->href('nid', [$n{'noteid'}]);
		#	$tkt{'notes'} .= $href;
		#	$tkt{'notes'} .= "<pre>: ".$n{'msgbody'}.'</pre>' if $self->current('format') eq 'H';
		#}
	} 
	
    # all messages
    my $cnt = @mids;
    my $msgs = (@mids == 1) ? "$cnt msg" : "$cnt msgs";
    ($tkt{'allmsgs'}) = $self->href('bidmids', [$tkt{'ticketid'}], $msgs);
    
    # $tkt{'msgbody'} = '<pre>'.encode_entities($tkt{'msgbody'}).'</pre>';
	# $tkt{'msgbody'} = encode_entities($tkt{'msgbody'});
	# $tkt{'subject'} = encode_entities($tkt{'subject'});
	
	# sourceaddr
    $tkt{'sourceaddr'} =~ tr/\"/\'/;
    $tkt{'sourceaddr'}      = qq|<a href="mailto:$tkt{'sourceaddr'}">$tkt{'sourceaddr'}</a>|;

    # ticketid
    ($tkt{'ticketid'})  = $self->href('bid', [$bid], $bid, $tkt{'subject'});
	$tkt{'ticketid'}    =~ s/format=h/format=H/;
    $tkt{'ticketid'}   .= "<br> &nbsp;&nbsp;($tkt{'allmsgs'})";
	
	# patches
    my @pats = (ref($tkt{'patches'}) eq 'ARRAY') ? @{$tkt{'patches'}} : ($tkt{'patches'});
    if (scalar @pats >= 1) {
   	    ($tkt{'patches'})  = join(', ', $self->href('pid', \@pats));
		# map to changeid		
    } else {
 		$tkt{'patches'} = '';
	}
	
	# tests
    my @tests = (ref($tkt{'tests'}) eq 'ARRAY') ? @{$tkt{'tests'}} : ($tkt{'tests'});
    if (scalar @tests >= 1) {
   	    ($tkt{'tests'})  = join(', ', $self->href('tid', \@tests));	
    } else {
 		$tkt{'tests'} = '';
	}
	
	# ccs
    my @ccs = (ref($tkt{'ccs'}) eq 'ARRAY') ? @{$tkt{'ccs'}} : ($tkt{'ccs'});
    if (scalar @ccs >= 1) {
		($tkt{'ccs'})  = join(', ', map { qq|<a href="mailto:$_">$_</a>| } @ccs);
    } else {
 		$tkt{'ccs'} = '';
	}
	
	# parents
    my @pids = (ref($tkt{'parents'}) eq 'ARRAY') ? @{$tkt{'parents'}} : ($tkt{'parents'});
    if (scalar @pids >= 1) {
   	    ($tkt{'parents'})  = join(', ', $self->href('bid', \@pids));
    } else {
 		$tkt{'parents'} = '';
	}
	
	# children
    my @cids = (ref($tkt{'children'}) eq 'ARRAY') ? @{$tkt{'children'}} : ($tkt{'children'});
    if (scalar @cids >= 1) {
   	    ($tkt{'children'}) = join(', ', $self->href('bid', \@cids));
    } else {
 		$tkt{'children'} = '';
	}
	
	# admin?
    if ($self->isadmin) { 
	    $self->debug(3, "Admin of bug($bid) called.");
		$tkt{'ccs'}        = $cgi->textfield(-'name' => $bid.'_ccs', -'value' => '', -'size' => 22, -'maxlength' => 55, -'override' => 1).$tkt{'ccs'};
		$tkt{'category'}   = $self->popup('category', 	$bid.'_category', 	$tkt{'category'});
        $tkt{'children'}   = $cgi->textfield(-'name' => $bid.'_children', -'value' => '', -'size' => 22, -'maxlength' => 55, -'override' => 1).$tkt{'children'};
		$tkt{'fixed'}	   = $cgi->textfield(-'name' => $bid.'_fixed', -'value' => $tkt{'fixed'}, -'size' => 10, -'maxlength' => 12, -'override' => 1);
		$tkt{'notes'}      = $tkt{'notes'}.$cgi->textarea(-'name' => $bid.'_notes', -'value' => '', -'rows' => 3, -'cols' => 45, -'override' => 1);
		$tkt{'osname'}     = $self->popup('osname', 	$bid.'_osname',      $tkt{'osname'});
		$tkt{'parents'}	   = $cgi->textfield(-'name' => $bid.'_parents', -'value' => '', -'size' => 22, -'maxlength' => 55, -'override' => 1).$tkt{'parents'};
		$tkt{'patches'}	   = $cgi->textfield(-'name' => $bid.'_patches', -'value' => '', -'size' => 10, -'maxlength' => 12, -'override' => 1).$tkt{'patches'};
		$tkt{'tests'}	   = $cgi->textfield(-'name' => $bid.'_tests', -'value' => '', -'size' => 10, -'maxlength' => 12, -'override' => 1).$tkt{'tests'};
		$tkt{'severity'}   = $self->popup('severity', 	$bid.'_severity',   	$tkt{'severity'});
        $tkt{'status'}     = $self->popup('status', 	$bid.'_status',     	$tkt{'status'});
    	$tkt{'select'}     = $cgi->checkbox(-'name'=>'bugids', -'checked' => '', -'value'=> $bid, -'label' => '', -'override' => 1);
        $tkt{'version'}	   = $cgi->textfield(-'name' => $bid.'_version', -'value' => $tkt{'version'}, -'size' => 10, -'maxlength' => 10, -'override' => 1);
	} 
	# print '<pre>'.Dumper(\%tkt).'</pre>';
	return \%tkt;
}


=item format_message_fields

Format individual message entries for placement

    my $h_msg = $o_web->format_message_fields($h_msg);

=cut

sub format_message_fields {
    my $self = shift;
    my $h_msg= shift;
    return undef unless ref($h_msg) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my %msg = %{$h_msg};
    # ------------------
    my $author = $msg{'author'};
			
    # $msg{'msgbody'} = '<pre>'.encode_entities($msg{'msgbody'}).'</pre>';
	# $msg{'msgbody'} = encode_entities($msg{'msgbody'});
	
    my $mid = $msg{'messageid'};
    my $src = $msg{'sourceaddr'};
    my $tid = $msg{'ticketid'};
    
    # ticketid
    ($msg{'ticketid'})  = $self->href('bid', [$msg{'ticketid'}], $msg{'ticketid'}, '');

    # messageid
    ($msg{'headers'}) = $self->href('mheader', [$msg{'messageid'}], '(message headers)');
    # $msg{'headers'} = qq|<a href="perlbug.cgi?req=headers&headers=$msg{'messageid'}">Headers</a>|;

    ($msg{'messageid'}) = $self->href('mid', [$msg{'messageid'}]);
    $msg{'author'} =~ tr/\"/\'/;
    $msg{'sourceaddr'} = qq|<a href="mailto:$msg{'author'}">$msg{'author'}</a>|;
    $msg{'select'}     = $cgi->checkbox(-'name'=>'messageids', -'checked' => '', -'value'=> $mid, -'label' => '', -'override' => 1);
    return \%msg;
}


=item format_patch_fields

Format individual patch entries for placement

    my $h_pat = $o_web->format_patch_fields($h_pat);

=cut

sub format_patch_fields {
    my $self = shift;
    my $h_pat= shift;
	return undef unless ref($h_pat) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my %pat = %{$h_pat};
	
	# patch
    my $patchid = $pat{'patchid'};
    ($pat{'patchid'})  = $self->href('pid', [$pat{'patchid'}], $pat{'patchid'}, '');
	$pat{'patchid'} =~ s/format\=h/format\=H/gi;
	# $pat{'msgbody'} = '<pre>'.encode_entities($pat{'msgbody'}).'</pre>';
	## $pat{'msgbody'} = encode_entities($pat{'msgbody'});
	
	($pat{'headers'}) = $self->href('pheader', [$patchid], '(patch headers)');

    $pat{'toaddr'} = qq|<a href="mailto:$pat{'toaddr'}">$pat{'toaddr'}</a>|;
    $pat{'sourceaddr'} = qq|<a href="mailto:$pat{'author'}">$pat{'author'}</a>|;
    # $pat{'subject'} = encode_entities($pat{'subject'});
	
	# strange behaviour! 
	# print "<hr>".Dumper($pat{'bugids'})."</hr>";
	($pat{'bugids'}) = join(', ', $self->href('bid', \@{$pat{'bugids'}}));
    # print "<hr>$pat{'bugids'}</hr>";
	
	$pat{'select'}     = $cgi->checkbox(-'name'=>'patches', -'checked' => '', -'value'=> $patchid, -'label' => '', -'override' => 1);
    if ($self->isadmin) {
		# ...
	}
	# print '<pre>'.Dumper(\%pat).'</pre>';
	return \%pat;
}

=item format_test_fields

Format individual test entries for placement

    my $h_test = $o_web->format_test_fields($h_test);

=cut

sub format_test_fields {
    my $self = shift;
    my $h_test= shift;
	return undef unless ref($h_test) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my %test = %{$h_test};
	
	# test
    my $testid = $test{'testid'};
    ($test{'testid'})  = $self->href('tid', [$test{'testid'}], $test{'testid'}, '');
	$test{'testid'} =~ s/format\=h/format\=H/gi;
	# $test{'msgbody'} = '<pre>'.encode_entities($test{'msgbody'}).'</pre>';
	## $test{'msgbody'} = encode_entities($test{'msgbody'});
	
	($test{'headers'}) = $self->href('theader', [$testid], '(test headers)');

    $test{'toaddr'} = qq|<a href="mailto:$test{'toaddr'}">$test{'toaddr'}</a>|;
    $test{'sourceaddr'} = qq|<a href="mailto:$test{'author'}">$test{'author'}</a>|;
    # $test{'subject'} = encode_entities($test{'subject'});
	
	# strange behaviour! 
	# print "<hr>".Dumper($test{'bugids'})."</hr>";
	($test{'bugids'}) = join(', ', $self->href('bid', \@{$test{'bugids'}}));
    # print "<hr>$test{'bugids'}</hr>";
	
	$test{'select'}     = $cgi->checkbox(-'name'=>'tests', -'checked' => '', -'value'=> $testid, -'label' => '', -'override' => 1);
    if ($self->isadmin) {
		# ...
	}
	# print '<pre>'.Dumper(\%test).'</pre>';
	return \%test;
}


=item format_note_fields

Format individual note entries for placement

    my $h_msg = $o_web->format_note_fields($h_msg);

=cut

sub format_note_fields {
    my $self = shift;
    my $h_note= shift;
    return undef unless ref($h_note) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my %note = %{$h_note};
	# $note{'msgbody'} = '<pre>'.encode_entities($note{'msgbody'}).'</pre>';
	# $note{'msgbody'} = encode_entities($note{'msgbody'});
	($note{'headers'}) = $self->href('nheader', [$note{'noteid'}], '(note headers)');

	($note{'ticketid'})  = $self->href('bid', [$note{'ticketid'}], $note{'ticketid'}, '');
	($note{'noteid'}) = $self->href('nid', [$note{'noteid'}]);
    $note{'author'} =~ tr/\"/\'/;
    return \%note;
}


=item format_user_fields

Format individual user entries for placement

    my $h_usr = $o_web->format_user_fields($h_usr);

=cut

sub format_user_fields {
    my $self = shift;
    my $h_usr= shift;
    return undef unless ref($h_usr) eq 'HASH';
    my $cgi = $self->{'CGI'};
    my $url = $self->url;
    my %usr = %{$h_usr};
    my $active  = ($usr{'active'} == 1) ? 1 : 0;
    my $address = $usr{'address'};
    my $name    = $usr{'name'};
    my $userid  = $usr{'userid'};
    my $match_address = $usr{'match_address'};
    my $password = $usr{'password'};
    if ($self->can_update($userid)) { 
		my @status = qw(1 0); push(@status, 'NULL') if $self->isadmin eq $self->system('bugmaster');
        $usr{'active'}        = $cgi->popup_menu(-'name' => $userid.'_active',    -'values' => \@status, -'labels' => {1 => 'Yes', 0 => 'No'}, -'default' => $active, -'override' => 1);
        $usr{'name'}          = $cgi->textfield( -'name' => $userid.'_name',      -'value' => $name, -'size' => 25, -'maxlength' => 50, -'override' => 1);
	    $usr{'address'}       = $cgi->textfield( -'name' => $userid.'_address',   -'value' => $address, -'size' => 35, -'maxlength' => 50, -'override' => 1);
        # $usr{'userid'}      = $cgi->textfield( -'name' => $userid.'_userid',    -'value' => $userid, -'size' => 10, -'maxlength' => 10, -'override' => 1);
        $usr{'match_address'} = $cgi->textfield( -'name' => $userid.'_match_address', -'value' => $match_address, -'size' => 45, -'maxlength' => 55, -'override' => 1);
        $usr{'password_update'}= $cgi->checkbox( -'name'  =>$userid.'_password_update', -'checked' => '', -'value'=> 1, -'label' => '', -'override' => 1);
        $usr{'password'}      = $cgi->textfield( -'name' => $userid.'_password',  -'value' => $password, -'size' => 16, -'maxlength' => 16, -'override' => 1);
        $usr{'select'}        = $cgi->checkbox( -'name'  => 'userids', -'checked' => '', -'value'=> $userid, -'label' => '', -'override' => 1);
        $usr{'select'}       .= "&nbsp;($userid)";
    } else {
        $usr{'active'}        = ($active) ? '*' : '-';
		my $o_addr = Mail::Address->parse($address);
		my $addr = ref($o_addr) ? $o_addr->address : $address;
        $usr{'address'}       = qq|<a href="mailto:$addr">$address</a>|;
        $name = "<b>$name</b>" if $active;
        $usr{'name'}          = qq|<a href="perlbug.cgi?req=uid&uid=$userid">$name</a>|;
        $usr{'password'}      = '-';
        $usr{'match_address'} = '-';
        $usr{'userid'}        = '';
    }
    return \%usr;
}
 

=item href

Return list of perlbug.cgi?req=id&... hyperlinks to given list). 

Maintains format, rng etc.

    my @links = $o_web->href('bid', \@bids, 'visible element of link', [optional subject hint]);

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
 	my $fmt = $self->current('format') || 'h';
    ITEM:
	foreach my $val (@{$a_items}) {
		next ITEM unless defined($val) and $val =~ /\w+/;
        my $vis = ($title =~ /\w+/) ? $title : $val;
	    # Params
		my $status = ($subject =~ /\w+/) ? qq|onMouseOver="status='$subject'"| : '';
		$self->debug(3, "status($status), cgi($cgi), key($key), val($val), format($fmt), status($status), vis($vis)");
		my $link = qq|<a href="$cgi?req=$key&$key=$val&range=$$&format=$fmt" $status>$vis</a>|;
        $self->debug(3, "link: '$link'");
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
	$tkt{'select'}     = $cgi->checkbox(-'name'=>'ticketid', -'checked' => '', -'value'=> $id);
	$tkt{'severity'}   = $self->popup('severity', 	$id.'_severity',   $tkt{'severity'});
	$tkt{'status'}     = $self->popup('status', 	$id.'_status',     $tkt{'status'});

=cut

sub popup {
    my $self 	= shift;
    my $flag 	= shift;
	my $uqid	= shift;
	my $default = shift || '';
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
=pod
		if ($self->{'popup'}{$flag} =~ /SELECT\sNAME\=\"([.\w]+)\"\$flag>/i) { # we are going to use the existing base data
        	$popup = $self->{'popup'}{$flag};
        	$popup =~ s/\s*selected\s*/ /i;              # trash previous selection
        	if ($default =~ /\w+/) {       
            	my $selected = q|$default" selected|;  # "  
            	$popup =~ s/^(.*)\b$default\b\"(.*)$/${1}${selected}$2/m; # replace default value
        	} else {
            	# $popup =~ s/^(.*)\b$default\b\"(.*)$/${1}${selected}$2/m; # replace default blank
        	}
        	$self->debug(3, "Cached popup ($popup) reused");
    	} else {
        	# generate a new one
        	my @flags = ('', $self->flags($flag));
        	$popup = $cgi->popup_menu( -'name' => $uqid, -'values' => \@flags, -'default' => $default, -'override' => 1);
        	$self->debug(3, "Generated popup ($popup)");
    	}
[253]  Generated popup (<SELECT NAME="19991103.005_severity">
<OPTION  VALUE="">
<OPTION  VALUE="fatal">fatal
<OPTION  VALUE="high">high
<OPTION SELECTED VALUE="medium">medium
<OPTION  VALUE="low">low
<OPTION  VALUE="wishlist">wishlist
</SELECT>
)
=cut		
	my @options = ('', sort($self->flags($flag)));
        $popup = $cgi->popup_menu( -'name' => $uqid, -'values' => \@options, -'default' => $default);
        # $self->debug(3, "Generated popup ($popup)");
    	$self->{'popup'}{$flag} = $popup;   # store the current version (without name, and without selection
	}
    return $self->{'popup'}{$flag};     # return it
}


# FORMATS: a, A, h, H, l, L 
# -----------------------------------------------------------------------------
# OBJECTS: b, r, p, t, n, u
# -----------------------------------------------------------------------------

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
$fmt{'ticketid'}, $fmt{'status'}, $fmt{'severity'}, $fmt{'category'}, $fmt{'osname'}, $fmt{'fixed'}, $fmt{'i_mids'}
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
BugID  :    @<<<<<<<<<<<<<<<                            Patch Ids:  @<<<<<<<<<<<   
			$fmt{'ticketid'},                                      $fmt{'patches'}
Created:    @<<<<<<<<<<<<<<<<<<<<                       Status:    @<<<<<<<<<<<   
            $fmt{'created'},                                       $fmt{'status'}
Version:    @<<<<<<<<<<<<<<<<<<<<                       Category:  @<<<<<<<<<<<                  
            $fmt{'version'},                                       $fmt{'category'}
Fixed in:   @<<<<<<<<<<<<<<<<<<<<                       Severity:  @<<<<<<<<<<<
            $fmt{'fixed'},                                         $fmt{'severity'}
                                                        Os:        @<<<<<<<<<<<
                                                                   $fmt{'osname'} 
Admins:     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<     
            $fmt{'admins'},                                                   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'admins'}   
Sourceaddr: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'sourceaddr'}                                           
MessageIDs: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messageids'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messageids'}   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messageids'}    
NoteIDs:    ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'notes'}    
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
BugID  :    @<<<<<<<<<<<<<<<                            Patch Ids: @<<<<<<<<<<<   
			$fmt{'ticketid'},                                      $fmt{'patches'}
Created:    @<<<<<<<<<<<<<<<<<<<<                       Status:    @<<<<<<<<<<<   
            $fmt{'created'},                                       $fmt{'status'}
Version:    @<<<<<<<<<<<<<<<<<<<<                       Category:  @<<<<<<<<<<<                  
            $fmt{'version'},                                       $fmt{'category'}
Fixed in:   @<<<<<<<<<<<<<<<<<<<<                       Severity:  @<<<<<<<<<<<
            $fmt{'fixed'},                                         $fmt{'severity'}
                                                        Os:        @<<<<<<<<<<<
                                                                   $fmt{'osname'} 
Admins:     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  
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
            $fmt{'messageids'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messageids'}   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'messageids'}  
Ccs:        ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'ccs'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'ccs'}     
NotesIDs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'notes'}    
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'notes'}   
~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'notes'}  
TestIDs:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $fmt{'tests'} 
Messagebody:
@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
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
<td><b>Patch</b></td>
<td><b>Tests</b></td>
<td><b>Notes</b></td>
<td><b>Fixed in</b></td>
<td><b>Subject</b></td>
</tr>
.


format FORMAT_B_h =
<tr><td>&nbsp;
@*
$fmt{'select'}
</td><td>&nbsp;
@*
$fmt{'ticketid'}
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
$fmt{'patches'}
</td><td>&nbsp;
@*
$fmt{'tests'}
</td><td>&nbsp;
@*
$fmt{'notes'}
</td><td>&nbsp;
@*
$fmt{'fixed'}
</td><td>&nbsp;
@*
$fmt{'subject'}
</td>
</tr>
.



=item FORMAT_B_H

Html, tabled in block format:
...

=cut

format FORMAT_B_H_TOP =
<p>
.


format FORMAT_B_H =
<table border=1 width=100%><tr>
<td><b>BugID  </b></td><td><b>History</b></td><td><b>Version</b></td><td><b>Created</b></td><td><b>Fixed In</b></td>
</tr>
<tr><td> 
@*
$fmt{'select'}
&nbsp;
@*
$fmt{'ticketid'}
</td><td>
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
&nbsp;</td><td><b>Patches:</b><br>
@*
$fmt{'patches'}
&nbsp;</td></tr>
<tr><td><b>Sourceaddr:</b></td><td colspan=5>
@*
$fmt{'sourceaddr'}
&nbsp;<td></tr>
<tr><td><b>Subject:</b></td><td colspan=5>
@*
$fmt{'subject'}
&nbsp;</td></tr>
<tr><td><b>Administrators:</b></td><td colspan=5>
@*
$fmt{'admins'}
&nbsp;</td></tr>
<tr><td><b>Parent IDs:</b></td><td colspan=2>
@*
$fmt{'parents'}
&nbsp;</td><td><b>Child IDs:</b></td><td colspan=2>
@*
$fmt{'children'}
&nbsp;</td></tr>
<tr><td><b>Message IDs:</b></td><td colspan=5>
@*
$fmt{'messageids'}
&nbsp;</td></tr>
<tr><td><b>Ccs:</b></td><td colspan=5>
@*
$fmt{'ccs'}
&nbsp;</td></tr>
<tr><td><b>Notes:</b></td><td colspan=5>
@*
$fmt{'notes'}
&nbsp;</td></tr>
<tr><td><b>Tests:</b></td><td colspan=5>
@*
$fmt{'tests'}
&nbsp;</td></tr>
<tr></table>
<table border=1 width=100%><tr><td colspan=6>
@*
$fmt{'msgbody'}
&nbsp;</td></tr>
<tr><td colspan=6>
@*
$fmt{'buttons'}
</td></tr></table>
<br>
.


=item FORMAT_O_a

Formating for overview (default).
...
    
=cut

format FORMAT_O_a_TOP =
PerlBug Database overview, figures in brackets() are still open:
-------------------------------------------------------------------------------
.

format FORMAT_O_a =
@<<<<<<
$fmt{'_pre'}
Bugs     Messages Patches Tests  Notes  Admins  24hrs   7days   30days   90days   
@<<<<<<< @<<<<<<< @<<<<<< @<<<<< @<<<<< @<<<<<< @<<<<<< @<<<<<< @<<<<<<< @<<<<<
$fmt{'bugs'}, $fmt{'messages'}, $fmt{'patches'}, $fmt{'tests'}, $fmt{'notes'}, $fmt{'administrators'}, $fmt{'days1'}, $fmt{'days7'}, $fmt{'days30'}, $fmt{'days90'}
Ratios:     Open to Closed   Closed to Open   Msgs to Bugs     Bugs to Admins 
            @<<<<<<<<<<<<<   @<<<<<<<<<<<<<   @<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<
            $fmt{'ratio_o2c'}, $fmt{'ratio_c2o'}, $fmt{'ratio_m2t'}, $fmt{'ratio_t2a'}
Status:     Open       Closed     Busy       Onhold     Abandoned  Duplicate                                          
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
            $fmt{'open'}, $fmt{'closed'}, $fmt{'busy'}, $fmt{'onhold'}, $fmt{'abandoned'}, $fmt{'duplicate'}
Category:   Install    Library    Patch      Core       Docs       Utilities     
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
            $fmt{'install'}, $fmt{'library'}, $fmt{'patch'}, $fmt{'core'}, $fmt{'docs'}, $fmt{'utilities'}
            Unknown    Notabug    OK
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
            $fmt{'unknown'}, $fmt{'notabug'}, $fmt{'ok'}
Severity:   Fatal      High       Medium     Low        Wishlist
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
            $fmt{'fatal'}, $fmt{'high'}, $fmt{'medium'}, $fmt{'low'}, $fmt{'wishlist'}
OS:         Generic     Linux       Win32       MacOS    Solaris     Hpux        Aix     
            @<<<<<<<<<< @<<<<<<<<<< @<<<<<<<<<< @<<<<<<< @<<<<<<<<<< @<<<<<<<<<< @<<<<<<<<<<
            $fmt{'generic'}, $fmt{'linux'}, $fmt{'mswin32'}, $fmt{'macos'}, $fmt{'solaris'}, $fmt{'hpux'}, $fmt{'aix'}, 
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_O_h_TOP

Formatting for html overview.

=cut

format FORMAT_O_h_TOP =
<p>
.

format FORMAT_O_h =
<table border=1><tr>
<td colspan=8><h3>Perlbug Database overview: all bugs</h3></td>
</tr>
<tr><td colspan=8><i>Figures in brackets() are still open</i></td></tr>
<TR>
	<td><b>
	@*
	$fmt{'graph'}{'admins'}
	</b></td>
	<td><b>Bugs:</b> &nbsp;
	@<<<<<<<
	$fmt{'bugs'}
	</td>
	<td><b>Messages:</b> &nbsp;
	@<<<<<<<
	$fmt{'messages'}
	</td>
	<td><b>Patches:</b> &nbsp;
	@<<<<<<<
	$fmt{'patches'}
	</td>
	<td><b>Notes:</b> &nbsp;
	@<<<<<<<
	$fmt{'notes'}
	</td>
	<td><b>Tests:</b> &nbsp;
	@<<<<<<<
	$fmt{'tests'}
	</td>
	<td><b>Bugs to Messages:</b> &nbsp;
	@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
	$fmt{'ratio_m2t'}
	</td>
	<td colspan=2><b>Bugs to admins</b> &nbsp;
	@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
	$fmt{'ratio_t2a'}
	</td>
</TR>
<TR>
	<td><b>
	@*
	$fmt{'graph'}{'dates'}
	</b>&nbsp;</td>
	<td><b>24hrs:</b> &nbsp;
	@*
	$fmt{'days1'}
	</td><td><b>7 days:</b> &nbsp;
	@*
	$fmt{'days7'}
	</td><td><b>30 days:</b> &nbsp;
	@*
	$fmt{'days30'}
	</td><td><b>90 days:</b> &nbsp;
	@*
	$fmt{'days90'}
	</td><td colspan=2><b>Over 90 days:</b> &nbsp;
	@*
	$fmt{'90plus'}
	</td>
	<td>&nbsp;</td>
</TR>
<TR>
	<td><b>
	@*
	$fmt{'graph'}{'status'}
	</b>&nbsp;</td>
	<td><b>Open:</b> &nbsp;
	@*
	$fmt{'open'}
	</td><td><b>Closed:</b> &nbsp;
	@*
	$fmt{'closed'}
	</td><td><b>Busy:</b> &nbsp;
	@*
	$fmt{'busy'}
	</td><td><b>Onhold:</b> &nbsp;
	@*
	$fmt{'onhold'}
	</td><td><b>Abandoned:</b> &nbsp;
	@*
	$fmt{'abandoned'}
	</td>
	<td><b>Duplicate:</b> &nbsp;
	@*
	$fmt{'duplicate'}
	</td>
	<td>&nbsp;</td>
</TR>
<TR>
	<td><b>
	@*
	$fmt{'graph'}{'category'}
	</b>&nbsp;</td>
	<td><b>Install:</b> &nbsp;
	@*
	$fmt{'install'}
	</td><td><b>Library:</b> &nbsp;
	@*
	$fmt{'library'}
	</td><td><b>Patch:</b> &nbsp;
	@*
	$fmt{'patch'}
	</td><td><b>Core:</b> &nbsp;
	@*
	$fmt{'core'}
	</td><td><b>Docs:</b> &nbsp;
	@*
	$fmt{'docs'}
	</td><td><b>Utilities:</b> &nbsp;
	@*
	$fmt{'utilities'}
	</td><td><b>Unknown:</b> &nbsp;
	@*
	$fmt{'unknown'}
	</td>
</TR>
<TR>
	<td><b>
	@*
	$fmt{'graph'}{'severity'}
	</b>&nbsp;</td>
	<td><b>Fatal:</b> &nbsp;
	@*
	$fmt{'fatal'}
	</td><td><b>High:</b> &nbsp;
	@*
	$fmt{'high'}
	</td><td><b>Medium:</b> &nbsp;
	@*
	$fmt{'medium'}
	</td><td><b>Low:</b> &nbsp;
	@*
	$fmt{'low'}
	</td><td><b>Wishlist:</b> &nbsp;
	@*
	$fmt{'wishlist'}
	</td>
	<td>&nbsp;</td>
	<td><b>Notabug:</b> &nbsp;
	@*
	$fmt{'notabug'}
	</td>
</TR>
<TR>
	<td><b>
	@*
	$fmt{'graph'}{'osname'}
	</b>&nbsp;</td>
	<td><b>Generic:</b> &nbsp;
	@*
	$fmt{'generic'}
	</td><td><b>Linux:</b> &nbsp;
	@*
	$fmt{'linux'}
	</td><td><b>Win32:</b> &nbsp;
	@*
	$fmt{'mswin32'}
	</td><td><b>MacOS:</b> &nbsp;
	@*
	$fmt{'macos'}
	</td><td><b>Solaris:</b> &nbsp;
	@*
	$fmt{'solaris'}
	</td><td><b>HPux:</b> &nbsp;
	@*
	$fmt{'hpux'}
	</td><td><b>Aix:</b> &nbsp;
	@*
	$fmt{'aix'}
	</td>
</TR>
</table>
.

# other


=item FORMAT_S_a

Default format for Schema fields for database (top elsewhere).

=cut

format FORMAT_S_a_TOP =
.
format FORMAT_S_a =
@<<<<<<<<<<<<   @<<<<<<<<<<<<<<<    @<<<<<  @<<<<<  @<<<<<< @<<<<
$fmt{'Field'}, $fmt{'Type'}, $fmt{'Null'}, $fmt{'Key'}, $fmt{'Default'}, $fmt{'Extra'}
.


=item FORMAT_S_h

Html format for Schema fields for database (top elsewhere temporarily).

=cut

format FORMAT_S_h_TOP =
.
format FORMAT_S_h =
<pre>
@<<<<<<<<<<<<   @<<<<<<<<<<<<<<<    @<<<<<  @<<<<<  @<<<<<< @<<<<
$fmt{'Field'}, $fmt{'Type'}, $fmt{'Null'}, $fmt{'Key'}, $fmt{'Default'}, $fmt{'Extra'}
</pre>
.

=item FORMAT_M_l

Messages lean format.

=cut

format FORMAT_M_l_TOP =
@<<<<<<
$fmt{'_pre'}
Messageid   Bugid
@<<<<<<
$fmt{'_post'}
.

format FORMAT_M_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<  @<<<<<<<<<<<<<
$fmt{'messageid'}, $fmt{'ticketid'} 
@<<<<<<
$fmt{'_post'}
.


=item FORMAT_M_a

Messages list format.

=cut

format FORMAT_M_a_TOP =

.

format FORMAT_M_a =
@<<<<<<
$fmt{'_pre'}
MessageID   BugID     
-------------------------------------------------------------------------------
@<<<<<<<<<  @<<<<<<<<<<<<<
$fmt{'messageid'}, $fmt{'ticketid'} 
Messagebody:
@*
$fmt{'msgbody'}
@<<<<<<
$fmt{'_post'}
.

# Message body suppressed (try 'M' or 'T')


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
$fmt{'messageid'}, $fmt{'ticketid'} 
Messagebody:
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
$fmt{'ticketid'}
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
$fmt{'ticketid'}
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

User list format.

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
@<<<<<<
$fmt{'_post'}
.

=item FORMAT_U_h

User in list html format.

=cut

format FORMAT_U_h_TOP =
<tr><td colspan=8 width=100%><hr></td></tr>
<tr><td width=35><b>Name</b></td><td width=15><b>Active?</b></td><td><b>Bugs</b></td><td><b>Address</b></td><td><b>Password</b></td><td><b>Match Address</b></td></tr>
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
$fmt{'noteid'}, $fmt{'created'}, $fmt{'ticketid'} 
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
$fmt{'noteid'}, $fmt{'created'}, $fmt{'ticketid'} 
Messagebody:
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
$fmt{'noteid'}, $fmt{'created'}, $fmt{'ticketid'} 
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
<tr><td width=25%><b>Note ID</b></td><td><b>Bug ID</b></td><td><b>Admin</b></td><td><b>Created</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'noteid'}
@*
$fmt{'headers'}
</td><td> &nbsp;    
@*
$fmt{'ticketid'}
</td><td>&nbsp;
@*
$fmt{'author'}
</td><td>&nbsp;
@*
$fmt{'created'}
</td></tr><tr><tr><td colspan=4>
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
<tr><td width=25%><b>Note ID</b></td><td><b>Bug ID</b></td><td><b>Created</b></td><td><b>Admin</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'noteid'}
</td><td>&nbsp;
@*
$fmt{'ticketid'}
</td><td>&nbsp;
@<<<<<<<<<<<<<<<<<<<<<<<<<
$fmt{'created'}
</td><td>&nbsp;
@*
$fmt{'author'}
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
PatchID      BugIDs                    ChangeID         
@<<<<<<
$fmt{'_post'}    
.

format FORMAT_P_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  
$fmt{'patchid'}, $fmt{'bugids'}, $fmt{'changeid'}
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
PatchID      BugIDs                    ChangeID               
-------------------------------------------------------------------------------
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  
$fmt{'patchid'}, $fmt{'bugids'}, $fmt{'changeid'}
Patch:
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
PatchID      BugIDs                    ChangeID           
-------------------------------------------------------------------------------
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  
$fmt{'patchid'}, $fmt{'bugids'}, $fmt{'changeid'}
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
<tr><td width=25%><b>Patch ID</b></td><td><b>Bug IDs</b></td><td><b>Change ID</b></td><td><b>&nbsp;</b></td></tr>
<tr><td>&nbsp;
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
</td></tr><tr><td colspan=5>&nbsp;
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
<tr><td width=25%><b>Patch ID</b></td><td><b>Bug IDs</b></td><td><b>&nbsp;</b></td><td><b>Change ID</b></td><td><b>Created</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'patchid'} 
</td><td>&nbsp;
@*
$fmt{''}
</td><td>&nbsp;
@*
$fmt{'fixed'}
</td><td>&nbsp;
@*
$fmt{'changeid'}
</td><td>&nbsp;
@*
$fmt{'created'}
</td></tr><tr><td colspan=6>
@*
$fmt{'msgheader'}
</td></tr><tr><td colspan=6>&nbsp;
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
TestID       BugIDs                    ChangeID       
@<<<<<<
$fmt{'_post'}    
.

format FORMAT_T_l =
@<<<<<<
$fmt{'_pre'}
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  
$fmt{'testid'}, $fmt{'bugids'}, $fmt{'changeid'}
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
TestID       BugIDs                    ChangeID               
-------------------------------------------------------------------------------
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  
$fmt{'testid'}, $fmt{'bugids'}, $fmt{'changeid'}
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
TestID       BugIDs                    ChangeID          
-------------------------------------------------------------------------------
@<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<  
$fmt{'testid'}, $fmt{'bugids'}, $fmt{'changeid'}
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
<tr><td width=25%><b>Test ID</b></td><td><b>Bug IDs</b></td><td><b>Change ID</b></td><td><b>&nbsp;</b></td></tr>
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
$fmt{'changeid'}
</td><td>&nbsp;
@*
$fmt{'fixed'}
</td></tr>
<tr><td colspan=5>&nbsp;
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
<tr><td width=25%><b>Test ID</b></td><td><b>Bug IDs</b></td><td><b>&nbsp;</b></td><td><b>Change ID</b></td><td><b>Created</b></td></tr>
<tr><td>&nbsp;
@*
$fmt{'testid'} 
</td><td>
@*
$fmt{'bugids'}
</td><td>&nbsp;
@*
$fmt{''}
</td><td>&nbsp;
@*
$fmt{'fixed'}
</td><td>&nbsp;
@*
$fmt{'changeid'}
</td><td>&nbsp;
@*
$fmt{'created'}
</td></tr>
<tr><td colspan=5>
@*
$fmt{'msgheader'}
</td></tr><tr><td colspan=6>&nbsp;
@*
$fmt{'msgbody'}
</td></tr></table><br><p>
.
=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999

=cut

1;

