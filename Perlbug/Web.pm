# Perlbug WWW interface
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Web.pm,v 1.66 2000/10/30 16:21:57 perlbug Exp perlbug $
#
# TODO: newnote, newtest, newpatch
# 

=head1 NAME

Perlbug::Web - Web interface to perlbug database.

=head1 DESCRIPTION

Methods for web access to perlbug database via L<Perlbug> module.

=cut

package Perlbug::Web; 
use lib qw(../);
use vars qw($VERSION);
use CGI;
use CGI::Carp 'fatalsToBrowser';
use Data::Dumper;
use HTML::Entities;
use Perlbug::Base; 
use URI::Escape;
@ISA = qw(Perlbug::Base);
use strict;
$| = 1; 

$VERSION = 1.64;

=head1 SYNOPSIS

	my $o_web = Perlbug::Web->new;
	
	print $o_web->header;
	
	print $o_web->request('help');
	
	print $o_web->footer;
	

=head1 METHODS

=over 4

=item new

Create new Perlbug::Web object.

	my $web = Perlbug::Web->new;

=cut

sub new {
	my $class = shift;
	my $self  = Perlbug::Base->new(@_);
	$self->{'CGI'} = CGI->new(@_);
	bless($self, $class);
    $self->check_user($ENV{'REMOTE_USER'});
    $self->setup; # default pars etc.
	return $self;
}


=item setup

Setup Perlbug::Web

    $o_perlbug->setup($cgi);

=cut

sub setup {
    my $self = shift;
    my $cgi  = $self->{'CGI'};
	
    # Ranges
    my $rngpar = $self->{'attr'}{'current_range'} = $cgi->param('range') || '';
	my $src = $self->directory('spool')."/ranges/${rngpar}.rng";
	if ((defined($rngpar)) && (-e $src)) {  # reuse it
		my $tgt = $self->directory('spool')."/ranges/$$.rng";
		my $ok = $self->copy($src, $tgt);
	} else {                                # create it
		$self->append('rng', ''); 
	}
    
    # Vars    
	$self->current('debug',  $cgi->param('debug')  ||  0);
    $self->context('h');
	$self->current('format', $cgi->param('format') || 'h');
	
    # Context
    $self->{'attr'}{'current_buttons'} = '';
    $self->{'attr'}{'PRE'} = '';
    $self->{'attr'}{'POST'} = '';
    return $self;
}


=item check_user

Access authentication via http, we just prime ourselves with data from the db as well.

Should really be integrated as a database lookup via Apache, but we do not know this will be the webserver?

=cut

sub check_user { 
	my $self = shift;
	my $remote_user = shift || '';
	my $user = '';
    if (defined($ENV{'REQUEST_URI'}) && ($ENV{'REQUEST_URI'} =~ /\/admin/i)) {
		$user = $self->SUPER::check_user($remote_user); # Base
		$self->debug(1, "Checked user($remote_user)->'$user'");
	} else {
		$user = $self->SUPER::check_user(''); # Base
		# $user = $self->current('admin', '');
		$self->debug(2, "Neutralising user($remote_user)->$user");
	}
	return $user; 
}


=item header


Return consistent header.

	print $web->header;

=cut

sub header { #web 
    my $self = shift;
    my $cgi  = $self->{'CGI'};
	my $hdr  = '';
    if ($cgi->param('req') eq 'graph') {
		$hdr = $self->{'CGI'}->header('image/png');	
    } else {
		my $head = $self->{'CGI'}->header(-'expires'=>'+10m');
		my $url  = $self->url;
		my $header = $self->read('header');
		$header =~ s/Perlbug::VERSION/ - v$Perlbug::VERSION/i;
		my $user = $self->isadmin;
		if ($user eq $self->system('bugmaster')) {
			$header =~ s/$Perlbug::VERSION/$Perlbug::VERSION - user($user)/i;
		} 
		$hdr = qq|$head $header
			<form method="post" action="$url">
		|;
	}
    return $hdr;
}


=item switch

Parse switch

=cut

sub switch {
    my $self = shift;
    my $cgi  = $self->{'CGI'}; 
    my $req  = $cgi->param('req'); 
    my $switch = ($req =~ /\w+/) ? $req : 'help';
    return $switch;
}


=item request

Handle all web requests

=cut

sub request {
    my $self = shift;
    my $ok   = 1;
    my $cgi  = $self->{'CGI'};
    my $req  = $cgi->param('req');
    # supported methods
    if (defined($req)) {
        if ($req eq 'query') { # special case *** YUK
            $req = 'web_query';
        }
    } else { # default
        $req = 'search';
    }
    my $result = '';
	my $meth = join('|', qw(administrators adminfaq bid bidmids delete graph help hist mid mheader nid nheader nocc overview patches pheader pid search spec sql_query tid theader todo uid update web_query));
    if ((defined($req)) && ($req =~ /^($meth)$/)) {
        my $request = $1;
        $self->debug(1, "Web::request($req) accepted -> '$request'");
        if ($self->can($request)) {
            $self->debug(3, "Can call -> '$request'");
            if ($request =~ /^delete|sql_query|update$/i) {
                if ($self->isadmin) {
                    $ok = $self->$request($cgi);
                } else {
                    $ok = 0;
	                my $user = $self->current('admin');
                    $result = "<h3>User ($user) not permitted for action '$request'</h3>";
                }
            } else {
		        $ok = $self->$request($cgi);
            }	
            if ($ok == 1) {
            	$result = ($request eq 'graph') ? 'graph' : $self->get_results;
            	$self->debug(0, "request($request) -> '$ok'");
	        } else {
				my $err = "Request($request) unexpectedly returned '$ok'";
				$self->debug(0, $err); carp($err);
			}
        } else {
            $result = "Unable to do '$request'";
            $self->debug(0, "$self 'can' not do '$request'");
        }
    } else {
        $result = "Invalid request ($req)";
        $self->debug(0, "Invalid CGI ($cgi) request ($req) for methods available: ($meth)");
    }
    return $result;
}


=item overview

Wrapper for doo method

=cut

sub overview {
    my $self = shift;
    return $self->doo();
}


=item graph

Display pie or mixed graph for category of bugs etc., mixed to come.

=cut

sub graph {
	my $self = shift;
	my $cgi  = shift;
	my $flag = $cgi->param('graph') || 'status';
 	my $status = 0;	

	# DATA 
	my @keys = ();
	my @vals = ();
	my $data = $self->stats;
	foreach my $key (keys %{$$data{$flag}}) {
		next unless $key =~ /^(\w+)$/;
		next unless $$data{$flag}{$key} =~ /^(\d+)$/;
		push(@keys, "$key ($$data{$flag}{$key})");
		push(@vals, $$data{$flag}{$key});
	}

	# GRAPH
	eval { require GD::Graph::pie; }; # make non-fatal at least until required :-)
	if ($@) {
		my $maintainer = $self->system('bugmaster');
		$self->result("Graph functionality unsupported, talk to the webmaster($maintainer) :-(");
		$self->debug(0, "Failed to load GD::Graph $!");
 		$status = 0;
	} else {	
		my $gd = GD::Graph::pie->new(300, 300);       
		#        'types'        => [qw(pie lines bars points area linespoints)],
		#        'default_type' => 'points',
		#);
		#$gd->set_legend( qw( one two three four five six )); # mixed or points only?
		$gd->set(
			'axislabelclr'     => 'black',
			'title'            => "Perlbug overview ($flag)",
		);
		my $graph = $gd->plot([\@keys, \@vals]); 
		my $image = $graph->png; 
		binmode STDOUT;
		print $image;
 		$status = 1;
	}

	return $status;
}

=item nid

Wrapper for don note access

=cut

sub nid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @nids = $cgi->param('nid');
    $self->debug(1, "nid: nids(@nids)");
    my $a_buttons = ($self->can_update(\@nids)) ? [qw(reset update)] : [];
    $self->current_buttons($a_buttons, scalar(@nids));
    
	$self->result('<table border=1>');
    $self->don(\@nids);		
    $self->result('</table>');
    return $ok;
}

=item tid

Wrapper for dot test id access

=cut

sub tid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @tids = $cgi->param('tid');
    $self->debug(1, "tid: tids(@tids)");
	my $a_buttons = ($self->can_update(\@tids)) ? [qw(update nocc reset delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@tids)));
	
    $self->result('<table border=1>');
    $self->dot(\@tids);		
    $self->result('</table>');
    return $ok;
}

=item pid

Wrapper for dop patch id access

=cut

sub pid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @pids = $cgi->param('pid');
    $self->debug(1, "pid: pids(@pids)");
	my $a_buttons = ($self->can_update(\@pids)) ? [qw(update nocc reset delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@pids)));
	
    $self->result('<table border=1>');
    $self->dop(\@pids);		
    $self->result('</table>');
    return $ok;
}


=item bid

Wrapper for dob bugid access

=cut

sub bid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @bids = $cgi->param('bid');
    $self->debug(1, "bid: bids(@bids)");
	my $a_buttons = ($self->can_update(\@bids)) ? [qw(update nocc reset delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@bids)));
	
    $self->result('<table border=1>');
    $self->dob(\@bids);		
    $self->result('</table>');
    return $ok;
}


=item patches

Wrapper for dop patchid access

=cut

sub patches {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @pats = $cgi->param('patches');
    $self->debug(1, "patches(@pats)");
    my $a_buttons = ($self->can_update(\@pats)) ? [qw(update reset)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@pats)));
    $self->result('<table border=1>');
    $self->dop(\@pats);		
    $self->result('</table>');
    return $ok;
}


=item uid

Wrapper for dou user/administrator access

=cut

sub uid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @uids = $cgi->param('uid');
    $self->debug(1, "uid: uids(@uids)");
    my $a_buttons = ($self->can_update(\@uids)) ? [qw(reset update delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@uids)));
    $self->result('<table border=1>');
    $self->dou(\@uids);		
    $self->result('</table>');
    return $ok;
}


=item hist

History mechanism for bugs and users.

Move formatting to Format::history !!!

=cut

sub hist {
    my $self = shift;
    my $cgi = shift;
    my ($bid) = $cgi->param('hist');
    $self->debug(1, "hist: bid($bid)");
    my ($bik) = $self->href('bid', [$bid], $bid);
    my $title = $self->system('title');
    my $ok = 1;
    my $hist = qq|<table border=1>
        <tr><td colspan=3 width=500><b>$title bug ($bik) history</td/></tr>
        <tr><td><b>Admin</b></td><td><b>Entry</b></td><td><b>Modification</b></td></tr>
    |;
    my $sql = "SELECT *, from_unixtime(unix_timestamp(ts)) FROM tm_log WHERE objecttype = 'b' AND objectid = '$bid' ORDER BY ts DESC"; 
    my @data = $self->get_data($sql);
    foreach my $data (@data) {
	next unless ref($data) eq 'HASH';
	my %data = %{$data};
	my $admin = $data{'userid'};
	if (defined $admin && $admin =~ /^(\w+)$/) {
        my %admin = %{$self->user_data($admin)};
        $admin = qq|<a href="mailto:$admin{'address'}">$admin{'name'} &nbsp; $admin{'address'}</a>|;
	    # $self->debug(5, "admin($admin)");
	}
	my $date = $data{'ts'};
	# $hist .= qq|<tr><td>$admin</td><td>$data{'entry'}</td><td>$data{'date'}</td></tr>|;	
	$hist .= qq|<tr><td>$admin</td><td>$data{'objecttype'} &nbsp; $data{'entry'}</td><td>$data{'from_unixtime(unix_timestamp(ts))'}</td></tr>|;	
	#$self->debug(5, "data($data)");
    }
    $hist .= '</table>';
    $self->result($hist);
    return $ok;
}


=item headers 

Headers for all objects (m, n, p, t) by id 

=cut

sub headers {
    my $self = shift;
	$self->debug('IN', @_);
	my $obj = shift;
	my $id  = shift;
    my $ok = 1;
	my %hdr = (
		'm' => 'message',
		'n' => 'note',
		'p' => 'patch',
		't' => 'test',
	);
	if (!($id =~ /^\w+$/ && grep(/^$obj$/, keys %hdr))) {
		$ok = 0;
		$self->debug(0, "Can't do invalid obj($obj) id($id)");
	} else {
    	my ($item) = $self->href($obj.'id', [$id], $id);
    	my $title = $self->system('title');
    	my $headers = qq|<table border=1>
        	<tr><td colspan=3 width=500><b>$title $hdr{$obj} ($item) headers</td/></tr>
    	|;
		my $table = $hdr{$obj};
    	my $sql = "SELECT msgheader FROM tm_$table WHERE $hdr{$obj}id = '$id'";
    	my @data = $self->get_list($sql);
    	$headers .= "<tr><td colspan=3>&nbsp;";
		foreach my $data (@data) {
	    	next unless $data =~ /\w+/; 
        	$data = encode_entities($data);
			$headers .= qq|<tr><td><pre>$data &nbsp;</pre></td></tr>|;	
    	}
    	$headers .= '</td></tr></table>';
    	$self->result($headers);
    }
	$self->debug('OUT', $ok);
	return $ok;
}


=item mheader

Headers for message

=cut

sub mheader {
    my $self = shift;
    my $cgi = shift;
    my ($id) = $cgi->param('mheader');
	my $ok = $self->headers('m', $id);
    return $ok;
}


=item pheader

Headers for patches

=cut

sub pheader {
    my $self = shift;
    my $cgi = shift;
    my ($id) = $cgi->param('pheader');
	my $ok = $self->headers('p', $id);
    return $ok;
}

=item nheader

Headers for notes

=cut

sub nheader {
    my $self = shift;
    my $cgi = shift;
    my ($id) = $cgi->param('nheader');
	my $ok = $self->headers('n', $id);
    return $ok;
}

=item theader

Headers for tests

=cut

sub theader {
    my $self = shift;
    my $cgi = shift;
    my ($id) = $cgi->param('theader');
	my $ok = $self->headers('t', $id);
    return $ok;
}


=item bidmids

Wrapper for bugid and messageid access

=cut

sub bidmids {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my ($bid) = $cgi->param('bidmids');
    $self->debug(1, "bidmids: bid($bid)");
    my $a_buttons = ($self->can_update([$bid])) ? [qw(update nocc reset delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar($bid)));
	$self->result('<table border=1>');
	$self->doB([$bid], '</table>');
    return $ok;
}


=item mids

Wrapper for retrieve by messageid access

=cut

sub mid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @mids = $cgi->param('mid');
    $self->debug(1, "mid: mids(@mids)");
    my $a_buttons = ($self->can_update(\@mids)) ? [qw(update reset delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@mids)));
    $self->dom(\@mids);
    return $ok;
}


=item delete

Wrapper for delete access

=cut

sub delete {
    my $self = shift;
    my $cgi = shift;
    my $res = 0;
	my @bugids = $cgi->param('bugids');
	if (scalar @bugids >= 1) {
	 	$res = $self->doX([@bugids]);
		if ($res >= 1) {
			$self->result("bugids (@bugids) succesfully deleted");
		} else {
			my $maintainer = $self->system('maintainer');
			$maintainer = qq|<a href="mailto: $maintainer">$maintainer</a>|;
			$self->result("<hr>bugids not entirely deleted, please report this to the administrator: $maintainer");
			$self->result('<table border=1>');
			$self->dob(@bugids); 
			$self->result('</table>');
		}
    } else {
		if ($cgi->param('userids') >= 1) {	
			my $maintainer = $self->system('maintainer');
			$self->result("Cannot delete adminstrator from web interface, see maintainer($maintainer)");
		} else {
			$self->result("No bugids (@bugids) selected for deletion?");
		}
	}
	return 1;
}


=item update

Wrapper for update access

=cut

sub update {
    my $self = shift;
    my $res = $self->web_update;
	return $res;
}

=item nocc

Wrapper for nocc update access

=cut

sub nocc {
    my $self = shift;
    my $res = $self->web_update('nocc');
	return $res;
}


=item sql_query

Open field sql query processor

=cut

sub sql_query {
    my $self = shift;
    my $cgi = shift;
    my $sql = $cgi->param('sql_query');
    $sql =~ s/^\s*\w+(.*)$/SELECT $1/;
    my ($res) = $self->doq($sql);
    return $res;
}


=item web_query

Form bug search web query results

=cut

sub web_query {	# results
    my $self = shift;
	$self->debug('IN', @_);
    my $cgi = shift;
    my $result = '';
	my $ok = 1;
    my $sql = $self->format_web_query($cgi);
    my @bids = $self->get_list($sql);
    my $found = scalar @bids;
    $self->result("Found $found bugs");
	if ($found >= 10) {
        my $trim = $cgi->param('trim');
        $self->result(" showing '$trim'<br>") if $trim =~ /\d+/ and $trim <= $found;
        if (($trim !~ /^\d+$/) || ($trim >= 10001)) {
            $trim = 10000;
        }
        $self->tenify(\@bids, $trim); 
        if ($trim =~ /\d+/) {
            $#bids = $trim - 1;
        }
    } 
    my $a_buttons = ($self->can_update(\@bids)) ? [qw(update nocc reset delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@bids)));
	$self->result('<table border=1>');
    my $res = $self->dob(\@bids);
	$self->result('</table>');
	$self->debug('OUT', $ok);
    return $ok;
}


=item current_buttons

Returns array of relevant buttons by context key 

    my @buttons = $o_web->current_buttons('search update reset', scalar(@uids), [$colspan]);

=cut

sub current_buttons {
    my $self = shift;
	$self->debug('IN', @_);
	my $akeys= shift;       # [submit query update]
    my $items= shift;       # num of bids/uids/etc. 
    my $span = shift || 8;  # number of bug fields
	my $cgi  = $self->{'CGI'};
    my @keys = (ref($akeys) eq 'ARRAY') ? @{$akeys} : split $akeys;
	$self->debug(2, "current_buttons args: keys(@keys), items($items), span($span)");
	if ((scalar(@keys) >= 1) && ($items >= 1) && ($self->current('format') !~ /^[aAL]$/)) { 
		my %map = (
			'delete'    => $cgi->submit(-'name' => 'req', -'value' => 'delete'),
            'reset'     => $cgi->defaults('reset'),
            'search'    => $cgi->submit(-'name' => 'req', -'value' => 'query'),
	        'sql_query' => $cgi->submit(-'name' => 'req', -'value' => 'sql_query'),
	        'update'    => $cgi->submit(-'name' => 'req', -'value' => 'update'),
	        'nocc'      => $cgi->submit(-'name' => 'req', -'value' => 'nocc'),
	    );
        my $buttons = '';
        foreach my $key (@keys) {
		    $buttons .= "&nbsp; $map{$key}";
    	} 
        $self->{'attr'}{'current_buttons'} = qq|<table border=0><tr><td colspan="$span"><br>$buttons &nbsp;</td></tr></table>|;
	}   
	$self->debug('OUT', $self->{'attr'}{'current_buttons'});
	return $self->{'attr'}{'current_buttons'};
}


=item footer

Return consistent footer.

	print $web->footer;

=cut

sub footer { 
    my $self    = shift;	
    my $cgi     = $self->{'CGI'};
    my $fmt     = $self->current('format');
    my $x_fmt   = ($cgi->param('req') eq 'search') ? '' : qq|<input type="hidden" name="format" value="$fmt">|;
    my $x_rng   = qq|<input type="hidden" name="range" value="$$">|;
    my $buttons = $self->current_buttons;
    my $hidden  = ''; # $self->hidden_parameters; # if not set
    my $range   = $self->read('rng');
    my $footer  = $self->read('footer');
    if ($self->isadmin) {
		$footer =~ s/\Q<!-- FAQ -->\E/<td><a href="perlbug.cgi?req=adminfaq">FAQ<\/a><\/td>/;
	} else {
		$footer =~ s/\Q<!-- FAQ -->\E/<td>&nbsp;<\/td>/; # userfaq
	}
	my $dump    = ($self->current('debug') >= 2) ? $cgi->dump : '';
	my $data    = "</table>$buttons <hr>$range $footer $x_rng $x_fmt $hidden</form> $dump".$cgi->end_html;
    return $data;
}


=item administrators

List of administrators

=cut

sub administrators {
    my $self  = shift;
    my $cgi   = $self->{'CGI'};
    my $url   = $self->url;
    my $title = $self->system('title');
    $self->result(qq|<table border=0><tr><td colspan=2><b>$title administrators:</td/></tr>|);
    my $get = "SELECT userid FROM tm_user";
	$get .= " WHERE active != 'NULL'" unless $self->isadmin eq $self->system('bugmaster');
	my @admins = $self->get_list($get);
    
    my $a_buttons = ($self->can_update(\@admins)) ? [qw(update reset delete)] : [];
    $self->result($self->current_buttons($a_buttons, scalar(@admins)));
	$self->dou(\@admins); # inc. format
    my $ADMIN = '';
    if ($self->isadmin eq $self->system('bugmaster')) {
        my $hidden = qq|<input type=hidden name=newAdmin_password_update value=1>|;
        $ADMIN = qq|<tr><td colspan=5><hr><b>New User:</b></td></tr>\n<tr><td>|.
    join("</td></tr>\n<tr><td>",
                                    $cgi->checkbox( -'name' => 'userids',           -'value'=> 'newAdmin',  -'label' => '',             -'checked' => '', -'override' => 1),
    'Userid:&nbsp; </td><td>'.      $cgi->textfield(-'name' => 'newAdmin_userid',   -'value' => '',         -'label' => 'userid',       -'size' => 10,  -'maxlength' => 10, -'override' => 1),
    'Name:&nbsp; </td><td>'.        $cgi->textfield(-'name' => 'newAdmin_name',     -'value' => '',         -'label' => 'name',         -'size' => 25,  -'maxlength' => 50, -'override' => 1),
    'Active:&nbsp; </td><td>'.      $cgi->popup_menu(-'name'=> 'newAdmin_active',   -'values' => [1, 0],    -'labels' => {1 => 'Yes', 0 => 'No'},       -'default' => 0, -'override' => 1),
    'Password:&nbsp; </td><td>'.    $cgi->textfield(-'name' => 'newAdmin_password', -'value' => '',         -'label' => 'password',     -'size' => 16,  -'maxlength' => 16, -'override' => 1),
    'Address:&nbsp; </td><td>'.     $cgi->textfield(-'name' => 'newAdmin_address',  -'value' => '',         -'label' => 'address',      -'size' => 35,  -'maxlength' => 50, -'override' => 1),
    'Match Adress:&nbsp; </td><td>'.$cgi->textfield(-'name' => 'newAdmin_match_address', -'value' => '',    -'label' => 'match_address', -'size' => 35, -'maxlength' => 50, -'override' => 1),
        );
        $ADMIN .= '</td></tr>';
    }
    $self->result($ADMIN.'</table>');
    return 1;
}


=item spec

Returns specifications for the Perlbug system.

=cut

sub spec {
    my $self    = shift;
	my ($perlbug_spec) = $self->SUPER::spec; # Base
	$perlbug_spec =~ s/\</&lt;/g;
	$perlbug_spec =~ s/\>/&gt;/g;
	$perlbug_spec =~ s/\b(http\:.+?perlbug\.cgi)\b/<a href="$1">$1<\/a>/gi;
	$perlbug_spec =~ s/\b([\<\w+\-_\.\>|\&.t\;]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;
	my $spec = "<table align=center><tr><td><pre>$perlbug_spec</pre></td></tr></table>";
	$self->result($spec);
    return 1;
}


=item help

Web based help menu for perlbug.

	print $web->help;

=cut

sub help { #web help 
	my $self = shift;
	my $url  = $self->url;
	my $email = $self->email('domain');
	my $bugdb = $self->email('bugdb');
	my ($perlbug_help) = $self->SUPER::help; # Base
	my ($total) = $self->get_list("SELECT COUNT(*) FROM tm_bug");
	$perlbug_help =~ s/\b(http\:.+?perlbug\.cgi(?:\?.+)*)*\b/<a href="$1">$1<\/a>/gi;
	$perlbug_help =~ s/\b([\<\w+\-_\.\>]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;
	my $help = qq#<table align=center><tr><td><pre>$perlbug_help</pre><hr></td></tr></table>
<table border=0 align=center><tr><td>
<b>Searching:</b><br>
The search mask has no pre-selected entries, click <b>query</b> and an indiscriminate 
list of all the bugs in the database (currently $total) will be returned.  Filterering is achieved by selecting options from the popup menus, or entering data in the text fields.

<p>
<b>Note:</b><br>
All text fields are searched using the SQL <b>LIKE</b> operator (see <i>SQL wildcards</i> below). <br>
<i>Bug</i>, <i>version</i>, <i>patch|change id</i> and <i>fixed in</i> fields are used as seen, 
that is, if a wildcard is not provided, one will not be used.<br>
Conversly <i>subject</i>, <i>body</i> and <i>source address</i> fields have '<i>%</i>' pre-placed 
around the search query by default.<br><br>
What this means is that entering '<b>20001122.</b>', in the bugid field, will probably not return much, but '<b>20001122.%</b>' might.<br>
Of course a complete bugid could be entered on it's own eg: '<b>20001122.003</b>'.<br><br>
Whereas entering only '<i>strict</i>' in the subject field will still use '<b>%strict%</b> during the search.
<p>

<b>SQL wildcards:</b><br>
The available SQL wildcards: <i>any single character</i>(<b>_</b>) and <i>none or more characters</i>(<b>%</b>) are allowed in all fields. <br>
Note also that for convenience, an asterisk(<b>*</b>) will be simply mapped to the sql wildcard '<b>%</b>'.<br><br>
N.B. It can be a good idea to use the Show SQL switch to display what's being searched for. 
<p>

<b>Results</b><br>
Bugs are initially returned in either <b>list</b> or <b>block</b> format, with an optional trimming mechanism which defaults to 25.<br>
At the base of the page is a list of all the other bugs found during the query, sectioned into similarly managable portions.<br>
The list format is designed for quickly moving around a list of bugs, while the block format is aimed at finding all information relating to said bug, without having to hop around.<br><br>

The bug minimally displays it's <b>status</b>, <b>category</b>, <b>OS</b>, <b>severity</b>, which <b>version</b> it was filed against, and the subject of the initial mail.<br><br>
Additionally links are provided to find each individual <b>message</b> attributed to each bug, (including the relevant mail headers), which <b>administrator</b> is assigned and what the command <b>history</b> has been.  <br><br>

There are also links to other (<b>parent/child</b>) bugs, all email addresses appearing on the <b>Cc:</b> list of the bug, <b>Tests</b> against each bug and <b>notes</b> from when an administrator closed or otherwise dealt with the bug.<br>
<b>Patches</b> may be attributed to bugs which are then downloadable.<br>
<p>
<b>Hints:</b>
For further information, check out <a href="$url?req=spec">specs</a> and for help using the email interface send an email to: '<b><a href="mailto:help\@$email">help\@$email</a></b>' <p>
<p>
</td></tr></table>
#;
	my $admin = qq#
<hr>
<table border=0 width=100%>
<b>Administration:</b><br>
Bugs must be selected using the checkbox before modifications are accepted - otherwise we wouldn't know which bug to modify :-)  Updated bugs are returned for inspection.
<p>
Bug status may be modified using the web frontend (remember the <b>/admin/</b> bit of the address), or the email interface at:<pre>
	<b>close_&lt;bugID&gt;_win32\@$email</b></pre>
<p>
Patches may be mailed in against one or more bugids.  The bugs will be closed and the patch entered into the database.  Normally a changeID (perl-lib/src/Changes-nnn) should also be assigned where possible:<pre>
	<b>patch_&lt;changeID&gt;_&lt;bugID&gt;\@$email</b></pre>
<p>
Notes may be assigned from the web front end or be mailed against a given bug:<pre>
	<b>note_&lt;bugid&gt;\@$email</b></pre>
<p>
<b>NB:</b>
When using the email interface, keywords need to be at the beginning of the address, ie:<pre>
	<b>/^(patch|note|test|help|Help)_xyz\@$email</b></pre>
<p>
Don't delete any bugs unless you have to, when in doubt: use the '<b>notabug</b>' category and '<b>close</b>' it.
<p>
More helpful hints to come...
<p>
</td></tr></table>
#;
	$help .= $admin if $self->isadmin;
	$self->result($help);
	return 1;
}


=item administration_failure

Deal with a failed administration attempt

	my $i_ok = $self->administration_failure($bid, $user, $commands);

=cut

sub administration_failure {
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = $self->SUPER::administration_failure(@_);
	my $err = qq|
		There was an access error violation:
		
		@_
	|;
	$self->result($err);
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


sub file_ext { return '.html'; }


=item todo

To do list, may be appended to

=cut

sub todo { # mailto -> maintainer
    my $self = shift;
	my $ok = 1;
	my $cgi = $self->{'CGI'};
	my $tup = $cgi->param('append');
	if (defined($tup) && $tup =~ /\w+/ && length($tup) < 500) {
		# just append it
		my $spacer = '       '; # 7
		$self->debug(0, "Appending to TODO: data($tup)");
		$self->append('todo', "\n$spacer $tup\n"); 
	}
	my $i_todo = $self->SUPER::todo($tup); # mail out
	my $todo = $self->read('todo');
    $self->result("<pre>$todo</pre>");
    return $ok;
}


=item adminfaq

adminFAQ

=cut

sub adminfaq { # ...
    my $self = shift;
	my $ok = 1;
	my $cgi = $self->{'CGI'};
	my $adminfaq = $self->read('adminfaq');
    $self->result("<pre>$adminfaq</pre>");
    return $ok;
}


=item search

Search form into result

	with chosen params as defaults...

=cut

sub search {
    my $self = shift;
    my $cgi = $self->{'CGI'};
    # my %defaults = $cgi->defaults;
    # Data
	my @status     = ('any', $self->get_list("SELECT DISTINCT flag FROM tm_flags WHERE type = 'status'"));
	my @categories = ('any', $self->get_list("SELECT DISTINCT flag FROM tm_flags WHERE type = 'category'"));
	my @severities = ('any', $self->get_list("SELECT DISTINCT flag FROM tm_flags WHERE type = 'severity'"));
	my @osnames    = ('any', $self->get_list("SELECT DISTINCT flag FROM tm_flags WHERE type = 'osname'"));
	my @userids    = ('any', $self->get_list("SELECT DISTINCT userid FROM tm_bug_user"));
	my @sourceaddr = $self->get_list("SELECT DISTINCT sourceaddr FROM tm_bug");
	my @bugs    = $self->get_list("SELECT bugid FROM tm_bug");
	my %admins = ();
	foreach my $uid (@userids) {
		my ($name) = $self->get_list("SELECT DISTINCT name FROM tm_user WHERE userid = '$uid'");
		$admins{$uid} = $name;
	}
    $self->debug(3, "Setting search form elements...");   
	# Elements
	my $body     = $cgi->textfield(-'name'  => 'body',   	-'default' => '', -'size' => 45, -'maxlength' => 45, -'override' => 1);
	my $bugid = $cgi->textfield(-'name'  => 'bugid',  -'default' => '', -'size' => 14, -'maxlength' => 14, -'override' => 1);
    my $version  = $cgi->textfield(-'name'  => 'version',   -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $patchid  = $cgi->textfield(-'name'  => 'patchid',   -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $patch    = $cgi->textfield(-'name'  => 'patch',     -'default' => '', -'size' => 25, -'maxlength' => 10, -'override' => 1);
	my $noteid   = $cgi->textfield(-'name'  => 'noteid',    -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $note     = $cgi->textfield(-'name'  => 'note',      -'default' => '', -'size' => 25, -'maxlength' => 10, -'override' => 1);
	my $testid   = $cgi->textfield(-'name'  => 'testid',    -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $test     = $cgi->textfield(-'name'  => 'test',      -'default' => '', -'size' => 25, -'maxlength' => 10, -'override' => 1);
	my $changeid = $cgi->textfield(-'name'  => 'changeid',  -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
    my $msgid    = $cgi->textfield(-'name'  => 'messageid', -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $subject  = $cgi->textfield(-'name'  => 'subject',   -'default' => '', -'size' => 25, -'maxlength' => 25, -'override' => 1);
	my $sourceaddr= $cgi->textfield(-'name' => 'sourceaddr',-'default' => '', -'size' => 55, -'override' => 1);
	my $fixedin  = $cgi->textfield(-'name'  => 'fixedin',   -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $admins   = $cgi->popup_menu(-'name' => 'admin',     -'values' => \%admins,     -'default' => 'any', -'override' => 1);
	my $status   = $cgi->popup_menu(-'name' => 'status',    -'values' => \@status,     -'default' => 'any', -'override' => 1);
    my $category = $cgi->popup_menu(-'name' => 'category',  -'values' => \@categories, -'default' => 'any', -'override' => 1);
    my $severity = $cgi->popup_menu(-'name' => 'severity',  -'values' => \@severities, -'default' => 'any', -'override' => 1);
	my $osnames  = $cgi->popup_menu(-'name' => 'osname',    -'values' => \@osnames,    -'default' => 'any', -'override' => 1);
	my %dates    = $self->date_hash; # 'labels' => \%dates ?
	my @dates    = keys %dates;
	my $date     = $cgi->popup_menu(-'name' => 'dates',     -'values' => \@dates,      -'default' => 'any', -'override' => 1);
	# no case sensitivity in mysql?
    # my $case     = '';
    #if ($self->isadmin eq $self->system('bugmaster')) {
    #    $case     = 'Case: '.$cgi->popup_menu(-'name' => 'case',      -'values' => ['Sensitive', 'Insensitive'], -'default' => 'Insensitive');
    #}
    my $andor_def = ($cgi->param('andor') =~ /^(AND|OR)$/) ? $1 : 'AND';
    my $andor    = $cgi->radio_group(-'name'=> 'andor',     -'values' => ['AND', 'OR'], -'default' => $andor_def, -'override' => 1);
    my $restrict_def = ($cgi->param('trim') =~ /^(\d+)$/) ? $1 : 25;
    my $restrict = $cgi->popup_menu(-'name' => 'trim',      -'values' => ['All', '5', '10', '25', '50', '100'],  -'default' => $restrict_def, -'override' => 1);
    my %format   = ( 'h' => 'Html list', 'H' => 'Html block', 'L' => 'Html lean', 'a' => 'Ascii list', 'A' => 'Ascii block', 'l' => 'Ascii lean',); 
	# my %format   = ( 'h' => 'Html list', 'H' => 'Html block', 'a' => 'Ascii list', 'A' => 'Ascii block', 'l' => 'Ascii lean', -'override' => 1); 
	my $format   = $cgi->radio_group(-'name' => 'format',  -values => \%format, -'default' => 'h', -'override' => 1);
    my $sqlshow_def = ($cgi->param('sqlshow') =~ /^(Yes|No)$/i) ? $1 : 'No';
    my $sqlshow  = $cgi->radio_group(-'name' => 'sqlshow',	-'values' => ['Yes', 'No'], -'default' => $sqlshow_def, -'override' => 1);
    my $url = $cgi->url;
   $self->current_buttons([qw(search reset)], 1);
    # Form <form name="bugquery" method="post" action="$url"> 
	my $withbug  = $cgi->radio_group(-'name' => 'withbug',	-'values' => ['Yes', 'No'], -'default' => 'Yes', -'override' => 1); 
	my $order  = $cgi->radio_group(-'name' => 'order',	-'values' => ['Asc', 'Desc'], -'default' => 'Desc', -'override' => 1); 
	my $plus = qq|
		<tr><td><b>NoteID</b>&nbsp;$noteid<br>$note</td><td><b>PatchID</b>&nbsp; $patchid<br>$patch</td><td><b>TestID</b>&nbsp; $testid<br>$test</td><td><b>Asc\/Desc (by bugid):</b><br>$order</td></tr>
	| if 1; 
	$plus = qq|
		<tr><td><b>NoteID</b>&nbsp;$noteid<br>$note</td><td><b>PatchID</b>&nbsp; $patchid<br>$patch</td><td><b>TestID</b>&nbsp; $testid<br>$test</td><td><b>Must relate to a bugid?</b><br>$withbug</td></tr>
	| if 0; 
	my $form = qq|
	    <table border=1><tr><td colspan=5><i>
	    Select from the options (see <a href="$url?req=help">help</a>) available, then click the query button.<br>  
	    </td></tr>
	    <tr><td><b>BugID:</b><br>$bugid</td><td><b>Version:<br></b>&nbsp;$version</td><td><b>Fixed In:<br></b>&nbsp;$fixedin</td><td><b>Changeid</b><br>$changeid</td></tr>
	    <tr><td><b>Status:</b><br>$status</td><td><b>Category:</b><br>$category</td><td><b>Severity:</b><br>$severity</td><td><b>OS:</b><br>$osnames</td></tr>
	    <tr><td colspan=2><b>Subject:</b>&nbsp;$subject</td><td colspan=2><b>Body:</b>&nbsp;$body</td></tr>
	    <tr><td><b>Source address:</b></td><td colspan=4>$sourceaddr</td></tr>
	    <tr><td><b>Dates:</b><br>$date</td><td colspan=2><b>Administrator</b><br>$admins</td><td><b>Restrict returns to</b>:<br> $restrict</td></tr>
	    <tr><td colspan=2><b>Format:<br></b>$format</td><td><b>Show SQL:<br></b>$sqlshow</td><td><b>Boolean:</b><br>$andor</td></tr>
	    $plus
		</table>
    |;
	my $input = $cgi->textarea(-'name' => 'sql_query', -'default' => 'your select query here', -'rows' => 5, -'columns' => 50);
    my $sqlquery = $self->current_buttons('sql_query reset');
    my $sqlinput = qq|<hr>
        Alternatively query directly from here:&nbsp<b>SELECT</b>... <br>
        <form name="sql" method="post" action="$url">
        $input<br>
        $sqlquery
        </form>
    |;
    if ($self->isadmin eq $self->system('bugmaster')) { # could be all active admins? 
        # $form .= $sqlinput;    
    }
    $self->debug(3, "Form: '$form'\nSQLinput: '$sqlinput'");
    $self->result($form); 
    return 1;
}


=item case

Handle case sensitivity from web search form.

=cut

sub case {
    my $self = shift;
    my $arg = shift;
    return $self->{'attr'}{'PRE'}.$arg.$self->{'attr'}{'POST'};
}


=item format_web_query

Produce SQL query for bug search from CGI query.

    my $query = $web->format_web_query;

=cut

sub format_web_query {
    my $self = shift;
    my $cgi = $self->{'CGI'};
    $self->debug(3, "Formatting web query");
    my %dates = $self->date_hash;
    # parameters
    my $admin       = ($cgi->param('admin') eq 'any') ? '' : $cgi->param('admin');
    my $andor       = $cgi->param('andor') || 'AND';
    my $body	    = $cgi->param('body') || '';
    my $bugid    = $self->wildcard($cgi->param('bugid')) || '';
    my $case        = $cgi->param('case') || '';
    my $category    = ($cgi->param('category') eq 'any') ? '' : $cgi->param('category');
    my $changeid    = $cgi->param('changeid') || '';
	my $date        = ($cgi->param('dates') eq 'any') ? '' : $cgi->param('dates');
    my $fixed		= $cgi->param('fixedin') || '';
	# my $msgid      = $self->wildcard($cgi->param('messageid')) || '';
    my $noteid      = $cgi->param('noteid') || '';
	my $note        = $cgi->param('note') || '';
    my $testid      = $cgi->param('testid') || '';
	my $test        = $cgi->param('test') || '';
    my $patchid     = $cgi->param('patchid') || '';
	my $patch       = $cgi->param('patch') || '';
	my $order       = $cgi->param('order') || 'DESC';
	my $osname      = ($cgi->param('osname') eq 'any') ? '' : $cgi->param('osname');
    my $severity    = ($cgi->param('severity') eq 'any') ? '' : $cgi->param('severity');
    my $sourceaddr  = $self->wildcard($cgi->param('sourceaddr')) || '';
    my $sqlshow	    = $cgi->param('sqlshow') || '';
    my $status      = ($cgi->param('status') eq 'any') ? '' : $cgi->param('status');
    my $subject     = $self->wildcard($cgi->param('subject')) || '';
    my $version     = $self->wildcard($cgi->param('version')) || '';
    my $withbug     = $cgi->param('withbug') || '';
	#
    # case inoperative on mysql
	if ($case =~ /Insensitive/) {
	    $self->{'attr'}{'PRE'} = 'UPPER(';
	    $self->{'attr'}{'POST'} = ')';
	}
	my $wnt = 0;
	my $fnd = 0;
	
    # Work through parameters given above to generate appropriate sql.
    my $sql = 'SELECT bugid FROM tm_bug WHERE ';
    if ($date =~ /\w+/) {
        my $crit = $dates{$date};
        $sql .= " $crit ";
    } else {
        # let's default to all of them :-)
        $sql .= " bugid IS NOT NULL ";
    }
    # 
    if ($admin =~ /^(\w+)$/) {
		$wnt++;
        my $get_tids = "SELECT bugid FROM tm_bug_user WHERE userid = '$1'";
        $fnd += my @tids = $self->get_list($get_tids);
		$self->result("Found ".@tids." bug_user relations from claimants($1)");
        my $found = join("', '", @tids);	
        $sql .= " $andor bugid IN ('$found') " if scalar(@tids) >= 1;
    }
	if ($patchid =~ /^(\w+)$/) {
		$wnt++;
        my $get_tids = "SELECT bugid FROM tm_bug_patch WHERE patchid LIKE '$1'";
        $fnd += my @tids = $self->get_list($get_tids);
		$self->result("Found ".@tids." bug_patch relations from patchid($1)");
        my $found = join("', '", @tids);	
        $sql .= " $andor bugid IN ('$found') " if scalar(@tids) >= 1;
    }
	if ($testid =~ /^(\w+)$/) {
		$wnt++;
        my $get_tids = "SELECT bugid FROM tm_bug_test WHERE testid LIKE '$1'";
        $fnd += my @tids = $self->get_list($get_tids);
		$self->result("Found ".@tids." bug_test relations from testid($1)");
        my $found = join("', '", @tids);	
        $sql .= " $andor bugid IN ('$found') " if scalar(@tids) >= 1;
    }
	if ($noteid =~ /^(\w+)$/) {
		$wnt++;
        my $get_tids = "SELECT bugid FROM tm_bug_note WHERE noteid LIKE '$1'";
        $fnd += my @tids = $self->get_list($get_tids);
		$self->result("Found ".@tids." bug_note relations from noteid($1)");
        my $found = join("', '", @tids);	
		$sql .= " $andor bugid IN ('$found') " if scalar(@tids) >= 1;
    }
	if ($patch =~ /(.+)/) {
		$wnt++;
		my $get_ids = "SELECT patchid FROM tm_patch WHERE msgbody like '%$1%'";
		my @ids = $self->get_list($get_ids);
		my $ids = join("', '", @ids);
		$fnd += my @tids = $self->get_list("SELECT bugid FROM tm_bug_patch WHERE patchid IN ('$ids')");
		$self->result("Found ".@tids." bug_patch relations from patch content($1)");
		my $found = join("', '", @tids);	
        $sql .= " $andor bugid IN ('$found') ";
    }
	if ($test =~ /(.+)/) {
		$wnt++;
		my $get_ids = "SELECT testid FROM tm_test WHERE msgbody like '%$1%'";
		my @ids = $self->get_list($get_ids);
		my $ids = join("', '", @ids);
		$fnd += my @tids = $self->get_list("SELECT bugid FROM tm_bug_test WHERE testid IN ('$ids')");
		$self->result("Found ".@tids." bug_test relations from test content($1)");
		my $found = join("', '", @tids);	
        $sql .= " $andor bugid IN ('$found') ";
    }
	if ($note =~ /(.+)/) {
		$wnt++;
		my $get_ids = "SELECT noteid FROM tm_note WHERE msgbody like '%$1%'";
		$fnd += my @ids = $self->get_list($get_ids);
		$self->result("Found ".@ids." bug_note relations from note content($1)");
		my $found = join("', '", @ids);	
		$fnd += my @tids = $self->get_list("SELECT bugid FROM tm_bug_note WHERE noteid IN ('$found')");
       	 	$found = join("', '", @tids);	
		$sql .= " $andor bugid IN ('$found') " if scalar(@tids) >= 1;
    	}
	if ($changeid =~ /^(\w+)$/) {
		$wnt++;
        	my $get_pids = "SELECT patchid FROM tm_patch_change WHERE changeid LIKE '$1'";
        	my @ids = $self->get_list($get_pids);
        	$self->result("Found ".@ids." change relations from changeid($1)");
		my $found = join("', '", @ids);	
		$fnd += my @tids = $self->get_list("SELECT bugid FROM tm_bug_patches WHERE patchid IN ('$found')");
        	$found = join("', '", @tids);	
		$sql .= " $andor bugid IN ('$found') " if scalar(@tids) >= 1;
    }
	if ($body =~ /(.+)/) {
		$wnt++;
		my $get_mids = "SELECT messageid FROM tm_message WHERE msgbody like '%$1%'";
		my @mids = $self->get_list($get_mids);	
		$self->result("Found ".@mids." messageids from body($1)");
		my $mids = join("', '", @mids);	
		$fnd += my @tids = $self->get_list("SELECT bugid FROM tm_bug_message WHERE messageid IN ('$mids')");
		$self->result("Found ".@tids." message_bug relations from message content($1)");
		my $found = join("', '", @tids);	
        $sql .= " $andor bugid IN ('$found') ";
    }
    if ($bugid =~ /^\s*(.*\w+.*)\s*$/) {
        $sql .= " $andor bugid LIKE '$1' ";
    }
	if ($version =~ /.+/) {
        $sql .= " $andor version LIKE '$version' ";
    }
	if ($fixed =~ /.+/) {
        $sql .= " $andor fixed LIKE '$fixed' ";
    }
    if ($status =~ /\w+/) {
        $sql .= " $andor status = '$status' ";
    }
    if ($category =~ /\w+/) {
        $sql .= " $andor category = '$category' ";
    }
    if ($severity =~ /\w+/) {
        $sql .= " $andor severity = '$severity' ";
    }
    if ($osname =~ /.+/) {
        $sql .= " $andor osname = '$osname' ";
    }
	if ($subject =~ /.+/) {
        $sql .= " $andor subject LIKE '%".$self->case($subject)."%' ";
    }
    if ($sourceaddr =~ /.+/) {
        $sql .= " $andor sourceaddr LIKE '%".$self->case($sourceaddr)."%' ";
    }    
	# 
	if ($wnt >= 1 && $fnd == 0 && $andor eq 'AND') { #  && $withbug eq 'Yes') {
		$self->debug(1, "appear to want($wnt) unfound($fnd) andor($andor) withbug($withbug) data!");
		$sql .= " $andor 1 = 0 "; 
	} 
	# ref
	# $self->result("want($wnt) fnd($fnd) andor($andor) withbug($withbug)");
	# $self->result("SQL: $sql<hr>"); 
	
	$sql .= " ORDER BY bugid $order"; #?
	$self->result("SQL: $sql<hr>") if $sqlshow =~ /y/i;
	$self->debug(2, "SQL built: '$sql'");
	return $sql;
}


=item wildcard

Convert '*' into '%' for sqlquery

    my $string = $self->wildcard('5.*');

=cut

sub wildcard {
    my $self = shift;
    my $str  = shift;
    $str =~ s/\*/%/g;
    return $str;
}


=item web_update

For bugs and users

=cut

sub web_update {
    my $self = shift;
    my $nocc = shift || '';
    my $cgi = $self->{'CGI'};
    my @bugids = $cgi->param('bugids');
	my @userids   = $cgi->param('userids');
    $self->debug(1, "web_update: tids(@bugids), userids(@userids)");
    my $ok = 1;
    if (scalar @bugids >= 1) {
    	my $a_buttons = ($self->can_update(\@bugids)) ? [qw(update nocc reset delete)] : [];
		$self->result($self->current_buttons($a_buttons, scalar(@bugids)));
    	BUG:
		foreach my $bid (@bugids) {
			next BUG unless $bid =~ /\d{8}\.\d{3}/;
            next BUG unless $ok == 1;
			$self->debug(0, "calling dok($bid)");
        	$self->dok([$bid]) unless $self->admin_of_bug($bid, $self->isadmin);
        	my $orig = $self->current_status($bid);
			my $status   = $cgi->param($bid.'_status') || '';
        	my $category = $cgi->param($bid.'_category') || '';
        	my $severity = $cgi->param($bid.'_severity') || '';
        	my $version  = $cgi->param($bid.'_version') || '';
        	my $osname   = $cgi->param($bid.'_osname') || '';
        	my $fixed    = $cgi->param($bid.'_fixed') || '';
        	my $commands = "status='$status', category='$category', severity='$severity', version='$version', osname='$osname', fixed='$fixed'";
			my $update   = "UPDATE tm_bug SET $commands WHERE bugid='$bid'";
        	my $sth = $self->exec($update);
			# $self->doa("a $bid @cmds"); # !
			$ok = $self->track('b', $bid, join(':', $status, $category, $severity, $version, $osname));
	    	if (defined($sth)) { # do the rest: relationships, notes, patches, tests
				my $ix = $self->notify_cc($bid, '', $orig) unless $nocc eq 'nocc';
				my @parents  = split(/\s+/, $cgi->param($bid.'_parents'));
				my @children = split(/\s+/, $cgi->param($bid.'_children'));
				my $pcs 		= $self->tm_parent_child($bid, \@parents, \@children);
				my ($x, @xccs) 	= $self->tm_cc($bid, split(/\s+/, $cgi->param($bid.'_ccs')));
				my ($note, @notes)	 = $self->doN($bid, $cgi->param($bid.'_newnote'),  '');
				my ($patch,@patches) = $self->doP($bid, $cgi->param($bid.'_newpatch'), '');
				my ($test, @tests)	 = $self->doT($bid, $cgi->param($bid.'_newtest'),  '');
				my ($n, @xnotes)   = $self->tm_bug_note( $bid, split(/\s+/, $cgi->param($bid.'_notes')   ));
				my ($p, @xpatches) = $self->tm_bug_patch($bid, split(/\s+/, $cgi->param($bid.'_patches') ));
				my ($t, @xtests)   = $self->tm_bug_test( $bid, split(/\s+/, $cgi->param($bid.'_tests')   ));
				my $ref = "<p>Bug ($bid) updated $Mysql::db_errstr<p>";
	    		$self->debug(2, $ref);
		    } else {
	        	my $ref = "<p>Bug ($bid) update failure: ($@, $Mysql::db_errstr, $sth).<p>";
	    		$self->result($ref);
		    }
    	}
        $self->result('<table border=1>');
		$ok = $self->dob(\@bugids); 
		$self->result('</table>'); 
    } else {
		my $err = "No bugids (@bugids) selected for update?";
		$self->result($err) unless scalar(@userids) >= 1;
		$self->debug(0, $err);
	}	
    if (scalar @userids >= 1) {
		my $a_buttons = ($self->can_update(\@userids)) ? [qw(update reset delete)] : [];
        $self->result($self->current_buttons($a_buttons, scalar(@userids)));
        USER:
        foreach my $uid (@userids) {
			next USER unless $uid =~ /^\w+$/;
            next USER unless $ok == 1;
			$self->debug(0, "updating admin($uid)");
            my $userid   = $cgi->param($uid.'_userid'); 
            my $active   = $cgi->param($uid.'_active');
            my $name     = $cgi->param($uid.'_name');
        	my $address  = $cgi->param($uid.'_address');
        	my $password = $cgi->param($uid.'_password');
            my $pwdupdate= $cgi->param($uid.'_password_update') || 0;
            $password    = crypt($password, substr($password, 0, 2)) if $pwdupdate;
        	my $match_address = $self->qm($cgi->param($uid.'_match_address'));
            my $ref = qq|uid($uid), userid($userid), active($active), name($name), pass($password), passupd($pwdupdate), match($match_address)|;
            if (!(grep(/\w+/, $uid, $active, $name, $address, $password, $pwdupdate, $match_address) == 7)) {
                $ok = 0;
                $self->debug(0, "Not enough data for update: $ref");
            }
            $self->debug(0, "REF: $ref");
            my ($sql, $commands) = ('', '');
            if ($ok == 1) {
                my $exists = $self->get_list("SELECT userid FROM tm_user WHERE userid = '$uid'");
                if (($uid eq 'newAdmin') && (!$exists))  {
                    # $uid = $userid; # only relevant for new data?
                    $commands = "now(), NULL, '$userid', '$password', '$address', '$name', $match_address, $active";
	    	        if ($self->isadmin eq $self->system('bugmaster')) {
                        $sql = "INSERT INTO tm_user values ($commands)";
                        push(@userids, $userid);
                    } else {
                        $ok = 0;
                        $self->debug(0, "User(".$self->isadmin." can't generate user: ($commands)");
                    } 
                } else {
					$active = $self->quote($active) unless $active eq 'NULL';
                    $commands = "password='$password', address='$address', name='$name', match_address=$match_address, active=$active";
	    	        $sql = "UPDATE tm_user SET $commands WHERE userid='$uid'";
                }
            }
            if ($ok == 1) {
                my $sth = $self->exec($sql);
	    	    if (defined($sth)) {
	        	    my $cnt = $sth->affected_rows;
	        	    my $ref = "<p>User ($uid) updated($cnt) $Mysql::db_errstr<p>";
			        $ok = $self->track('u', $uid, join(':', $uid, $name, $address, $password, $cgi->param($uid.'_match_address')));
	    		    $self->debug(2, $ref);
		            if ($ok == 1) {
                        $ok = $self->htpasswd($uid, $password) if $pwdupdate || $userid eq 'newAdmin';
                    }
                } else {
	        	    my $ref = "<p>Admin ($uid) command failure: ($@, $Mysql::db_errstr, $sth).<p>";
	    		    $self->result($ref);
		        }
            }
    	}
        $self->result('<table border=1>');
        $ok = $self->dou(\@userids);
		$self->result('</table>'); 
    } else {
		my $err = "No userids (@userids) selected for update?";
		$self->result($err) unless scalar(@bugids) >= 1;
		$self->debug(0, $err);
	}	
    $self->debug(1, "web_update? -> '$ok'");
    return ($ok >= 1) ? 1 : 0;    
}


=item tenify

Create range of links to split (by tens or more) bugids from web query result.

	$self->tenify(\@_bids, 7); # in chunks of 7

=cut

sub tenify {
    my $self    = shift;
    my $a_bids  = shift;
    my $given   = shift || 25;
    my $slice   = (($given >= 1) && ($given <= 10000)) ? $given : 25;
	my $ok 		= 1;
	$self->debug(3, "tenify($a_bids, $given) $slice -> '$$'");
    if (ref($a_bids) ne 'ARRAY') {
		$ok = 0;
		$self->debug(0, "Duff bug arrayref given to tenify($a_bids)");
	} else {
		my ($bids, $cnt, $min, $max) = ('', 0, 1, 0);
	    my $url = $self->current('url');
        my $fmt = $self->current('format');
		my $range = '';
		my @bids = @{$a_bids};
		foreach my $bid (@bids) {
	        $cnt++;
	        $max++;
	        $bids .= "&bid=$bid"; 
	        if (($cnt == $slice) || ($max == $#bids + 1)) { # chunk
				# Params
	            $range .= qq|<a href="$url?req=bid$bids&range=$$&format=$fmt">$min to $max</a>&nbsp;\n|;
	            $min = $max + 1; 
	            $bids = '';
	            $cnt = 0;
	        } 
	    }
		$self->range($$, "<table><tr><td>$range</td></tr></table>");	# store data
    }
    return $ok;
}


=item range

Store and retrieve range of bugs, swap between using filesystem and database?

	$id = $o_web->range($id, $data); 		# get and set

=cut

sub range {
	my $self 	= shift;
	my $id 		= shift;
	my $data 	= shift;
	my $ok 		= 1;
	if ($id !~ /^\d+$/) {
		$ok = 0;
		$self->debug(0, "Cannot get/set range() without an id($id)");
	} else {
	  	$self->{'attr'}{'current_range'} = $id;
		$self->current('rng_file', $self->directory('spool')."/ranges/${id}.rng"); # point to correct file
		if (length($data) >= 1) {	# set
			my $res = $self->append('rng', $data);
		} else {
			$ok = 0;
			carp("NOT storing range id($id) in: '".$self->current('rng_file')."', data($data)");
		}
	}
	return $self->{'attr'}{'current_range'};
}


=item comment

Return string as html comment

	my $commented = $o_web->comment(qq|<input type="text" name="dont_know" value="vaguer_still">|);

=cut

sub comment {
	my $self = shift;
	my $str  = qq|<!--$_[0] -->|;
	return $str;
}


=item hide

=cut

sub hide {
    my $self    = shift;
    my ($a_bids, $name, $slice)  = @_;
    $self->debug(3, "hide (@_)");
    my $hidden = "";
    if (ref($a_bids) eq 'ARRAY') {
        $self->debug(3, "hiding @{$a_bids}");
        $hidden = join(":", @{$a_bids});
    }
    $hidden .= "&trim=$slice";
    $self->debug(3, "hidden: '$hidden'");
    return $hidden;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999

=cut

1;

