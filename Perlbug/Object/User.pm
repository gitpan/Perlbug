# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: User.pm,v 1.25 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::User - User class

=cut

package Perlbug::Object::User;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.25 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_User_DEBUG'} || $Perlbug::Object::User::DEBUG || '';
$|=1;


=head1 DESCRIPTION

Perlbug user class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Object;
use Perlbug::Base;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::User;

	print Perlbug::Object::User->read('richardf')->format('a');


=head1 METHODS

=item new

Create new User object:

	my $o_usr = Perlbug::Object::User->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'User',
		'match_oid'	=> '([a-zA-Z]+)',
		'from'		=> [qw(group)],
		'to'		=> [qw(bug)],
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=item updatable 

Check if current user object/s is/are allowed to be updated

Returns the updatable ids.

    print 'updatable: '.join(', ', $o_obj->updatable(\@userids));

=cut

sub updatable {
    my $self   = shift;

    my $a_uids = shift; # 
	my $user   = $self->base->isadmin;

	my @uids   = $self->SUPER::updatable($a_uids);

	if ($user ne $self->base->system('bugmaster')) {
		@uids = grep(/^$user$/, @{$a_uids});
	}

    return @uids;
}


=item insertid

Returns newly inserted id from recently created object.
	
	my $new_oid = $o_obj->insertid();

=cut

sub insertid {
	my $self = shift;

	my $oid = $self->data($self->attr('primary_key'));	
	$self->debug(0, "newly inserted userid($oid)") if $DEBUG;

	return $oid; 
}



=item htmlify 

html formatter for individual user entries for placement

    my $h_usr = $o_usr->htmlify($h_usr);

=cut

sub htmlify {
    my $self = shift;
    my $h_usr= shift || $self->_oref('data');
	return undef unless ref($h_usr) eq 'HASH';
    my $cgi = $self->base->cgi();
    my $url = $self->base->url;
    my %usr = %{$h_usr};
    my $userid  = $usr{'userid'};

    my $active  = ($usr{'active'} == 1) ? 1 : 0;
    my $address = ($usr{'address'});
    my $name    = $usr{'name'};

	my $o_grp = $self->object('group');
	my @mygids = $self->read($userid)->rel_ids('group');
    my $match_address = $usr{'match_address'};
    my $password = $usr{'password'};
	%usr = %{$self->SUPER::htmlify($h_usr)};	

    if ($self->base->isadmin && $self->updatable([$userid]) && $self->base->current('format') ne 'L') { 
		my @status = qw(1 0); push(@status, 'NULL') if $self->base->isadmin eq $self->base->system('bugmaster');
        $usr{'active'}        = $cgi->popup_menu(-'name' => $userid.'_active',    -'values' => \@status, -'labels' => {1 => 'Yes', 0 => 'No'}, -'default' => $active, -'override' => 1);
        $usr{'name'}          = $cgi->textfield( -'name' => $userid.'_name',      -'value' => $name, -'size' => 25, -'maxlength' => 50, -'override' => 1);
	    $usr{'address'}       = $cgi->textfield( -'name' => $userid.'_address',   -'value' => $address, -'size' => 35, -'maxlength' => 50, -'override' => 1);
		$usr{'group_ids'} 	  = $o_grp->selector($userid.'_groupids', @mygids).$usr{'group_ids'};
        $usr{'match_address'} = $cgi->textfield( -'name' => $userid.'_match_address', -'value' => $match_address, -'size' => 45, -'maxlength' => 55, -'override' => 1);
        $usr{'password_update'}= $cgi->checkbox( -'name'  =>$userid.'_password_update', -'checked' => '', -'value'=> 1, -'label' => '', -'override' => 1);
        $usr{'password'}      = $cgi->textfield( -'name' => $userid.'_password',  -'value' => $password, -'size' => 16, -'maxlength' => 16, -'override' => 1);
        $usr{'select'}        = $cgi->checkbox( -'name'  => 'userids', -'checked' => '', -'value'=> $userid, -'label' => '', -'override' => 1);
        $usr{'select'}       .= "&nbsp;($userid)";
    } else {
        $usr{'active'}        = ($active) ? '*' : '-';
		my ($addr) = $self->parse_addrs([$address]);
        $usr{'address'}       = qq|<a href="mailto:$addr">$address</a>|;
        $name = "<b>$name</b>" if $active;
        $usr{'name'}          = qq|<a href="perlbug.cgi?req=user_id&user_id=$userid">$name</a>|;
        $usr{'password'}      = '-';
        $usr{'match_address'} = '-';
        $usr{'userid'}        = '';
    }
	# print '<pre>'.Dumper(\%usr).'</pre>';
    return \%usr;
}
 

=head1 FORMATS

Formatters for all occasions...


=item FORMAT_l

Lean (list) ascii format for users

	my ($top, $format, @args) = $o_usr->FORMAT_l(\%data);

=cut

sub FORMAT_l { # 
	my $self = shift;
	my $x = shift; # 
	my @args = ( 
		$$x{'userid'}, 		$$x{'active'}, 		
		$$x{'bug_count'}, 	$$x{'group_count'},	
		$$x{'address'},
	);
	my $top = qq|
User ID    Active Bugs  Groups Address |;
	my $format = qq|
@<<<<<<<<  @<<<<  @<<<  @<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
|; 
	return ($top, $format, @args);
}


=item FORMAT_a

ascii format for users

	my ($top, $format, @args) = $o_usr->FORMAT_a(\%data);

=cut

sub FORMAT_a { # 
	my $self = shift;
	my $x = shift; # 
	my @args = ( 
		$$x{'userid'}, 		$$x{'active'}, 		
		$$x{'bug_count'}, 	$$x{'group_count'},	
		$$x{'name'},
		$$x{'created'},		$$x{'address'}, 	
		$$x{'group_ids'},
	);
	my $top = qq|
User ID    Active Bugs  Groups    Name 
--------------------------------------------------------------------------------|;
	my $format = qq|
@<<<<<<<<  @<<<<  @<<<  @<<<      @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
Created:   @<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
Groups:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
|; 
	return ($top, $format, @args);
}


=item FORMAT_A

ASCII format for users

	my ($top, $format, @args) = $o_usr->FORMAT_A(\%data);

=cut

sub FORMAT_A {
	my $self = shift;
	my $x = shift; # 
	my @args = ( 
		$$x{'userid'}, 		$$x{'active'}, 		
		$$x{'bug_count'}, 	$$x{'group_count'},	
		$$x{'name'},
		$$x{'created'},		$$x{'address'}, 	
		$$x{'group_ids'},
		$$x{'password'},	$$x{'match_address'},
		$$x{'bug_ids'},
	);
	my $top = qq|
User ID    Active Bugs  Groups    Name 
--------------------------------------------------------------------------------|;
	my $format = qq|
@<<<<<<<<  @<<<<  @<<<  @<<<      @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
Created:   @<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
Groups:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
@<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
@* 
|; 
	return ($top, $format, @args);
}


=item FORMAT_L

Lean html format for users:
	
	my ($top, $format, @args) = $o_usr->FORMAT_L(\%data);

=cut

sub FORMAT_L {
	my $self = shift;
	return $self->FORMAT_h(@_); # rjsf temp
}


=item FORMAT_h

html format for users:
	
	my ($top, $format, @args) = $o_usr->FORMAT_h(\%data);

=cut

sub FORMAT_h { # 
	my $self = shift;
	my $x    = shift; # 
	my @args = ( 
		$$x{'select'},
		$$x{'name'}, 		$$x{'active'}, 		
		$$x{'bug_count'},   $$x{'address'}, 	
		$$x{'password'},	$$x{'match_address'},
		$$x{'group_names'},
	);
	my $top = qq|<tr>
<td width=35><b>&nbsp;</b></td>
<td width=35><b>Name</b></td>
<td width=15><b>Active?</b></td>
<td><b>Bugs</b></td>
<td><b>Address</b></td>
<td><b>Password</b></td>
<td><b>Match Address</b></td>
<td><b>Groups</b></td>
</tr>
|;
	my $format = '<tr><td>'.join('&nbsp;</td><td>', @args).'&nbsp;<td></tr>';	
	return ($top, $format, @args);
}


=item FORMAT_H

HTML format for users:
	
	my ($top, $format, @args) = $o_usr->FORMAT_H(\%data);

=cut

sub FORMAT_H {
	my $self = shift;
	# my $x = shift;
	my ($top, $format, @args) = $self->FORMAT_h(@_); # rjsf temp
	# $format .= "<tr><td><b>Bug IDS</b></td><td>$$x{'bug_ids'}</td></tr>";
	return ($top, $format, @args);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;

