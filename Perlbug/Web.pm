# Perlbug WWW interface
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Web.pm,v 1.84 2001/02/07 16:20:18 perlbug Exp $
#
# TODO: 
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
use Perlbug::Format; # href's
use URI::Escape;
@ISA = qw(Perlbug::Base);
use strict;
$| = 1; 

$VERSION = 1.83;

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
    $self->{'range'} = $cgi->param('range') || $$;

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
		my $head = $self->{'CGI'}->header; #(-'expires'=>'+10m');
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
	my $meth = join('|', qw(administrators adminfaq bid bidmids cid 
		date delete gid graph groups help hist mailhelp mid mheader 
		nid nheader nocc overview patches pheader pid search spec 
		sql_query tid theader todo uid update web_query
	));
    if ((defined($req)) && ($req =~ /^($meth)$/)) {
        my $request = $1;
        $self->debug(1, "Web::request($req) accepted -> '$request'");
        if ($self->can($request)) {
            $self->debug(3, "Can call -> '$request'");
            if ($request =~ /^delete|sql_query|update$/i) {
                if ($self->isadmin) {
                    $result = $self->$request($cgi);
                } else {
	                my $user = $self->current('admin');
                    $result = "<h3>User ($user) not permitted for action '$request'</h3>";
                }
            } else {
		        $result = $self->$request($cgi);
            }	
        } else {
            $result = "Unable to do '$request'";
            $self->debug(0, "$self 'can' not do '$request'");
        }
    } else {
        $result = "Invalid request ($req)";
        $self->debug(0, "Invalid CGI ($cgi) request ($req) for methods available: ($meth)");
    }
    return ($result =~ /^1$/) ? '' : $result;
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
		print "Graph functionality unsupported, talk to the webmaster($maintainer) :-(<br>";
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
    $self->debug(1, "nids(@nids)");
    my $a_buttons = ($self->can_update(\@nids)) ? [qw(reset update)] : [];
    $self->current_buttons($a_buttons, scalar(@nids));
    
	print '<table border=1>', $self->don(\@nids), '</table>';
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
    $self->debug(1, "tids(@tids)");
	my $a_buttons = ($self->can_update(\@tids)) ? [qw(update nocc reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@tids));
	
	print '<table border=1>', $self->dot(\@tids), '</table>';
    return $ok;
}


=item date

Wrapper for search by date access

=cut

sub date {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my $date = $cgi->param('date');
    $self->debug(1, "date($date)");
    my $filter = '';

    if ($date =~ /^\d{8}$/) {
		$filter = "TO_DAYS($date)";	
		$self->debug(0, "using given date($date)");
    } elsif ($date =~ /^\d+$/) {
		$filter = "TO_DAYS($date)";	
		$self->debug(0, "using non-norm given date($date)");
    } elsif ($date =~ /^\-(\d+)$/) {
		$filter = "(TO_DAYS(now())-$1)";	
		$self->debug(0, "using minus given num($date)");
    } else {
		$filter = "TO_DAYS(now()) - 10";	
		$self->debug(0, "unrecognised date($date) format(should be of the form: 20001015), using($filter)");
    }

    my $sql = qq|SELECT bugid FROM tm_bug WHERE TO_DAYS(created) >= $filter |;
    my @bids = $self->get_list($sql);
    $self->debug(0, "$sql->'@bids'");

    my $a_buttons = ($self->can_update(\@bids)) ? [qw(update nocc reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@bids));
	
    print '<table border=1>', $self->dob(\@bids), '</table>';
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
    $self->debug(1, "pids(@pids)");
	my $a_buttons = ($self->can_update(\@pids)) ? [qw(update nocc reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@pids));
	
    print '<table border=1>', $self->dop(\@pids), '</table>';
    return $ok;
}


=item cid

Wrapper for doc changeid access

=cut

sub cid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @cids = $cgi->param('cid');
    $self->debug(1, "cids(@cids)");
	my $a_buttons = ($self->can_update(\@cids)) ? [qw(update nocc reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@cids));

    print '<table border=1>', $self->doc(\@cids), '</table>';
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
    $self->debug(1, "bids(@bids)");
	my $a_buttons = ($self->can_update(\@bids)) ? [qw(update nocc reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@bids));
	
    print '<table border=1>', $self->dob(\@bids), '</table>';
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
    print $self->current_buttons($a_buttons, scalar(@pats));

    print '<table border=1>', $self->dop(\@pats), '</table>';
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
    $self->debug(1, "uids(@uids)");
    my $a_buttons = ($self->can_update(\@uids)) ? [qw(reset update delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@uids));

    print '<table border=1>', $self->dou(\@uids), '</table>';
    return $ok;
}


=item gid

Wrapper for dog group access

=cut

sub gid {
    my $self = shift;
    my $cgi = shift;
    my $ok = 1;
    my @gids = $cgi->param('gid');
    $self->debug(1, "gids(@gids)");
    my $a_buttons = ($self->can_update(\@gids)) ? [qw(reset update delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@gids));

    print '<table border=1>', $self->dog(\@gids), '</table>';
    return $ok;
}


=item hist

History mechanism for bugs and users.

Move formatting to Formatter::history !!!

=cut

sub hist {
    my $self = shift;
    my $cgi = shift;
    my ($bid) = $cgi->param('hist');
    $self->debug(1, "hist: bid($bid)");
    my ($bik) = Perlbug::Format::href($self, 'bid', [$bid], $bid);
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
	}
	my $date = $data{'ts'};
	$hist .= qq|<tr><td>$admin</td><td>$data{'objecttype'} &nbsp; $data{'entry'}</td><td>$data{'from_unixtime(unix_timestamp(ts))'}</td></tr>|;	
    }
    $hist .= '</table>';
    print $hist;
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
		$self->debug(0, "Can't do invalid obj($obj) id($id) for header request");
	} else {
    	my ($item) = Perlbug::Format::href($self, $obj.'id', [$id], $id);
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
    	print $headers;
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
    print $self->current_buttons($a_buttons, scalar($bid));

    print '<table border=1>', $self->doB([$bid]), '</table>';
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
    print $self->current_buttons($a_buttons, scalar(@mids));

    print '<table border=1>', $self->dom(\@mids), '</table>';
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
			print "bugids (@bugids) succesfully deleted<br>";
		} else {
			my $maintainer = $self->system('maintainer');
			$maintainer = qq|<a href="mailto: $maintainer">$maintainer</a>|;
			print "<hr>bugids not entirely deleted, please report this to the administrator: $maintainer";

			print '<table border=1>', $self->dob(\@bugids), '</table>';
		}
    } else {
		if ($cgi->param('userids') >= 1) {	
			my $maintainer = $self->system('maintainer');
			print "Cannot delete adminstrator from web interface, see maintainer($maintainer)";
		} else {
			print "No bugids (@bugids) selected for deletion?";
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
    print "Found $found bugs<br>";
	if ($found >= 10) {
        my $trim = $cgi->param('trim');
        print " showing '$trim'<br>" if $trim =~ /\d+/ and $trim <= $found;
        if (($trim !~ /^\d+$/) || ($trim >= 10001)) {
            $trim = 10000;
        }
        $self->tenify(\@bids, $trim); 
        if ($trim =~ /\d+/) {
            $#bids = $trim - 1;
        }
    } 
    my $a_buttons = ($self->can_update(\@bids)) ? [qw(update nocc reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@bids));

    print '<table border=1>', $self->dob(\@bids), '</table>';
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
	my $rangeid = $self->{'range'};
    my $x_fmt   = ($cgi->param('req') eq 'search') ? '' : qq|<input type="hidden" name="format" value="$fmt">|;
    my $x_rng   = qq|<input type="hidden" name="range" value="$rangeid">|;
    my $buttons = $self->current_buttons;
    my $hidden  = ''; # $self->hidden_parameters; # if not set
	my ($range) = Perlbug::Range->new->col('range', "processid='$rangeid'");
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
    print qq|<h2>$title administrators:</h2>|;
    my $get = "SELECT userid FROM tm_user";
	$get .= " WHERE active != 'NULL'" unless $self->isadmin eq $self->system('bugmaster');
	my @admins = $self->get_list($get);
   
    my $a_buttons = ($self->can_update(\@admins)) ? [qw(update reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@admins));
	print '<table border=1>', $self->dou(\@admins), '</table>'; # inc. format
    my $ADMIN = '';
    if ($self->isadmin eq $self->system('bugmaster')) {
        my $hidden = qq|<input type=hidden name=newAdmin_password_update value=1>|;
        $ADMIN = qq|</table><table><tr><td colspan=5><hr><b>New User:</b></td></tr>\n<tr><td>|.
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
    print $ADMIN.'</table>';
    return 1;
}


=item groups 

List of groups

=cut

sub groups {
    my $self  = shift;
    my $cgi   = $self->{'CGI'};
    my $url   = $self->url;
    my $title = $self->system('title');
    print qq|<h2>$title groups:</h2>|;
   
	my @gids = $self->get_list("SELECT groupid FROM tm_group");
    my $a_buttons = ($self->can_update(\@gids)) ? [qw(update reset delete)] : [];
    print $self->current_buttons($a_buttons, scalar(@gids));
	print '<table border=1>', $self->dog(\@gids), '</table>'; # inc. format

	if ($self->isadmin =~ /\w+/ and $self->isadmin ne 'generic') { # addgroup
		my $add = $cgi->textfield(-'name' => 'addgroup', -'value' => '', -'size' => 20, -'maxlength' => 20, -'override' => 1);
		my $groups = "</table><hr><table border=0><tr><td><b>Add a new group (alphanumeric only):</b></td><td>&nbsp;$add</td></tr>";
		my $desc = $cgi->textfield(-'name' => 'adddescription', -'value' => '', -'size' => 35, -'maxlength' => 99, -'override' => 1);
		$groups .= "<tr><td><b>Description for new group:</b></td><td>&nbsp;$desc</td></tr></table><hr>";
		print $groups;
	}

	return 1;
}


=item spec

Returns specifications for the Perlbug system.

=cut

sub spec {
    my $self    = shift;
	my ($perlbug_spec) = $self->SUPER::spec; # Base
	my $spec = $self->read('spec');
	$perlbug_spec =~ s/\</&lt;/g;
	$perlbug_spec =~ s/\>/&gt;/g;
	$perlbug_spec =~ s/\b(http\:.+?perlbug\.cgi)\b/<a href="$1">$1<\/a>/gi;
	$perlbug_spec =~ s/\b([\<\w+\-_\.\>|\&.t\;]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;
	my $spec = qq|<table align=center>
		<tr><td><pre>$perlbug_spec</pre></td></tr>
		</table>
		<hr>
		<table border=0 align=center>
			<tr><td>$spec </td></tr>
		</table>
	|;
	print $spec;
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
	my $webhelp = $self->read('webhelp');
	my ($total) = $self->get_list("SELECT COUNT(*) FROM tm_bug");
	$perlbug_help =~ s/\b(http\:.+?perlbug\.cgi(?:\?.+)*)*\b/<a href="$1">$1<\/a>/gi;
	$perlbug_help =~ s/\b([\<\w+\-_\.\>]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;
	my $help = qq|
		<table align=center>
			<tr><td><pre>$perlbug_help</pre><hr></td></tr>
		</table>
		<hr>
		<table border=0 align=center>
			<tr><td> $webhelp </td></tr>
		</table>
    |;	
	print $help;
	return 1;
}


=item mailhelp

Web based mail help menu for perlbug.

	print $web->mailhelp;

=cut

sub mailhelp { #mailhelp 
	my $self = shift;
	my $url  = $self->url;
	my $email = $self->email('domain');
	my $bugdb = $self->email('bugdb');
	my ($perlbug_help) = $self->SUPER::doh; # Base
	my $help = $self->read('mailhelp');
	my ($total) = $self->get_list("SELECT COUNT(*) FROM tm_bug");
	$perlbug_help =~ s/\b(http\:.+?perlbug\.cgi(?:\?.+)*)*\b/<a href="$1">$1<\/a>/gi;
	$perlbug_help =~ s/\b([\<\w+\-_\.\>]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;
	my $HELP = qq|
		<table align=center>
			<tr><td><pre>$perlbug_help</pre><hr></td></tr>
		</table>
		<hr>
		<table border=0 align=center>
			<tr><td>$help</td></tr>
		</table>
    |;	
	print $HELP;
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
	print $err;
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
    print "<pre>$todo</pre>";
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
    print "<pre>$adminfaq</pre>";
    return $ok;
}


=item help_ref

creates something of the form: C<<a href="http://bugs.per.org/perlbug.cgi?req=help\#note">Note</a>>

	my $note = $self->help_ref('note');	

=cut

sub help_ref {
	my $self = shift;
	my $targ = shift || '';
	my $title= shift || $targ; 
    my $cgi  = $self->{'CGI'};
    my $url  = $cgi->url;

	my $sect = ($targ =~ /\w+/) ? "\#$targ" : '';
	my $with = ($targ =~ /\w+/) ? "help with $targ parameters"    : 'general help overview';
	my $hint = "click for $with";
	my $help = qq|<a 
			href="$url?req=help$sect"
			onMouseOver="window.status='$hint'; return true;"
			onMouseOut="window.status='';"
		>$title</a>
	|;
	$help =~ s/\s*\n+\s*/ /g;
	return "$help\n";
}


=item search

Search form into result

	with chosen params as defaults...

=cut

sub search {
    my $self = shift;
    my $cgi = $self->{'CGI'};
	my @sourceaddr = $self->get_list("SELECT DISTINCT sourceaddr FROM tm_bug");
	my @bugs    = $self->get_list("SELECT bugid FROM tm_bug");

	# Elements
    $self->debug(3, "Setting search form elements...");   
	my $body     = $cgi->textfield(-'name'  => 'body',   	-'default' => '', -'size' => 35, -'maxlength' => 45, -'override' => 1);
	my $bugid 	 = $cgi->textfield(-'name'  => 'bugid',     -'default' => '', -'size' => 14, -'maxlength' => 14, -'override' => 1);
    my $version  = $cgi->textfield(-'name'  => 'version',   -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $patchid  = $cgi->textfield(-'name'  => 'patchid',   -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $patch    = $cgi->textfield(-'name'  => 'patch',     -'default' => '', -'size' => 25, -'maxlength' => 10, -'override' => 1);
	my $noteid   = $cgi->textfield(-'name'  => 'noteid',    -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $note     = $cgi->textfield(-'name'  => 'note',      -'default' => '', -'size' => 25, -'maxlength' => 10, -'override' => 1);
	my $testid   = $cgi->textfield(-'name'  => 'testid',    -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $test     = $cgi->textfield(-'name'  => 'test',      -'default' => '', -'size' => 25, -'maxlength' => 10, -'override' => 1);
	my $changeid = $cgi->textfield(-'name'  => 'changeid',  -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $subject  = $cgi->textfield(-'name'  => 'subject',   -'default' => '', -'size' => 35, -'maxlength' => 25, -'override' => 1);
	my $sourceaddr= $cgi->textfield(-'name' => 'sourceaddr',-'default' => '', -'size' => 45, -'override' => 1);
	my $fixedin  = $cgi->textfield(-'name'  => 'fixedin',   -'default' => '', -'size' => 10, -'maxlength' => 10, -'override' => 1);
	my $msgid = $cgi->textfield(-'name'  => 'messageid',   -'default' => '', -'size' => 30, -'maxlength' => 40, -'override' => 1);

	my $admins   = $self->object('user')->popup('admin', 'any');
	my $category = $self->object('category')->popup('category', 'any');
	my $osnames  = $self->object('osname')->popup('osname', 'any');
	my $severity = $self->object('severity')->popup('severity', 'any');
	my $status   = $self->object('status')->popup('status', 'any');
	my $data = encode_entities($osnames);
	print qq|<table><tr><td><pre>$data &nbsp;</pre></td></tr></table>|;	
	# exit;

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
	# HELP
	my $BUG   	= $self->help_ref('bug',	'Bug ID');
	my $VERSION	= $self->help_ref('version', 'Version');
	my $FIXED 	= $self->help_ref('fixed', 'Fixed in');
	my $CHANGE	= $self->help_ref('change', 'Change ID');
	my $STAT	= $self->help_ref('status', 'Status');
	my $CAT		= $self->help_ref('category', 'Category');
	my $SEV		= $self->help_ref('severity', 'Severity');
	my $OS		= $self->help_ref('osname', 'OSname');
	my $SUBJ	= $self->help_ref('subject', 'Subject');
	my $BODY 	= $self->help_ref('body', 'Body');
	my $MSGID   = $self->help_ref('message_id', 'Message-Id');
	my $SRCADDR = $self->help_ref('source_addr', 'Source address');
	my $DATES	= $self->help_ref('dates', 'Dates');
	my $ADMIN   = $self->help_ref('admin', 'Administrator');
	my $RESTRICT= $self->help_ref('restrict', 'Retrict returns to');
	my $FMT		= $self->help_ref('format', 'Formatter');
	my $SHOWSQL = $self->help_ref('show_sql', 'Show SQL');
	my $ANDOR	= $self->help_ref('and_or', 'Boolean');
	my $ASCD	= $self->help_ref('asc_desc', 'Asc/Desc by bugid');
	my $NOTE	= $self->help_ref('note', 'Note ID');	# <a href="$url?req=help">help</a>	
	my $PATCH 	= $self->help_ref('patch', 'Patch ID');
	my $TEST	= $self->help_ref('test', 'Test ID');
	my $form = qq|
	    <table border=1><tr><td colspan=5><i>
	    Select from the options (see <a href="$url?req=help">help</a>) available, then click the query button.<br>  
	    </td></tr>
	    <tr><td><b>$BUG:</b><br>$bugid</td><td><b>$VERSION:<br></b>&nbsp;$version</td><td><b>$FIXED:<br></b>&nbsp;$fixedin</td><td><b>$CHANGE</b><br>$changeid</td></tr>
	    <tr><td><b>$STAT:</b><br>$status</td><td><b>$CAT:</b><br>$category</td><td><b>$SEV:</b><br>$severity</td><td><b>$OS:</b><br>$osnames</td></tr>
	    <tr><td colspan=2><b>$SUBJ:</b>&nbsp;$subject</td><td colspan=2><b>$SRCADDR:</b>&nbsp;$sourceaddr</td></tr>
	    <tr><td colspan=2><b>$BODY:&nbsp;&nbsp;&nbsp;</b>&nbsp;$body</td><td colspan=2><b>$MSGID:</b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$msgid</td></tr>
	    <tr><td><b>$DATES:</b><br>$date</td><td colspan=2><b>$ADMIN</b><br>$admins</td><td><b>$RESTRICT</b>:<br>$restrict</td></tr>
	    <tr><td colspan=2><b>$FMT:<br></b>$format</td><td><b>$SHOWSQL:<br></b>$sqlshow</td><td><b>$ANDOR:</b><br>$andor</td></tr>
		<tr><td><b>$NOTE</b>&nbsp;$noteid<br>$note</td><td><b>$PATCH</b>&nbsp; $patchid<br>$patch</td><td><b>$TEST</b>&nbsp; $testid<br>$test</td><td><b>$ASCD:</b><br>$order</td></tr>
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
    print $form;
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
    $self->debug(3, "Formating web query");
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
    my $msgid      = $self->wildcard($cgi->param('messageid')) || '';
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
        my $get_tids = "SELECT bugid FROM tm_user_bug WHERE userid = '$1'";
        $fnd += my @ids = $self->get_list($get_tids);
		print "Found ".@ids." user_bug relations from claimants($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
	if ($patchid =~ /^(\w+)$/) {
		$wnt++;
        my $get_tids = "SELECT bugid FROM tm_bug_patch WHERE patchid LIKE '$1'";
        $fnd += my @ids = $self->get_list($get_tids);
		print "Found ".@ids." bug_patch relations from patchid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
	if ($testid =~ /^(\w+)$/) {
		$wnt++;
        my $get_tids = "SELECT bugid FROM tm_bug_test WHERE testid LIKE '$1'";
        $fnd += my @ids = $self->get_list($get_tids);
		print "Found ".@ids." bug_test relations from testid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
	if ($noteid =~ /^(\w+)$/) {
		$wnt++;
        my $get_tids = "SELECT bugid FROM tm_bug_note WHERE noteid LIKE '$1'";
        $fnd += my @ids = $self->get_list($get_tids);
		print "Found ".@ids." bug_note relations from noteid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
		$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
	if ($patch =~ /(.+)/) {
		$wnt++;
		my $get_ids = "SELECT patchid FROM tm_patch WHERE msgbody like '%$1%'";
		my @ids = $self->get_list($get_ids);
		my $ids = join("', '", @ids);
		$fnd += @ids = $self->get_list("SELECT bugid FROM tm_bug_patch WHERE patchid IN ('$ids')");
		print "Found ".@ids." bug_patch relations from patch content($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
		$sql .= " $andor bugid IN ('$found') ";
    }
	if ($test =~ /(.+)/) {
		$wnt++;
		my $get_ids = "SELECT testid FROM tm_test WHERE msgbody like '%$1%'";
		my @ids = $self->get_list($get_ids);
		my $ids = join("', '", @ids);
		$fnd += @ids = $self->get_list("SELECT bugid FROM tm_bug_test WHERE testid IN ('$ids')");
		print "Found ".@ids." bug_test relations from test content($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') ";
    }
	if ($note =~ /(.+)/) {
		$wnt++;
		my $get_ids = "SELECT noteid FROM tm_note WHERE msgbody like '%$1%'";
		$fnd += my @ids = $self->get_list($get_ids);
		print "Found ".@ids." bug_note relations from note content($1)";
		my $found = join("', '", @ids);	
		$fnd += @ids = $self->get_list("SELECT bugid FROM tm_bug_note WHERE noteid IN ('$found')");
		$found = join("', '", grep(/\w+/, @ids));	
		$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    	}
	if ($changeid =~ /^(.+)$/) {
		$wnt++;
		my $cid = $1;
		my $get_pids = "SELECT DISTINCT patchid FROM tm_patch_change WHERE changeid LIKE '$cid'";
		my @pids = $self->get_list($get_pids);
		my @ids  = ();
		if (scalar(@pids) >= 1) {
			$self->debug(2, "Found ".@pids." patch change relations from changeid($cid)");
			my $found = join("', '", @pids);	
			$fnd += @ids = $self->get_list("SELECT bugid FROM tm_bug_patch WHERE patchid IN ('$found')");
		} else {
			$self->debug(2, "No patches found with changeid($cid), trying with bugs..."); 
			my $sql = "SELECT DISTINCT bugid FROM tm_bug_change WHERE changeid LIKE '$cid'";
			$fnd += @ids = $self->get_list($sql);
			$self->debug(2, "Found ".@ids." bug change relations from changeid($cid)");
		}
		my $found = join("', '", grep(/\w+/, @ids));	
		print "Found bugids(".@ids.") with changeid($cid)";
		$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
	if ($body =~ /(.+)/) {
		$wnt++;
		my $get_mids = "SELECT messageid FROM tm_message WHERE msgbody like '%$1%'";
		my @mids = $self->get_list($get_mids);	
		print "Found ".@mids." messageids from body($1)";
		my $mids = join("', '", @mids);	
		$fnd += my @ids = $self->get_list("SELECT bugid FROM tm_bug_message WHERE messageid IN ('$mids')");
		print "Found ".@ids." message_bug relations from message content($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') ";
    }
	if ($msgid =~ /(.+)/) {
		$wnt++;
		my $get_mids = "SELECT messageid FROM tm_message WHERE LOWER(msgheader) like LOWER('%Message-Id: %$1%')";
		my @mids = $self->get_list($get_mids);	
		print "Found ".@mids." messageids from body($1)";
		my $mids = join("', '", @mids);	
		$fnd += my @ids = $self->get_list("SELECT bugid FROM tm_bug_message WHERE messageid IN ('$mids')");
		print "Found ".@ids." message_bug relations from messageid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
		$sql .= " $andor bugid IN ('$found') ";
    }

    if ($bugid =~ /^\s*(.*\w+.*)\s*$/) {
        $sql .= " $andor bugid LIKE '$1' ";
    }
	if ($version =~ /(.+)/) {
		$wnt++;
		my $x = $1;
		my ($x) = $self->object->('version')->name2id([$x]) if $x !~ /^\d+$/;
        my $get_ids = "SELECT bugid FROM tm_bug_version WHERE versionid LIKE '$x'";
        $fnd += my @ids = $self->get_list($get_ids);
		print "Found ".@ids." bug_version relations from versionid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
	if ($fixed =~ /.+/) {
        $sql .= " $andor fixed LIKE '$fixed' ";
    }
    if ($status =~ /(\w+)/) {
		$wnt++;
		my $x = $1;
		my ($x) = $self->object('status')->name2id([$x]) if $x !~ /^\d+$/;
        my $get_ids = "SELECT bugid FROM tm_bug_status WHERE statusid LIKE '$x'";
        $fnd += my @ids = $self->get_list($get_ids);
		print "Found ".@ids." bug_status relations from statusid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
    if ($category =~ /(\w+)/) {
		$wnt++;
		my $x = $1;
		my ($x) = $self->object('category')->name2id([$x]) if $x !~ /^\d+$/;
        my $get_ids = "SELECT bugid FROM tm_bug_category WHERE categoryid LIKE '$x'";
        $fnd += my @ids = $self->get_list($get_ids);
		print "Found ".@ids." bug_category relations from categoryid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
    if ($severity =~ /(\w+)/) {
		$wnt++;
		my $x = $1;
		my ($x) = $self->object('severity')->name2id([$x]) if $x !~ /^\d+$/;
        my $get_ids = "SELECT bugid FROM tm_bug_severity WHERE severityid LIKE '$x'";
        $fnd += my @ids = $self->get_list($get_ids);
		print "Found ".@ids." bug_severity relations from severityid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
    }
    if ($osname =~ /(.+)/) {
		$wnt++;
		my $x = $1;
		my ($x) = $self->object->('osname')->name2id([$x]) if $x !~ /^\d+$/;
        my $get_ids = "SELECT bugid FROM tm_bug_osname WHERE osnameid LIKE '$x'";
        $fnd += my @ids = $self->get_list($get_ids);
		print "Found ".@ids." bug_osname relations from osnameid($1)";
		my $found = join("', '", grep(/\w+/, @ids));	
        $sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
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
	print "SQL: $sql<hr>" if $sqlshow =~ /y/i;
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

For all application objects

Needs to be migrated to: 

	my $i_ok = Perlbug::Object->new('patch')->read($pid)->update($h_newdata, [$h_reldata...]); 

=cut

sub web_update {
    my $self = shift;
	$self->debug('IN', @_);
    my $nocc = shift || '';
    my $cgi = $self->{'CGI'};
	my @newgroups = split(/\s+/, $cgi->param('addgroup'));
	my ($desc) = split(/\s+/, $cgi->param('adddescription'));
    my @bids = $cgi->param('bugids');
    my @cids = $cgi->param('changeids');
    my @gids = $cgi->param('groupids');
    my @nids = $cgi->param('noteids');
    my @pids = $cgi->param('patchids');
    my @tids = $cgi->param('testids');
	my @uids = $cgi->param('userids');
	my $args = "bugids(@bids), changeids(@cids), groupids(@gids), newgroups(@newgroups), noteids(@nids), patchids(@pids), testids(@tids), userids(@uids)";
	my $total= (@bids.@cids.@gids.@newgroups.@nids.@pids.@tids.@uids);
    my $ok   = 1;
	if (!(scalar($total)) >= 1) {
		$ok = 0;
		my $err = "Nothing($total) selected to update! -> $args";
		print $err;
		$self->debug(0, $err);
	}
	# GROUP
	if ($ok == 1 && scalar @gids >= 1) {
    	my $a_buttons = ($self->can_update(\@gids)) ? [qw(update reset delete)] : [];
		print $self->current_buttons($a_buttons, scalar(@gids));
		$self->debug(1, "groups(@gids)");
    	GROUP:
		foreach my $gid (@gids) {
			next GROUP unless $gid =~ /\d+/;
            next GROUP unless $ok == 1;
			my $o_grp = $self->object('group')->read($gid);
        	my $addr = $cgi->param($gid.'_addaddress') || '';
        	my $desc = $cgi->param($gid.'_description') || '';
        	my @uids = $cgi->param($gid.'_userids');
			# my $o_patch = Patch->new($pid);
			# $i_ok = Patch->new($pid)->references('change', $cid) if $cid;
			my $commands = "description='$desc'";
			my $exists   = $o_grp->exists;
			my $insert   = "INSERT INTO tm_group SET $commands, created=now()";
			my $update   = "UPDATE tm_group SET $commands WHERE groupid='$gid'";
			my $request  = ($exists >= 1) ? $update : $insert;
        	my $sth = $self->exec($request);
			$ok = $self->track('g', $gid, join(':', $gid, $desc));
	    	if (defined($sth)) { # do the rest: (bug/user/address) ids...
				# my @exists = $self->get_list("SELECT address FROM tm_group_address WHERE groupid = '$gid'");
				if ($addr =~ /\w+/) {
					my ($o_addr) = Mail::Address->parse($addr); 
					if (ref($o_addr)) {
						my $o_address = $self->object('address');
						my ($addr) = $self->quote($o_addr->format);
						my $res = $o_address->store( { 'name' => $addr } );
						my $oid = $o_address->attr('objectid');
						my $o_rel = $o_grp->relation('address');
						my $rel = $o_rel->assign([$oid]);
					}
				}
				my $ref = "<p>Group modify($gid, $desc) updated $Mysql::db_errstr<p>";
	    		$self->debug(2, $ref);
				$o_grp->relation('user')->assign(\@uids); # rjsf store!
		    } else {
				my $ref = "<p>Group modify($gid, $desc) failure $Mysql::db_errstr<p>";
	    		$self->debug(1, $ref);
				print $ref;
		    }
    	}
		print '<table border=1>', $self->dog(\@gids), '</table>';
	}	
	if ($ok == 1 && scalar @newgroups >= 1) {
		my @gindb = $self->get_list("SELECT DISTINCT name FROM tm_group");
		NEWGROUP:
		foreach my $newgroup (@newgroups) {
			last NEWGROUP unless $ok == 1;
			if ($newgroup !~ /^\w\w\w+$/) {
				$ok = 0;
				print "Group($newgroup) notallowed: please use at least 3 alphanumerics for group names!<hr>";
			} else {
				if (grep(/^$newgroup$/i, @gindb)) {
					$ok = 0;
					print "Can't recreate existing group($newgroup) in db(@gindb)!";
				} else {	
					my $insert = "INSERT INTO tm_group SET created=now(), name='$newgroup', description='$desc'";
					my $sth = $self->exec($insert);
					if (defined($sth)) {
						my ($gid) = $sth->insertid;
						print "New group: '$newgroup' created($gid)";
						push(@gids, $gid);
					} else {
						print "Failed to create new groups(@newgroups)!";
					}	
				}
			}
		}
        print '<table border=1>', $self->groups(\@gids), '</table>'; 
	}
	# BUG IDs
    if ($ok == 1 && scalar @bids >= 1) {
    	my $a_buttons = ($self->can_update(\@bids)) ? [qw(update nocc reset delete)] : [];
		print $self->current_buttons($a_buttons, scalar(@bids));
		$self->debug(1, "bugs(@bids)");
    	BUG:
		foreach my $bid (@bids) {
            next BUG unless $ok == 1;
			my $o_bug = $self->object('bug')->read($bid);
			next BUG unless $o_bug->ok_ids([$bid]);
			$self->debug(2, "calling dok($bid)");
        	$self->dok([$bid]) unless $self->admin_of_bug($bid, $self->isadmin);
        	my $orig = $self->current_status($bid);
        	my $fixed    = $cgi->param($bid.'_fixed') || '';
			my $update   = "UPDATE tm_bug SET fixed='$fixed' WHERE bugid='$bid'";
        	my $sth = $self->exec($update);
		if (1) {
			my @tracker = ();
			foreach my $rel ($o_bug->rels) {
				next if $rel eq 'message';
				my $o_rel = $o_bug->relation($rel);
				my @update = $cgi->param($bid."_$rel");
				if ($rel =~ /(address|change|version)/i) {
					# $o_rel->create(\@update);
					my $call = ($rel eq 'address') ? '_assign' : '_store';
					$o_rel->$call(\@update);
				} else {
					$o_rel->store(\@update);	
				}
				push(@tracker, "$rel(@update)");
			}
			$ok = $self->track('b', $bid, join(':', @tracker));
			print "track(@tracker)<br>\n";
		} else { 
			my $status   = $cgi->param($bid.'_status') || '';
        	my $category = $cgi->param($bid.'_category') || '';
        	my $severity = $cgi->param($bid.'_severity') || '';
        	my $version  = $cgi->param($bid.'_version') || '';
        	my $osname   = $cgi->param($bid.'_osname') || '';
			$o_bug->relation('status')->store([$status]);
			$o_bug->relation('category')->store([$category]);
			$o_bug->relation('severity')->store([$severity]);
			$o_bug->relation('osname')->store([$osname]);

			$o_bug->relation('version')->create([$version]);
			$o_bug->relation('user')->assign([$self->isadmin]);

			my @changes = split(/\s+/, $cgi->param($bid.'_changes')); 
			$o_bug->relation('change')->create(\@changes);

			my @ccs = split(/\s+/, $cgi->param($bid.'_ccs'));
			$o_bug->relation('address')->create(\@ccs);
			$ok = $self->track('b', $bid, join(':', $status, $category, $severity, $version, $osname, "@changes", "@ccs"));
		} # end if

	    	if (defined($sth)) { # do the rest: notes, patches, tests
				my $ix = $self->notify_cc($bid, '', $orig) unless $nocc eq 'nocc';
				my @parents  = split(/\s+/, $cgi->param($bid.'_parents'));
				my @children = split(/\s+/, $cgi->param($bid.'_children'));
				my ($pcs, @pcs)	= $self->tm_parent_child($bid, \@parents, \@children);
				my $i_newnoteid  = $self->doN($bid, $cgi->param($bid.'_newnote'),  '');
				my $i_newpatchid = $self->doP($bid, $cgi->param($bid.'_newpatch'), '');
				my $i_newtestid  = $self->doT($bid, $cgi->param($bid.'_newtest'),  '');
				
				my @nids = split(/\s+/, $cgi->param($bid.'_notes')); 
				my @pids = split(/\s+/, $cgi->param($bid.'_patches')); 
				my @tids = split(/\s+/, $cgi->param($bid.'_tests')); 

				my ($n, @xnotes)   = $self->tm_bug_note(  $bid, @nids);
				my ($p, @xpatches) = $self->tm_bug_patch( $bid, @pids);
				my ($t, @xtests)   = $self->tm_bug_test(  $bid, @tids);
				if ($i_newpatchid =~ /\w+/ && scalar(@cids) >= 1) {
					$self->debug(1, "given both a new patchid($i_newpatchid) and changeids(@cids), updating patches too!");
					my ($pc, @xpcs) = $self->tm_patch_changeid($i_newpatchid, @cids);
				}
				my $ref = "<p>Bug ($bid) updated $Mysql::db_errstr<p>";
	    		$self->debug(2, $ref);
		    } else {
	        	my $ref = "<p>Bug ($bid) update failure: ($@, $Mysql::db_errstr, $sth).<p>";
				print $ref;
		    }
    	}
		print '<table border=1>', $self->dob(\@bids), '</table>';
	}	
	# PATCH IDs
    if ($ok == 1 && scalar @pids >= 1) {
    	my $a_buttons = ($self->can_update(\@pids)) ? [qw(update reset delete)] : [];
		print $self->current_buttons($a_buttons, scalar(@pids));
		$self->debug(1, "patches(@pids)");
    	PATCH:
		foreach my $pid (@pids) {
			next PATCH unless $pid =~ /\d+/;
            next PATCH unless $ok == 1;
        	my $changeid = $cgi->param($pid.'_changeid') || '';
			# my $o_patch = Patch->new($pid);
			# $i_ok = Patch->new($pid)->references('change', $cid) if $cid;
			my $commands = "changeid='$changeid'";
			my $exists   = ($self->get_list("SELECT changeid FROM tm_patch_change WHERE patchid='$pid'"));
			my $insert   = "INSERT INTO tm_patch_change SET $commands, created=now(), patchid='$pid'";
			my $update   = "UPDATE tm_patch_change SET $commands WHERE patchid='$pid'";
			my $request  = ($exists >= 1) ? $update : $insert;
        	my $sth = $self->exec($request);
			$ok = $self->track('p', $pid, join(':', $pid, $changeid));
	    	if (defined($sth)) { # do the rest: relationships, notes, patches, tests
				my $ref = "<p>Patch_change($pid, $changeid) updated $Mysql::db_errstr<p>";
	    		$self->debug(2, $ref);
		    } else {
				my $ref = "<p>Patch_change($pid, $changeid) failure: ($@, $Mysql::db_errstr)<p>";
	    		$self->debug($ref);
				print $ref;
		    }
    	}
		print '<table border=1>', $self->dop(\@pids), '</table>';
	}	
	# USER IDs
    if ($ok == 1 && scalar @uids >= 1) {
		my $a_buttons = ($self->can_update(\@uids)) ? [qw(update reset delete)] : [];
        print $self->current_buttons($a_buttons, scalar(@uids));
		$self->debug(1, "users(@uids)");
        USER:
        foreach my $uid (@uids) {
			next USER unless $uid =~ /^\w+$/;
            next USER unless $ok == 1;
			$self->debug(0, "updating admin($uid)");
            my $active   = $cgi->param($uid.'_active');
        	my $address  = $cgi->param($uid.'_address');
        	my @groupids = $cgi->param($uid.'_groupids');
            my $name     = $cgi->param($uid.'_name');
        	my $password = $cgi->param($uid.'_password');
            my $pwdupdate= $cgi->param($uid.'_password_update') || 0;
            my $userid   = $cgi->param($uid.'_userid'); 
            $password    = crypt($password, substr($password, 0, 2)) if $pwdupdate;
        	my $match_address = $self->qm($cgi->param($uid.'_match_address'));
            my $ref = qq|uid($uid), userid($userid), active($active), name($name), pass($password), passupd($pwdupdate), match($match_address)|;
            if (!(grep(/\w+/, $uid, $active, $name, $address, $password, $pwdupdate, $match_address) == 7)) {
                $ok = 0;
                $self->error("Not enough data for update: $ref");
            }
            $self->debug(0, "REF: $ref");
			my $sql = '';
            if ($ok == 1) { # user update
				my $commands = qq|password='$password', 
					address='$address', 
					name='$name', 
					match_address=$match_address, 
					active=$active
				|;
                my $exists = $self->get_list("SELECT userid FROM tm_user WHERE userid = '$userid'");
                if (($uid eq 'newAdmin') && (!$exists))  {
                    # $uid = $userid; # only relevant for new data?
	    	        if ($self->isadmin eq $self->system('bugmaster')) {
                        $sql = "INSERT INTO tm_user SET $commands, userid='$userid', created=now()";
                        push(@uids, $userid);
                    } else {
                        $ok = 0;
                        $self->debug(0, "User(".$self->isadmin." can't generate user: ($commands)");
                    } 
                } else {
					$active = $self->quote($active) unless $active eq 'NULL';
	    	        $sql = "UPDATE tm_user SET $commands WHERE userid='$uid'";
                }
            }
            if ($ok == 1) { # track it and do htpass if required
                my $sth = $self->exec($sql);
	    	    if (defined($sth)) {
	        	    my $cnt = $sth->affected_rows;
	        	    my $ref = "<p>User ($uid) updated($cnt) $Mysql::db_errstr<p>";
			        $ok = $self->track('u', $uid, join(':', $uid, $name, $address, $password, $cgi->param($uid.'_match_address')));
	    		    $self->debug(2, $ref);
					if ($ok == 1) {
						my $sth = $self->exec("DELETE FROM tm_group_user WHERE userid = '$uid'");
						if (defined($sth)) {
							foreach my $gid (@groupids) {	
								my $sth = $self->exec("INSERT INTO tm_group_user SET created=now(), groupid='$gid', userid='$uid'"); 
							}
						}
					}
		            if ($ok == 1) {
                        $ok = $self->htpasswd($uid, $password) if $pwdupdate || $userid eq 'newAdmin';
                    }
                } else {
	        	    my $ref = "<p>Admin ($uid) command failure: ($@, $Mysql::db_errstr, $sth).<p>";
	    		    print $ref;
		        }
            }
    	}
		print '<table border=1>', $self->dou(\@uids), '</table>';
	}	
	# UPDATE DONE
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
	my $pid     = $self->{'range'};
	my $ok 		= 1;
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
	            $range .= qq|<a href="$url?req=bid$bids&range=$pid&format=$fmt&trim=$slice">$min to $max</a>&nbsp;\n|;
	            $min = $max + 1; 
	            $bids = '';
	            $cnt = 0;
	        } 
	    }
		$self->range($pid, "<table><tr><td>$range</td></tr></table>");	# store data
    }
    return $ok;
}


=item range

Store and retrieve range of bugs, by numerical id.

	my ($new_id, $ret) = $o_web->range($processid, $data);

=cut

sub range {
	my $self = shift;
	my $pid  = shift;
	my $data = shift || '';
	my $id   = '';
	my $ok 	 = 1;
	if ($pid !~ /^\d+$/) {
		$ok = 0;
		$self->debug(0, "Cannot get/set range() without a pid($pid)");
	} else {
			my $qdata = $self->quote($data);
			my $insert = qq|INSERT INTO tm_range SET created=now(), processid='$pid', range=$qdata|;	
			my $sth = $self->exec($insert);
			if (!defined($sth)) {
				$ok = 0;
				$self->debug(0, "failed to insert($insert)");
				($pid, $data) = ('', '');
			} else {
				$id = $sth->insertid;
			}
	}
	return ($id, $data);
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

Richard Foley perlbug@rfi.net Oct 1999 2000

=cut

1;

