# $Id: Bug.pm,v 1.33 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Bug - Bug class

=cut

package Perlbug::Object::Bug;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.33 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Bug_DEBUG'} || $Perlbug::Object::Bug::DEBUG || '';
$|=1;

my %fmt = ();


=head1 DESCRIPTION

Perlbug bug class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use HTML::Entities;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Bug;

	print Perlbug::Object::Bug->new()->read('19990127.003')->format('a');


=head1 METHODS

=item new

Create new Bug object:

	my $o_bug = Perlbug::Object::Bug->new();

Object references are returned with most methods, so you can 'chain' the calls:

	print $o_bug->read('198700502.007')->format('h'); 

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Bug',
		'match_oid'	=> '(\d{8}\.\d{3})',
		'from'		=> [qw(group project range user)],
		'to'		=> [qw(
			address change child fixed message note osname parent patch severity status test version
		)],
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG;

	bless($self, $class);
}


sub read {
	my $self = shift;
	$self->SUPER::read(@_);
	return $self;  
}


=item update

extend B<SUPER::update> with notify_cc (of changes)

=cut

sub update {
	my $self = shift;

	# my $ix = $self->notify_cc($bid, '', $orig) unless $nocc eq 'nocc';

	return $self->SUPER::update(@_);
}


=item new_id

Return valid new object id for bug, wrapper for base->new_id

	my $new_oid = $o_bug->new_id

# =cut redundant

sub new_id {
	my $self = shift;

	my $newid = $self->base->new_id;	

	return $newid;
}


=item insertid

Returns newly inserted id from recently created object.
	
	my $new_oid = $o_obj->insertid();

=cut

sub insertid {
	my $self = shift;

	my $oid = $self->data($self->attr('primary_key'));	
	$self->debug(0, "newly inserted bugoid($oid)") if $DEBUG;

	return $oid; 
}


=item htmlify 

html formatter for individual bug entries for placement

    my $h_bug = $o_bug->htmlify($h_bug);

See also L<Perlbug::Object::htmlify()>

=cut

sub htmlify {
    my $self = shift;
    my $h_bug= shift;
	return undef unless ref($h_bug) eq 'HASH';
    # $self->debug(3, $self->base->dump($h_bug)) if $DEBUG;
    my $cgi = $self->base->cgi();
    my $url = $self->base->url;
    my %bug = %{$h_bug};
    my $bid = $bug{'bugid'}; # save for bid usage
	# print $self->base->html_dump($h_bug);

	# messages
    my @mids = (ref($bug{'message_ids'}) eq 'ARRAY') ? @{$bug{'message_ids'}} : ($bug{'message_ids'});
	$bug{'message_ids'} = \@mids;
    my $cnt = @mids;
    my $msgs = (@mids == 1) ? "($cnt msg)" : "($cnt msgs)";
	my $stat_msgs = "$cnt messages for bug($bid)";
    my ($allmsgs) = $self->href('bidmids', [$bid], $msgs, $stat_msgs);
 
	%bug = %{$self->SUPER::htmlify($h_bug)};	
	$bug{'bugid'}     =~ s/format=h/format=H/;
    $bug{'bugid'}    .= " &nbsp; $allmsgs";
	my $stat_hist = "History for bug($bid)";
    ($bug{'history'}) = $self->href('hist', [$bid], 'History', $stat_hist);
	$bug{'newstuff'}  = '';

	foreach my $item (qw(children parent)) {
		$item = $item.'_ids';
		my @items = (ref($$h_bug{$item}) eq 'ARRAY') ? @{$$h_bug{$item}} : ($$h_bug{$item});
		if (scalar @items>= 1) {
			my $stat_item = $item."(".@items.") for bug($bid)";
			($bug{$item}) = join(', ', $self->href('bug_id', \@items, $item, $stat_item));
		} else {
			$bug{$item} = '';
		}
	}
		
	# admin?
    if ($self->base->isadmin && $self->base->current('format') ne 'L') { # LEAN for browsing...
	    $self->debug(3, "Admin of bug($bid) called.") if $DEBUG;
		my ($group)    = @{$$h_bug{'group_ids'}}    if $$h_bug{'group_ids'};
		my ($osname)   = @{$$h_bug{'osname_ids'}}   if $$h_bug{'osname_ids'};
		my ($severity) = @{$$h_bug{'severity_ids'}} if $$h_bug{'severity_ids'};
		my ($status)   = @{$$h_bug{'status_ids'}}   if $$h_bug{'status_ids'};
		my ($user)     = @{$$h_bug{'user_ids'}}     if $$h_bug{'user_ids'};
		my ($fixed)    = $self->object('fixed')->id2name($$h_bug{'fixed_ids'})     if $$h_bug{'fixed_ids'};
		my ($version)  = $self->object('version')->id2name($$h_bug{'version_ids'}) if $$h_bug{'version_ids'};
		# print "<hr>c($group) o($osname) sev($severity) stat($status) u($user) ver($version)<hr>";
		$bug{'help'} = q|Enter an <b>existing</b> id in the <b>ID</b> row <i>above</i>, to assign a new relation to this bug.<hr>|;
		$bug{'help'}.= q|Enter new <b>data</b> in the row <i>below</i> to create a new note, patch or test.  With a new patch, consider entering a <b>changeID</b> at the same time!|;
		$bug{'address_names'} = $self->object('address')->textfield($bid.'_address', '', -'size' => 55).$bug{'address_ids'};
		$bug{'note_names'}   	= $self->object('note')->textfield($bid.'_note', '').$bug{'note_ids'};
		$bug{'group_names'}  	= $self->object('group')->popup($bid.'_group', $group); 
		$bug{'change_names'}  = $self->object('change')->textfield($bid.'_change', '').$bug{'change_ids'};
		$bug{'child_ids'}   = $self->object('child')->textfield($bid.'_child', '').$bug{'child_ids'};
        $bug{'fixed'}       = $self->object('fixed')->textfield($bid.'_fixed', $fixed);
		# new stuff is only for format::H
		$bug{'newnote'}     = $cgi->textarea(-'name'  => $bid.'_newnote',  -'value' => '', -'rows' => 3, -'cols' => 25, -'override' => 1, 'onChange' => 'pick(this)');
		$bug{'newpatch'}    = $cgi->textarea(-'name'  => $bid.'_newpatch', -'value' => '', -'rows' => 3, -'cols' => 35, -'override' => 1, 'onChange' => 'pick(this)');
		$bug{'newtest'}     = $cgi->textarea(-'name'  => $bid.'_newtest',  -'value' => '', -'rows' => 3, -'cols' => 25, -'override' => 1, 'onChange' => 'pick(this)');
		# end newstuff
		$bug{'note_ids'}  = $self->object('note')->textfield($bid.'_note', '').$bug{'note_ids'};
		$bug{'osname_names'}  = $self->object('osname')->popup($bid.'_osname', $osname);
		$bug{'parent_ids'}  = $self->object('parent')->textfield($bid.'_parent', '').$bug{'parent_ids'};
		$bug{'patch_ids'}   = $self->object('patch')->textfield($bid.'_patch', '').$bug{'patch_ids'};
		$bug{'test_ids'}    = $self->object('test')->textfield($bid.'_test', '').$bug{'test_ids'};
		$bug{'severity_names'}= $self->object('severity')->popup($bid.'_severity', $severity);
        $bug{'status_names'}  = $self->object('status')->popup($bid.'_status', $status);
    	$bug{'select'}      = $cgi->checkbox(-'name'=>'bugids', -'checked' => '', -'value'=> $bid, -'label' => '', -'override' => 1);
        # $bug{'user_ids'}  = $self->object('user')->selector($bid.'_user', $user);
        $bug{'version_names'} = $self->object('version')->textfield($bid.'_version', $version);
	}
	# print '<pre>h_bug'.encode_entities(Dumper($h_bug)).'</pre>'; 
	# print '<pre>bug'.encode_entities(Dumper(\%bug)).'</pre>'; 
	return \%bug;
}


=head1 FORMATS

Bug formatters for all occasions...


=item FORMAT_l

Lean (list) ascii format for bugs:

	my ($top, $format, @args) = $o_bug->FORMAT_l(\%data);

=cut


sub FORMAT_l { # 
	my $self = shift;
	my $d    = shift; # 
	my @args = ( 
		$$d{'bugid'}, 
		$$d{'status_names'}, $$d{'severity_names'}, $$d{'group_names'}, $$d{'osname_names'},
		$$d{'fixed'}, $$d{'user_count'}, $$d{'message_count'},
		$$d{'note_count'}, $$d{'patch_count'}, $$d{'test_count'},
	);
	my $top = qq|
Bug id         Status   Severity Group     Os      Fixd Adms Msgs Nts Pchs Tsts
-------------------------------------------------------------------------------
|;
	my $format = qq|
@<<<<<<<<<<<<  @<<<<<<< @<<<<<<  @<<<<<<<< @<<<<<< @<<< @<<< @<<< @<< @<<< @<<<
|; 
	return ($top, $format, @args);
}


=item FORMAT_a

Default ascii format
	
	my ($top, $format, @args) = $o_bug->FORMAT_a(\%data);

=cut

sub FORMAT_a { # default where format or method missing!
	my $self = shift;
	my $x = shift; # 
	my @args = ( 
		$$x{'subject'}, 
		$$x{'bugid'}, 		    $$x{'status_names'},	
		$$x{'created'}, 		$$x{'group_names'}, 
		$$x{'version_names'},	$$x{'severity_names'},
		$$x{'fixed'}, 			$$x{'osname_names'}, 
		$$x{'user_count'}, 		$$x{'user_names'},
		$$x{'sourceaddr'}, 
		$$x{'message_count'}, 	$$x{'message_ids'},
		$$x{'note_count'}, 		$$x{'note_ids'},
		$$x{'patch_count'},		$$x{'patch_ids'}, 
		$$x{'change_count'}, 	$$x{'change_names'}, 
		$$x{'test_count'}, 		$$x{'test_ids'},
		$$x{'parent_count'}, 	$$x{'parent_ids'},
		$$x{'child_count'}, 	$$x{'child_ids'},
	);
	my $top = '';
	my $format = qq|   
------------------------------------------------------------------------------- 
Subject:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
BugID  :    @<<<<<<<<<<<<<<<          Status:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<... 
Created:    @<<<<<<<<<<<<<<<<<<<<     Group:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<...   
Version:    @<<<<<<<<<<<<<<<<<<<<     Severity: @<<<<<<<<<<<<<<<<<<<<<<<<<<<...                  
Fixed in:   @<<<<<<<<<<<<<<<<<<<<     Osname:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<...
Admins:     @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
Sourceaddr: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
MessageIDs: @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
NoteIDs:    @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
PatchIDs:   @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
ChangeIDs:  @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
TestIDs:    @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
ParentID:   @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
ChildIDs:   @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
	|;
	return ($top, $format, @args);
}


=item FORMAT_B_A

Default ASCII format for bugs:

	my ($top, $format, @args) = $o_bug->FORMAT_A(\%data);

=cut

sub FORMAT_A { # 
	my $self = shift;
	my $x    = shift; # 
	my @args = ( 
		$$x{'subject'}, 
		$$x{'bugid'}, 			$$x{'status_names'},
		$$x{'created'}, 		$$x{'group_names'}, 
		$$x{'version_names'},	$$x{'severity_names'},
		$$x{'fixed'}, 			$$x{'osname_names'}, 
		$$x{'user_count'}, 		$$x{'user_names'},
		$$x{'sourceaddr'}, 
		$$x{'message_count'}, 	$$x{'message_ids'},
		$$x{'note_count'}, 		$$x{'note_ids'},
		$$x{'patch_count'},		$$x{'patch_ids'}, 
		$$x{'change_count'}, 	$$x{'change_names'}, 
		$$x{'test_count'}, 		$$x{'test_ids'},
		$$x{'parent_count'}, 	$$x{'parent_ids'},
		$$x{'children_count'}, 	$$x{'children_ids'},
		$$x{'address_count'},	$$x{'address_names'}, 
		$$x{'body'},
	);
	my $top    = '';
	my $format = qq|
------------------------------------------------------------------------------- 
Subject:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
BugID  :    @<<<<<<<<<<<<<<<            Status:  @<<<<<<<<<<<<<<<<<<<<<<<<<<... 
Created:    @<<<<<<<<<<<<<<<<<<<<       Groups:  @<<<<<<<<<<<<<<<<<<<<<<<<<<...
Version:    @<<<<<<<<<<<<<<<<<<<<     Severity:  @<<<<<<<<<<<<<<<<<<<<<<<<<<...
Fixed in:   @<<<<<<<<<<<<<<<<<<<<           Os:  @<<<<<<<<<<<<<<<<<<<<<<<<<<...
Admins:     @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
Sourceaddr: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
MessageIDs: @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
NoteIDs:    @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
PatchIDs:   @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
ChangeIDs:  @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
TestIDs:    @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
ParentIDs:  @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
ChildrenIDs:@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
Ccs:        @<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<...
Message Header :
@*
Message body :  
@*
	|;
	return ($top, $format, @args);
}


=item FORMAT_L

Lean html format for bugs:
	
	my ($top, $format, @args) = $o_bug->FORMAT_L(\%data);

=cut

sub FORMAT_L { # 
	my $self = shift;
	my $x    = shift; # 
	my @args = ( 
		$$x{'select'},
		$$x{'bugid'}, 			
		$$x{'status_names'},
		$$x{'version_names'},	
		$$x{'group_names'}, 
		$$x{'severity_names'},	
		$$x{'osname_names'},	
		$$x{'fixed_names'}, 
		$$x{'message_count'}, 	
		$$x{'patch_count'},		
		$$x{'change_names'}, 	
		$$x{'test_count'}, 		
		$$x{'note_count'}, 		
	);
	my $top = q|<tr>
	<td>&nbsp;</td>
	<td>BugID</td>
	<td>Status</td>
	<td>Version</td>
	<td>Group</td>
	<td>Severity</td>
	<td>Osname</td>
	<td>Fixed</td>
	<td>Message IDs</td>
	<td>Patch IDs</td>
	<td>Change IDs</td>
	<td>Test IDs</td>
	<td>Note IDs</td>
</tr>|;
	my $format = '<tr><td>'.join('&nbsp;</td><td>', @args).'&nbsp;<td></tr>';	
	return ($top, $format, ());
}


=item FORMAT_h

html format for bugs:
	
	my ($top, $format, @args) = $o_bug->FORMAT_h(\%data);

=cut

sub FORMAT_h { # 
	my $self = shift;
	my $x    = shift; # 
	my @args = ( 
		$$x{'select'},
		$$x{'bugid'}, 			
		$$x{'status_names'},
		$$x{'version_names'}, 		
		$$x{'group_names'}, 
		$$x{'severity_names'},
		$$x{'osname_names'}, 
		$$x{'fixed'}, 			
		$$x{'subject'}, 
		$$x{'user_names'}, 		
		$$x{'sourceaddr'}, 
		$$x{'message_count'}, 	
		$$x{'note_count'}, 		
		$$x{'patch_count'}, 	
		$$x{'change_count'}, 
		$$x{'test_count'}, 	
		$$x{'address_count'}
	);
	my $top = qq|<tr>
<td>&nbsp;</td>
<td><b>BugID  </b></td>
<td><b>Status</b></td>
<td><b>Version</b></td>
<td><b>Group</b></td>
<td><b>Severity</b></td>
<td><b>OS</b></td>
<td><b>Fixed in</b></td>
<td><b>Subject</b></td>
<td><b>Admins</b></td>
<td><b>Source address</b></td>
<td><b>Messages</b></td>
<td><b>Notes</b></td>
<td><b>Patches</b></td>
<td><b>Changes</b></td>
<td><b>Tests</b></td>
<td><b>Cc's</b></td>
</tr>|;
	my $format = '<tr><td>'.join('&nbsp;</td><td>', @args).'&nbsp;<td></tr>';	
	return ($top, $format, ());
}


=item FORMAT_H

HTML format for bugs:
	
	my ($top, $format, @args) = $o_bug->FORMAT_H(\%data);

=cut

sub FORMAT_H { # 
	my $self = shift;
	my $x    = shift; # 
	my $top    = '';
	my $format = qq|<table border=1 width=100%><tr>
<td><b>BugID</b></td><td><b>Version</b></td><td><b>Created</b></td><td><b>Fixed In</b></td>
</tr>
<tr>
<td> 
$$x{'select'} &nbsp; $$x{'bugid'} &nbsp; $$x{'history'}</td>
<td>
$$x{'version_names'} &nbsp;</td>
<td>
$$x{'created'} &nbsp;</td>
<td>
$$x{'fixed'}
&nbsp;</td>
</tr>
<tr>
<td><b>Status:</b>
$$x{'status_names'} &nbsp;</td>
<td><b>Group:</b>
$$x{'group_names'} &nbsp;</td>
<td><b>Severity:</b> $$x{'severity_names'} &nbsp;</td>
<td><b>OS:</b> $$x{'osname_names'} &nbsp;</td>
</tr>
<tr>
<td><b>Sourceaddr:</b></td><td colspan=3> $$x{'sourceaddr'} &nbsp;</td>
</tr>
<tr>
<td><b>Subject:</b></td> <td colspan=3> $$x{'subject'} &nbsp;</td>
</tr>
<tr>
<td><b>Administrators:</b></td><td colspan=3> $$x{'user_names'} &nbsp;</td>
</tr>
<tr>
<td><b>Parent IDs:</b></td><td> $$x{'parent_ids'} &nbsp;</td>
<td><b>Child IDs:</b></td>
<td> $$x{'child_ids'} &nbsp;</td>
</tr>
<tr>
<td><b>Message IDs:</b></td> <td colspan=3> $$x{'message_ids'} &nbsp;</td>
</tr>
<tr>
<td><b>Ccs:</b></td><td colspan=3> $$x{'address_names'} &nbsp;</td>
</tr>
<tr>
<td><b>Note Ids:</b> $$x{'note_ids'} &nbsp;</td>
<td><b>Patch IDs:</b> $$x{'patch_ids'} &nbsp;</td>
<td><b>Change IDs:</b> $$x{'change_names'} &nbsp;</td>
<td><b>Test Ids:</b> $$x{'test_ids'} &nbsp;</td>
</tr>
<tr><td colspan=4> $$x{'help'} </td></tr>
<tr><td>$$x{'newnote'}</td><td colspan=2>$$x{'newpatch'}</td><td>$$x{'newtest'}</td></tr>
</table>
<table border=1 width=100%>
<tr> <td colspan=4> $$x{'body'}</td></tr>
</table>|;
	return ($top, $format, ());
}


=item new_id

Generate new_id for perlbug - YUK

=cut

sub new_id { # rf -> xxxx0827.007 ->19990827.007
    my $self = shift;
    my ($id, $ok) = ('', 1);
    my ($today) = $self->base->get_date();
    $self->debug(2, "new_id requested on '$today'") if $DEBUG;
    my $sth = $self->base->db->query("SELECT max(bugid) FROM pb_bugid");
    my $found = '';
    if (defined $sth) {
        ($found) = $sth->fetchcol(0);
        $self->debug(3, "Found bugid: '$found'.") if $DEBUG;
    } else {
        $self->debug(0, "Couldn't get max(bugid) FROM pb_bugid: $Mysql::db_errstr") if $DEBUG;
    }
    my ($date, $num) = ("", "");
    if ($found  =~ /^(\d{8})\.(\d{3})$/) { #
        ($date, $num) = ($1, $2);
        if (length($num) == 1) { $num = '00'.$num; }
        if (length($num) == 2) { $num = '0'.$num; } 
    } else {
        $ok = 0;
        $self->debug(0, "Can't find the latest ($found) id!") if $DEBUG;
        #or start a new one.
        $date = $today;
        $num = '001';
    }
    if (($date == $today) && ($ok == 1)) {
        if ($num >= 999) { # > just in case.
            $self->debug(0, "Ran out of bug ids today ($today) at: '$found'") if $DEBUG;
            $ok = 0;
        } else {
            $num++;
            #$num = sprintf("%03d", $num);
            if (length($num) == 1) { $num = '00'.$num; }
            if (length($num) == 2) { $num = '0'.$num; } 
        }
    } else {
        $num = '001';
    }
    if ($ok == 1) {
	    my $newid   = $today.'.'.$num;
	    my $update = "UPDATE pb_bugid SET bugid = '$newid' WHERE bugid = '$found'";
	    my $sth = $self->base->db->query($update);
	    if (defined($sth)) {
	        my $res = $sth->affected_rows;
	        if ($res) {
	            $id = $newid;
	            $self->debug(2, "New ID ($newid) generated.") if $DEBUG;
	        } else {
	            $self->error("Don't know what happened at pb_bugid update ($res)."); 
	        }
	    } else {
	        $self->error("Can't generate new ID ($newid), sth($sth), update($update): $Mysql::db_errstr"); 
	    }
	} else {
	    my $newid   = $today.'.'.$num;
	    my $insert = "INSERT INTO pb_bugid SET bugid = '$newid'";
	    my $sth = $self->base->db->query($insert);	
	    if (defined($sth)) {
	        my $res = $sth->affected_rows;
	        if ($res) {
	            $id = $newid;
	            $self->debug(2, "New ID ($newid) generated.") if $DEBUG;
	        } else {
	            $self->error("Don't know what happened at pb_bugid insert($res).");
	        }
	    } else {
	        $self->error("Can't insert new ID ($newid), sth($sth), insert($insert): $Mysql::db_errstr");
	    }
	}	
	$self->debug(2, "Returning new_id($id)") if $DEBUG;
    return $id;
}


=item get_id

Determine if the string contains a valid bug ID.

    my ($ok, $tid) = $obj->get_id($str);

=cut

sub get_id {
    my $self = shift;
    my $str = shift;
    my ($ok, $id) = (0, '');
    # /^\[[ID]*\s*(\d{8}\.\d{3})\s*\]$/ -> brackets ...?
    if ($str =~ /(\d{8}\.\d{3})/) { # no \b while _ is a letter?
        $id = $1;
        $ok = 1;
    }
    $self->debug(3, "str($str) -> $ok ($id)") if $DEBUG;
    return ($ok, $id);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;

