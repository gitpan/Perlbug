# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: User.pm,v 1.36 2002/02/01 08:36:47 richardf Exp $
#

=head1 NAME

Perlbug::Object::User - User class

=cut

package Perlbug::Object::User;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.36 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
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

=over 4

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
		'to'		=> [qw(bug template)],
	);

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

=item create 

Check if name is unique

    my $o_usr = $o_usr->create(\%data);

=cut

sub create {
    my $self   = shift;
	my $h_data = shift || $self->_oref('data');

	my $proposed = $$h_data{'userid'};
	my ($extant) = $self->ids("userid = '$proposed'");

	if ($extant) {
		$self->debug(0, 'disallowed user data: '.Dumper($h_data)) if $Perlbug::DEBUG;
		$h_data = undef;
		print "<h3>\nCan't create a non-unique userid($proposed) while extant($extant)!\n</h3><hr>\n";
	}

	$self->SUPER::create($h_data) if $h_data;

    return $self;
}


=item new_id

return given userid for user 

=cut

sub new_id {
	my $self = shift;

	my $newid = shift || 'NULL';
	$self->debug(1, 'new '.ref($self)." objectid($newid)") if $Perlbug::DEBUG;
	
	return $newid;
}

=item htmlify 

html formatter for individual user entries for placement

    my $h_usr = $o_usr->htmlify($h_usr);

=cut

sub htmlify {
    my $self = shift;
    my $h_usr= shift || $self->_oref('data');
	my $req  = shift || 'admin';
	return undef unless ref($h_usr) eq 'HASH';
    my $cgi = $self->base->cgi();
    my $url = $self->base->myurl;
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

    if ($self->base->isadmin && $self->updatable([$userid]) && $self->base->current('format') ne 'L' && $req ne 'noadmin') { 
		my @status = qw(1 0); push(@status, 'NULL') if $self->base->isadmin eq $self->base->system('bugmaster');
        $usr{'active'}        = $cgi->popup_menu(-'name' => $userid.'_active',    -'values' => \@status, -'labels' => {1 => 'Yes', 0 => 'No'}, -'default' => $active, -'override' => 1);
        $usr{'name'}          = $cgi->textfield( -'name' => $userid.'_name',      -'value' => $name, -'size' => 25, -'maxlength' => 50, -'override' => 1);
	    $usr{'address'}       = $cgi->textfield( -'name' => $userid.'_address',   -'value' => $address, -'size' => 35, -'maxlength' => 50, -'override' => 1);
		$usr{'group_ids'} 	  = $o_grp->choice($userid.'_groupids', @mygids).$usr{'group_ids'};
        $usr{'match_address'} = $cgi->textfield( -'name' => $userid.'_match_address', -'value' => $match_address, -'size' => 45, -'maxlength' => 55, -'override' => 1);
        $usr{'password'}      = $cgi->textfield( -'name' => $userid.'_password',  -'value' => $password, -'size' => 16, -'maxlength' => 16, -'override' => 1);
        $usr{'select'}        = $cgi->checkbox( -'name'  => 'userids', -'checked' => '', -'value'=> $userid, -'label' => '', -'override' => 1);
        $usr{'select'}       .= "&nbsp;".$usr{'userid'};
    } else {
        $usr{'active'}        = ($active) ? '*' : '-';
		my ($addr) = $self->parse_addrs([$address]);
        $usr{'address'}       = qq|<a href="mailto:$addr">$address</a>|;
        $name = "<b>$name</b>" if $active;
        $usr{'name'}          = qq|<a href="perlbug.cgi?req=user_id&user_id=$userid">$name</a>|;
        $usr{'password'}      = '-';
        $usr{'match_address'} = '-';
        $usr{'userid'}        = '&nbsp;';
    }
	# print '<pre>'.Dumper(\%usr).'</pre>';
    return \%usr;
}

=item update

Ensure the password is encrypted

	$o_usr->update(\%data);

=cut

sub update {
	my $self = shift;
	my $h_data = shift || $self->_oref('data');

	my $pri = $self->attr('primary_key');
	my $uid = $$h_data{$pri};
	$self->debug(1, "here($pri=$uid): ".Dumper($h_data)) if $Perlbug::DEBUG;

	my $password = $$h_data{'password'} || '';
	if ($password =~ /^(.+)$/) {
		my ($dbpass) = $self->col('password', "userid = '$uid'");
		if ($dbpass ne $password) { # been modified
			$self->debug(1, "given($password) ne dbpass($dbpass) updating...") if $Perlbug::DEBUG;
			$$h_data{'password'} = crypt($password, substr($password, 0, 2));
			# my $i_ok = $self->base->htpasswd($uid, $password);
		}
	}

	my $match = $$h_data{'match_address'} || '';
	if ($match =~ /^(.+)$/) {
		my ($dbmatch) = $self->col('match_address', "userid = '$uid'");
		if ($dbmatch ne $match) { # been modified
			$self->debug(1, "given($match) ne dbmatch($dbmatch) quoting...") if $Perlbug::DEBUG;
			$$h_data{'match_address'} = $self->base->db->quote($match);
		}
	}

	return $self->SUPER::update($h_data);
}

=item webupdate

Update user data via web interface, accepts relations via param('_opts')

	$oid = $o_usr->webupdate(\%cgidata, $oid);

=cut

sub webupdate {
	my $self   = shift;
	my $h_data = shift;
	my $oid    = shift;
    my $cgi    = shift || $self->base->cgi();

	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires data hash ref($h_data) to update ".ref($self)." data via the web!");
	} else {
		if ($self->read($oid)->READ) {
			$self->debug(1, "oid: ".$self->oid) if $Perlbug::DEBUG;
			my $pri = $self->attr('primary_key');
			$$h_data{$pri} = $oid;
			my $i_updated = $self->update($h_data)->UPDATED; # internal debugging
			if ($i_updated == 1) {
				$self->SUPER::webupdate($h_data, $oid);
			}
		}
	}
	
	return $oid;
}

=pod
			if ($uid ne 'newAdmin') {
				$o_usr->read($uid)->update(\%data);
			} else { 
				if ($self->isadmin eq $self->system('bugmaster')) {
					$o_usr->create({
						'userid'	=> $userid,
						%data,
					});
					$NEWID = $uid = $o_usr->read($userid)->oid if $o_usr->CREATED;
				}
			}
=cut

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut

1;

