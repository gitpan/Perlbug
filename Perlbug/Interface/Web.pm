# Perlbug WWW interface
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Web.pm,v 1.94 2001/04/21 20:48:48 perlbug Exp $
# 

=head1 NAME

Perlbug::Interface::Web - Web interface to perlbug database.

=head1 DESCRIPTION

Methods for web access to perlbug database via L<Perlbug> module.

=cut

package Perlbug::Interface::Web; 
use strict;
use vars qw(@ISA $VERSION);
@ISA = qw(Perlbug::Base);
$VERSION = do { my @r = (q$Revision: 1.94 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Interface_Web_DEBUG'} || $Perlbug::Interface::Web::DEBUG || '';
$| = 1; 

use lib qw(../);
use CGI;
use CGI::Carp 'fatalsToBrowser';
use Data::Dumper;
use HTML::Entities;
use Perlbug::Base; 
use Perlbug::Format; # href's
use Perlbug::JS;
use URI::Escape;


=head1 SYNOPSIS

	my $o_web = Perlbug::Interface::Web->new;
	
	print $o_web->header;
	
	print $o_web->request('help');
	
	print $o_web->footer;
	

=head1 METHODS

=over 4

=item new

Create new Perlbug::Interface::Web object.

	my $web = Perlbug::Interface::Web->new;

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $self  = Perlbug::Base->new();
	bless($self, $class);

	$self->cgi(@_);
    $self->check_user($ENV{'REMOTE_USER'});
    $self->setup; # default pars etc.
	$self->clean_cache('sql'); # mod_perl
	return $self;
}


=item setup

Setup Perlbug::Interface::Web

    $o_web->setup($cgi);

=cut

sub setup {
    my $self = shift;
    my $cgi  = $self->cgi();

	($DEBUG) = $Perlbug::DEBUG || $cgi->param('debug') || $DEBUG;
	($DEBUG) = $self->current({'debug', $DEBUG}) if $DEBUG; 

    $self->{'_range'} = $cgi->param('range') || '';

	my $framed = ($0 =~ /_([a-z]+\.{0,1})cgi$/) ? 0 : 1;
	$self->current({'framed', $framed}); 
	$self->debug(0, "$0 => framed($framed)") if $DEBUG;

	$self->current({'format', $cgi->param('format') || 'h'});
	$self->current({'context', 'http'});

	$self->debug(0, "Web::setup :-)") if $DEBUG;
	
    return $self;
}


=item check_user

Access authentication via http, we just prime ourselves with data from the db as well.

=cut

sub check_user { 
	my $self = shift;
	my $remote_user = shift || '';
	my $user = '';
    if (defined($ENV{'REQUEST_URI'}) && ($ENV{'REQUEST_URI'} =~ /\/admin/i)) {
		$user = $self->SUPER::check_user($remote_user); # Base
		$self->debug(1, "Checked user($remote_user)->'$user'") if $DEBUG;
	} else {
		$user = $self->SUPER::check_user(''); # Base
		# $user = $self->current('admin', '');
		$self->debug(2, "Neutralising user($remote_user)->$user") if $DEBUG;
	}
	return $user; 
}


# SETUP 
# ============================================================================ #
#

=item menu 

Return menu of system, designed for vertical format.  Wraps logo, title and links

	print $o_web->menu();

=cut

sub menu {
	my $self = shift;
	
	my $ret = $self->logo.$self->title.$self->links();
	# links = (menu) ? menu : links=~s/tr/br/

	$ret =~ s/<(table|tr|td)[^>]*(?:>)//gsi;
	$ret =~ s/<\/td>/<br>/gsi;
	$ret =~ s/<\/(tr|table)>//gsi;
	$ret .= '<hr>'.$self->isadmin;

	return $ret;
}


=item logo 

Return logo of system

	print $o_web->logo();

=cut

sub logo {
	my $self = shift;
	my $logo = '';
	
	my $home = $self->web('hard_wired_url');
    $logo = qq|<center><a href="$home" target="_top">|.$self->web('logo').'</a></center>';

	return $logo;
}


=item title

Return title of current page

	print $o_web->title();

=cut

sub title {
	my $self = shift;

    my $title = '<center><h3>'.$self->system('title').' '.$self->version.'</h3></center>';

	return $title;
}


=item links 

Return links of system

	print $o_web->links();

=cut

sub links {
	my $self = shift;
	my $links = '&nbsp; links';
	
    $links = join('', $self->read('footer'));

	my $url = $self->url;
    if ($self->isadmin) {
		$links =~ s#\Q<!-- FAQ -->\E#<td><a href="perlbug.cgi?req=adminfaq" target="perlbug" onClick="return go('adminfaq');">Admin FAQ<\/a><\/td>#;
	}
	$links =~ s/(perlbug\.cgi)/_$1/gi unless $self->current('framed');# url =~ /_perlbug\.cgi/i;

	return $links;
}


=item index 

Display the index results here...

=cut

sub index {
	my $self = shift;
	my $ret  = '';
	
	my $url   = $self->url;
	my $ehelp = $self->email('help');
	$ret .= $self->logo;
	$ret .= $self->title;
	$ret .= qq|
		<center>
		<h4>
		Anyone may search the bug Database via either the <a href="mailto:$ehelp">email</a> 
		or the <a href="$url">web</a> interface.
		</h4>
		<hr>

		<a href="perlbug.cgi?req=search"><h3>Enter BUG squashing arena!</h3></a>
		<a href="_perlbug.cgi?req=search&target=_top&frames=no"><h5>No Frames version!</h5></a>

		<h4>Or enter a quick search on just the subject line of submitted bugs which are still open:</h4>
		<input type=hidden name=req value=query>
		<input type=hidden name=status value=open>
		<input type=hidden name=trim value=35>
		<input type=hidden name=index value=yes>
		<input type=text name=subject value="">
		<br><i>
		N.B. - Shortcuts to bugids if the text matches a bugid pattern 
		</i> <br>

		<hr>
		</center>
	|;

	return $ret;
}


=item commands

Return command buttons applicable to current request 

	print $o_web->commands();

=cut

sub commands {
	my $self = shift;
	my $req  = shift;

	my $cgi  = $self->cgi();
	my $ret  = '';

	# Commands
	my %com = ( # back home refresh search
		'nix'	=> [qw()],
		'read'	=> [qw(query reset)], 
		'write'	=> [qw(query update nocc select unselect reset delete)], 
	);
	
	my $a_cmds = ($req =~ /^(commands|index|search)$/i) ? $com{'read'} : $com{'nix'};
	if ($self->isadmin) {
		my $opts = join('|', $self->editable);
		$a_cmds = $com{'write'} if $req =~ /^($opts)$/i;
	}
	$ret .= '<br>'.$self->current_buttons($a_cmds).'<br>';

	# Controls
	if (1 == 0 && $self->isadmin eq $self->system('bugmaster')) {
		my $o_js = Perlbug::JS->new();
		$ret .= "\n".join("&nbsp;\n", '',
			# $o_js->frames(),
			$o_js->control('menu'),
			$o_js->control('perlbug'),
			$o_js->control('commands'),
		);
	}	
	$self->debug(2, "req($req) cmd($a_cmds) ret($ret)") if $DEBUG;

	return $ret;
}


=item editable 

Return list of acceptable requests

	print "administrative requests: " . $o_web->editable;

=cut

sub editable { # 
	my $self = shift;
	my @reqs = qw(
		 \w+ids{0,1}
		 administrators
		 commands
		 date
		 delete
		 groups
		 nocc
		 query
		 sql
		 update
	);
	return @reqs;
}


# PROCESS 
# ============================================================================ #
#

=item switch

Return appropriate method call for request(else index), using internal CGI object

	my $method = $o_web->switch([$req]); # set $method=($call|index)

=cut

sub switch {
	my $self = shift;
	my $req  = shift;
	my $ret  = '';

	$req = $req || $self->cgi()->param('req') || 'index';

	my @ok = qw(
		menu perlbug commands index
		start header logo title links footer finish
		headers objectids hist bidmids date
		spec mailhelp webhelp overview groups administrators
		query nocc sql delete update info search
	); # (bug|status|user)_(ids|headers|search)

    if ($req =~ /^\w+$/) { 
		$ret = $req;
	} else {
        $self->error("Invalid request($req)");
	}
	$self->debug(0, "requested($req) -> returning($ret)") if $DEBUG ;

	return $ret;
}


=item start

Return appropriate start header data for web request.

Varies with framed, includes dump.

	print $o_web->start();

=cut

sub start { # index/display/top - see also finish
	my $self = shift;
	my $req  = shift;
	my $ret  = '';
    my $cgi  = $self->cgi();

	$self->debug(1, "start($req)") if $DEBUG;

	$ret .= $self->header($req);

	unless ($self->current('framed')) {
		$ret .= $self->logo($req);
		$ret .=$self->title($req);
	}

	# $ret .= $cgi->dump if $self->isadmin eq $self->system('bugmaster');

	$ret .= qq|<table border=1 width=100%>|;
	my $target = ($req =~ /^(menu|commands)$/i) ? $1 : 'perlbug';
	$ret .= $self->form($target);

	unless ($self->current('framed')) {
		$ret .= $self->commands($req);
	}

	return $ret;
}


=item form

Return form with appropriate name and target etc.
	
	print $o_web->form('menu');

=cut

sub form {
	my $self = shift;
	my $name = shift || 'undefined_form';

	my $url  = $self->url;
	my $form = qq|<FORM name="$name" method="post" action="$url">|;

	return $form;
}


=item header

Return consistent header.

	print $o_web->header;

=cut

sub header { #web 
    my $self = shift;
	my $req  = shift;
	my $ret  = '';

    my $cgi  = $self->cgi();
	my $url  = $self->url;
	my $title = $self->system('title');
	my $version = $self->version;

	$ret .= $cgi->header(
		-'expires'	=> '+15m',
		-'type'		=> (($req eq 'graph') ? '/image/png' : 'text/html'),	
	);

	$title = qq|$title Web Interface $version $req|; 
	my $call = ($req =~ /(commands|menu)/) ? $1 : 'perlbug';
	my $functions = Perlbug::JS->new()->$call();

	$ret .= $cgi->start_html(
		-'script'	=> $functions,
		-'title'	=> $title,
	);

	$self->debug(3, "req($req) -> $call -> header($ret)") if $DEBUG;

    return $ret;
}


=item request

Handle all web requests
	
	$o_web->request($call);

=cut

sub request {
    my $self = shift;
	my $req  = shift;
	my $ret  = '';

    my $cgi  = $self->cgi();
	    
	my $orig = $req;
    if (defined($req)) {
		$req = 'headers' 	if $req =~ /^(\w+)_header$/i; 	
		$req = 'objectids' 	if $req =~ /^(\w+)_id$/i;
		$req = 'spec' 		if $req =~ /^info$/i;
		$req = 'update' 	if $req =~ /^nocc$/i;
		$req = 'web_query' 	if $req =~ /^query$/i;
    }
	$self->debug(0, "Web::request($req) accepted"); 
		
    if (!($self->can($req))) { # ok and can
		$self->error("unsupported request($req)!");
	} else {
		if ($req !~ /^delete|sql|update$/i) {
			print $self->$req($orig);
		} else {
			if ($self->isadmin =~ /^(\w+)$/) {
				print $self->$req();
			} else {
				$self->error("User(".$self->isadmin.") not permitted for action($req)");
			}
		}	
	}

	$self->debug(0, "Web::request($req) done");

    return '';
}


=item target2file

Return appropriate dir/file.ext for given target string

	my $filename = $o_base->target2file('header'); 
	
	# -> '/home/richard/web/header.html'

=cut

sub target2file {
	my $self = shift;
	my $tgt  = shift;
	my $file = '';

	if ($tgt !~ /\w+/) {
		$self->error("can't remap duff target($tgt)!");
	} else {
		$file = $self->directory('web').$self->system('separator').$tgt.'.html';
	}

	return $file;
}


=item finish

Return appropriate finishing html

Varies with framed, includes new hidden request field

	print $o_web->finish($req);

=cut

sub finish { # index/display/bottom/base - see also start
	my $self = shift;
	my $req  = shift;
	my $ret  = '';

    my $cgi  = $self->cgi();

	my $range = $self->{'_range'};
	if ($self->current('framed')) {
		$ret .= $cgi->hidden(
			-'name' 	=> 'req', 
			-'default' 	=> '',
			-'override'	=> 1
		) unless $req =~ /index/i; # has it's own
		$ret .= $cgi->hidden(
			-'name' 	=> 'range', 
			-'default' 	=> $range,
			-'override'	=> 1
		);
	}
	$ret .= '<tr><td colspan=100%>'.$self->ranges($self->{'_range'}).'</td></tr>' if $range;
	$ret .= '</table>';

	unless ($self->current('framed')) {
		$ret .= $self->commands($req);
		$ret .= $self->links($req);
	}

	$ret .= $cgi->end_form.$cgi->end_html;

	$self->debug(3, "ret($ret)") if $DEBUG;

	return $ret;
}


# REQUESTS 
# ============================================================================ #


=item overview

Wrapper for doo method

=cut

sub overview {
    my $self = shift;
    print $self->doo('h');
}


=item graph

Display pie or mixed graph for groups of bugs etc., mixed to come.

=cut

sub graph {
	my $self = shift;

    my $cgi  = $self->cgi();
	my $flag = $cgi->param('graph') || 'status';
	my $title = $self->system('title');

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
		print "<h3>Graph functionality unsupported, talk to the webmaster($maintainer) :-(</h3><br>";
		$self->debug(0, "Failed to load GD::Graph $!") if $DEBUG;
	} else {	
		my $gd = GD::Graph::pie->new(300, 300);       
		#        'types'        => [qw(pie lines bars points area linespoints)],
		#        'default_type' => 'points',
		#);
		#$gd->set_legend( qw( one two three four five six )); # mixed or points only?
		$gd->set(
			'axislabelclr'     => 'black',
			'title'            => "$title overview ($flag)",
		);
		my $graph = $gd->plot([\@keys, \@vals]); 
		my $image = $graph->png; 
		binmode STDOUT;
		print $image;
	}

	return '';
}


=item date

Wrapper for search by date access

=cut

sub date {
    my $self = shift;

    my $cgi  = $self->cgi();

    my $date = $cgi->param('date');
    $self->debug(1, "date($date)") if $DEBUG;
    my $filter = '';

    if ($date =~ /^\d{8}$/) {
		$filter = "TO_DAYS($date)";	
		$self->debug(0, "using given date($date)") if $DEBUG;
    } elsif ($date =~ /^\d+$/) {
		$filter = "TO_DAYS($date)";	
		$self->debug(0, "using non-norm given date($date)") if $DEBUG;
    } elsif ($date =~ /^\-(\d+)$/) {
		$filter = "(TO_DAYS(now())-$1)";	
		$self->debug(0, "using minus given num($date)") if $DEBUG;
    } else {
		$filter = "TO_DAYS(now()) - 10";	
		$self->debug(0, "unrecognised date($date) format(should be of the form: 20001015), using($filter)") if $DEBUG;
    }

	my $o_bug = $self->object('bug');
    my @bids = $o_bug->ids("TO_DAYS(created) >= $filter"); 

	foreach my $id (@bids) {
		print $o_bug->read($id)->format;
	}

    return '';
}


=item objectids

Wrapper for object id access

	$o_web->objectids($cgi);

=cut

sub objectids {
    my $self = shift;
    my $cgi  = $self->cgi();

	my ($obj) = my ($req) = lc($cgi->param('req'));
	$obj =~ s/^(\w+)_id$/$1/;
    my @ids = $cgi->param("${obj}_id");
	my $trim = $cgi->param('trim') || 50;

	my $objects = join('|', $self->things('mail'), $self->things('item'), $self->things('flag'));
	$self->debug(0, "req($req) obj($obj) object($objects) ids(@ids)") if $DEBUG;

	if ($obj !~ /^($objects)$/) {
		print "<h3>unrecognised obj($obj) header request($req)</h3>";
	} else {
		$#ids = $trim if $trim <= scalar(@ids);
		my $o_obj = $self->object($obj);
		foreach my $oid (@ids) {
			$o_obj->read($oid);
			print $o_obj->format if $o_obj->READ && $o_obj->exists([$oid]);
		}
    }

    return '';
}


=item hist

History mechanism for bugs and users.

Move formatting to Formatter::history !!!

=cut

sub hist {
    my $self = shift;
    my $cgi  = $self->cgi();

    my ($bid) = $cgi->param('hist');
    $self->debug(1, "hist: bid($bid)") if $DEBUG;

    my ($bik) = $self->href('bug_id', [$bid], $bid);
    my $title = $self->system('title');
    my $hist = qq|<table border=1>
        <tr><td colspan=3 width=500><b>$title bug ($bik) history</td/></tr>
        <tr><td><b>Admin</b></td><td><b>Entry</b></td><td><b>Modification</b></td></tr>
    |;
    my $sql = "SELECT * FROM pb_log WHERE objectkey = 'bug' AND objectid = '$bid' ORDER BY modified DESC"; 
    my @data = $self->get_data($sql);
	my $o_usr = $self->object('user');
    foreach my $data (@data) {
		next unless ref($data) eq 'HASH';
		my %data = %{$data};
		my $admin = $data{'userid'};
		$o_usr->read($admin);
		if ($o_usr->READ) {
			my $h_usr = $o_usr->htmlify($o_usr->_oref('data'));
			my $name = $$h_usr{'name'}.' '.$$h_usr{'address'}; 
			my $date = $data{'ts'};
			my $entry = $data{'entry'}; 
			$hist .= qq|<tr><td>$name</td><td>$data{'objectkey'} &nbsp;<pre> $entry</pre></td><td>$data{'modified'}</td></tr>|;	
		}
    }
    $hist .= '</table>';
    print $hist;
    return '';
}


=item headers

Headers for all objects (message, note, ...) by id 

	$o_web->header('patch', $id);	

=cut

sub headers {
    my $self = shift;
    my $cgi  = $self->cgi();

	my ($obj) = my ($req) = lc($cgi->param('req'));
	$obj =~ s/^(\w+)_header$/$1/;
    my ($id)  = $cgi->param("${obj}_header"); # only going to support one for the moment

	my $objects = join('|', $self->things('mail'), $self->things('item'), $self->things('flag'));
	$self->debug(0, "req($req) obj($obj) object($objects) ids($id)") if $DEBUG;

	if ($obj !~ /^($objects)$/) {
		$self->error("Can't do invalid obj($obj) id($id) header request($req)");
	} else {
		$obj = 'bug' if $obj =~ /parent|child/i;
    	my ($item) = $self->href($obj.'_id', [$id], $id);
    	my $title = $self->system('title');
    	my $headers = qq|<table border=1>
        	<tr><td colspan=3 width=500><b>$title $obj ($item) headers</td/></tr>
    	|;
		my $data = $self->object($obj)->read($id)->data('header');
    	$headers .= "<tr><td colspan=3>&nbsp;";
		$data = encode_entities($data);
		$headers .= qq|<tr><td><pre>$data &nbsp;</pre></td></tr>|;	
    	$headers .= '</td></tr></table>';
    	print $headers;
    }

	return '';
}


=item bidmids

Wrapper for bugid and messageid access

=cut

sub bidmids {
    my $self = shift;
    my $cgi  = $self->cgi();

    my @bids = $cgi->param('bidmids');

	foreach my $bid (@bids) {
		print $self->doB([$bid]);
	}

    return '';
}


=item administrators

List of administrators

=cut

sub administrators {
    my $self  = shift;
    my $cgi   = $self->cgi();
    my $url   = $self->url;
    my $title = $self->system('title');
    print qq|<h2>$title administrators:</h2>|;

	my $o_usr  = $self->object('user');
	my $filter = ($self->isadmin eq $self->system('bugmaster'))
		? ''
		: "active IN ('1', '0')";
	my @admins = $o_usr->ids($filter);
   
    foreach my $oid (@admins) {
		print $o_usr->read($oid)->format;
	}

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
    return '';
}


=item groups 

List of groups

=cut

sub groups {
    my $self  = shift;
    my $cgi   = $self->cgi();
    my $url   = $self->url;
    my $title = $self->system('title');
    print qq|<h2>$title groups:</h2>|;
   
    my $o_grp = $self->object('group');
    my $o_usr = $self->object('user');
	my @gids = $o_grp->ids; 

    foreach my $oid (@gids) {
		print $o_grp->read($oid)->format;
	}

	if ($self->isadmin =~ /\w+/ and $self->isadmin ne 'generic') { # addgroup
		my $add = $cgi->textfield(-'name' => 'addgroup', -'value' => '', -'size' => 20, -'maxlength' => 20, -'override' => 1);
		my $groups = "</table><hr><table border=0>";

		$groups .= "<tr><td><b>Add a new group (alphanumeric only):</b></td><td>&nbsp;$add</td></tr>";

		my $desc = $cgi->textfield(-'name' => 'adddescription', -'value' => '', -'size' => 35, -'maxlength' => 99, -'override' => 1);
		$groups .= "<tr><td><b>Description for new group:</b></td><td>&nbsp;$desc</td></tr>";

		my $admins = $o_usr->selector('addusers');
		$groups .= "<tr><td><b>New group members:</b></td><td>&nbsp;$admins</td></tr>";
		
		$groups .= "</table><hr>";
		print $groups;
	}

	return '';
}


=item spec

Returns specifications for the Perlbug system.

=cut

sub spec {
    my $self    = shift;
	my ($dynamic) = $self->SUPER::spec; # Base
	my $spec = join('', $self->read('spec'));
=pod
	$spec .= qq|
		<hr>
		<h3>The following categories are registered:</h3>
	|;
	my %flags = $self->all_flags;
	foreach my $key (keys %flags) {
	    my $vals = join(', ', $self->flags($key));
	    $spec .= sprintf('%-15s', '<b>'.ucfirst($key).'</b>:')."$vals<br><br>\n";
	}

	$dynamic =~ s/\</&lt;/g;
	$dynamic =~ s/\>/&gt;/g;
	$dynamic =~ s/\b(http\:.+?perlbug\.cgi)\b/<a href="$1">$1<\/a>/gi;
	$dynamic =~ s/\b([\<\w+\-_\.\>|\&.t\;]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;
=cut
	my $dynaspec = qq|
		<table border=0 align=center>
			<tr><td><pre>$dynamic</pre></td></tr>
			<tr><td><pre>$spec</pre></td></tr>
		</table>
	|;
	print $dynaspec;
    return '';
}


=item webhelp

Web based help menu for perlbug.

	print $web->webhelp;

=cut

sub webhelp { #web help 
	my $self = shift;

	my $perlbug = $self->SUPER::help; # Base
	my $webhelp = join('', $self->read('webhelp'));

	# rjsf - may not need to do all this
	# $perlbug_help =~ s/\b(http\:.+?perlbug\.cgi(?:\?.+)*)*\b/<a href="$1">$1<\/a>/gi;
	# $perlbug_help =~ s/\b([\<\w+\-_\.\>]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;

	my $help = qq|
		<table align=center>
			<tr><td><pre>$perlbug</pre><hr></td></tr>
		</table>
		<hr>
		<table border=0 align=center>
			<tr><td> $webhelp </td></tr>
		</table>
    |;	
	print $help;

	return '';
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
	my $help = join('', $self->read('mailhelp'));
	my $total = $self->object('bug')->ids;
	$perlbug_help =~ s/\b(http\:.+?perlbug\.cgi(?:\?.+)*)*\b/<a href="$1">$1<\/a>/gi;
	$perlbug_help =~ s/\b([\<\w+\-_\.\>]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gi;
	my $HELP = qq|
		<table align=center>
			<tr><td><pre>$perlbug_help</pre><hr></td></tr>
		</table>
		<hr>
		<table border=0 align=center>
			<tr><td><pre>$help</pre></td></tr>
		</table>
    |;	
	print $HELP;
	return '';
}


=item delete

Wrapper for delete access

=cut

sub delete {
    my $self = shift;
    my $cgi  = $self->cgi();

	my @bugids = $cgi->param('bugids');
	if (scalar @bugids >= 1) {
	 	my $res = $self->dox(\@bugids); # doX handled by bugfix
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
	return '';
}


=item sql

Open field sql query processor

=cut

sub sql {
    my $self = shift;
    my $cgi  = $self->cgi();

    my $sql = $cgi->param('sql');
    $sql =~ s/^\s*\w+(.*)$/SELECT $1/;
    my ($res) = $self->doq($sql);

    return $res;
}


=item todo

To do list, may be appended to

=cut

sub todo { # mailto -> maintainer
    my $self = shift;
	my $cgi = $self->cgi();
	my $tup = $cgi->param('append');
	if (defined($tup) && $tup =~ /\w+/ && length($tup) < 500) {
		# just append it
		my $spacer = '       '; # 7
		$self->debug(0, "Appending to todo: data($tup)") if $DEBUG;
		$self->append('todo', "\n$spacer $tup\n"); 
		# my $i_todo = $self->SUPER::todo($tup); # mail out
	}
	my $todo = join('', $self->read('todo'));
    print "<pre>$todo</pre>";
    return '';
}


=item adminfaq

adminFAQ

=cut

sub adminfaq { # ...
    my $self = shift;
	my $cgi = $self->cgi();
	my $adminfaq = join('', $self->read('adminfaq'));
    print "<pre>$adminfaq</pre>";
    return '';
}


=item web_query

Form bugid search web query results

=cut

sub web_query {	# results - don't map to query() unless Base::query modified
    my $self = shift;
    my $cgi  = $self->cgi();

    my $sql = $self->format_query($cgi);

	my $o_bug = $self->object('bug');
	my $found = my @bids = $o_bug->ids($sql);
	print "Found $found bug ids<br>";

	if (@bids) {
		my $o_rng = $self->object('range');
		$o_rng->create({
			'rangeid'	=> $o_rng->new_id,
			'processid'	=> $$,
			'range'		=> join(',', @bids), # $o_rng->relation('bug')->assign(\@bids); # ouch!
		});
		$self->{'_range'} = $o_rng->oid if $o_rng->CREATED; 
	}

	my $trim = $cgi->param('trim') || 25;
	if (($trim !~ /^\d+$/) || ($trim >= 2501)) {
		print "Sorry trim($trim) is not conducive to system health - reducing to 101<br>\n";
		$trim = 101;
	}

	if ($found >= $trim) {
        print "Showing '$trim'<br>" if $trim =~ /\d+/;
		$#bids = $trim - 1 if $trim =~ /^\d+$/;
    } 

	print map { $o_bug->read($_)->format } @bids; # :-)

	return '';
}


=item search

Search form into result

	with chosen params as defaults...

=cut

sub search {
    my $self = shift;
    my $cgi = $self->cgi();
	my $o_bug = $self->object('bug');
	my @bugs  = $o_bug->ids;
	# my @sourceaddr = $o_bug->col('sourceaddr');

	# Elements
    $self->debug(3, "Setting search form elements...") if $DEBUG;   
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
	my $group    = $self->object('group')->popup('group', 'any');
	my $osnames  = $self->object('osname')->popup('osname', 'any');
	my $project  = $self->object('project')->popup('project', 'any');
	my $severity = $self->object('severity')->popup('severity', 'any');
	my $status   = $self->object('status')->popup('status', 'any');

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
    my $url = $self->url;
    # Form <form name="bug query" method="post" action="$url"> 
	my $withbug  = $cgi->radio_group(-'name' => 'withbug',	-'values' => ['Yes', 'No'], -'default' => 'Yes', -'override' => 1); 
	my $order  = $cgi->radio_group(-'name' => 'order',	-'values' => ['Asc', 'Desc'], -'default' => 'Desc', -'override' => 1); 
	# HELP
	my $BUG   	= $self->help_ref('bug',	'Bug ID');
	my $VERSION	= $self->help_ref('version', 'Version');
	my $FIXED 	= $self->help_ref('fixed', 'Fixed in');
	my $CHANGE	= $self->help_ref('change', 'Change ID');
	my $STAT	= $self->help_ref('status', 'Status');
	my $CAT		= $self->help_ref('group', 'Group');
	my $SEV		= $self->help_ref('severity', 'Severity');
	my $OS		= $self->help_ref('osname', 'OSname');
	my $SUBJ	= $self->help_ref('subject', 'Subject');
	my $BODY 	= $self->help_ref('body', 'Body');
	my $MSGID   = $self->help_ref('message_id', 'Message-Id');
	my $SRCADDR = $self->help_ref('source_addr', 'Source address');
	my $DATES	= $self->help_ref('dates', 'Dates');
	my $ADMIN   = $self->help_ref('admin', 'Administrator');
	my $RESTRICT= $self->help_ref('restrict', 'Restrict returns to');
	my $FMT		= $self->help_ref('format', 'Formatter');
	my $SHOWSQL = $self->help_ref('show_sql', 'Show SQL');
	my $ANDOR	= $self->help_ref('and_or', 'Boolean');
	my $ASCD	= $self->help_ref('asc_desc', 'Asc/Desc by bugid');
	my $NOTE	= $self->help_ref('note', 'Note ID');	# <a href="$url?req=help">help</a>	
	my $PATCH 	= $self->help_ref('patch', 'Patch ID');
	my $TEST	= $self->help_ref('test', 'Test ID');
	my $PROJECT = $self->help_ref('project', 'Project');
	my $form = qq|
	    <table border=1><tr><td colspan=5><i>
	    Select from the options (see <a href="$url?req=help">help</a>) available, then click the query button.<br>  
	    </td></tr>
	    <tr><td><b>$BUG:</b><br>$bugid</td><td><b>$VERSION:<br></b>&nbsp;$version</td><td><b>$FIXED:<br></b>&nbsp;$fixedin</td><td><b>$CHANGE</b><br>$changeid</td></tr>
	    <tr><td><b>$STAT:</b><br>$status</td><td><b>$CAT:</b><br>$group</td><td><b>$SEV:</b><br>$severity</td><td><b>$OS:</b><br>$osnames</td></tr>
	    <tr><td colspan=2><b>$SUBJ:</b>&nbsp;$subject</td><td colspan=2><b>$SRCADDR:</b>&nbsp;$sourceaddr</td></tr>
	    <tr><td colspan=2><b>$BODY:&nbsp;&nbsp;&nbsp;</b>&nbsp;$body</td><td colspan=2><b>$MSGID:</b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$msgid</td></tr>
	    <tr><td><b>$DATES:</b><br>$date</td><td colspan=2><b>$ADMIN</b><br>$admins</td><td><b>$RESTRICT</b>:<br>$restrict</td></tr>
	    <tr><td colspan=2><b>$FMT:<br></b>$format</td><td><b>$SHOWSQL:<br></b>$sqlshow<hr><b>$ANDOR:</b><br>$andor</td><td><b>$PROJECT:<br></b>$project</td></tr>
		<tr><td><b>$NOTE</b>&nbsp;$noteid<br>$note</td><td><b>$PATCH</b>&nbsp; $patchid<br>$patch</td><td><b>$TEST</b>&nbsp; $testid<br>$test</td><td><b>$ASCD:</b><br>$order</td></tr>
		</table>
    |;
=pod
	my $input = $cgi->textarea(-'name' => 'sql', -'default' => 'your select query here', -'rows' => 5, -'columns' => 50);
    my $sqlinput = qq|<hr>
        Alternatively query directly from here:&nbsp<b>SELECT</b>... <br>
        <form name="sql" method="post" action="$url" target="perlbug">
        $input<br>
    |;
    if ($self->isadmin && $self->isadmin ne 'generic') { 
    # if ($self->isadmin eq $self->system('bugmaster')) { # could be all active admins? 
        $form .= $sqlinput;    
    }
    $self->debug(3, "Form: '$form'\nSQLinput: '$sqlinput'") if $DEBUG;
=cut
    return $form;
}


=item update

For all application objects

Needs to be migrated to: 

	my $i_ok = Perlbug::Object->new('patch')->read($pid)->update($h_newdata, [$h_reldata...]); 

=cut

sub update {
    my $self = shift;
    my $req  = shift;

	my $nocc = ($req eq 'nocc') ? 1 : 0;
	my $orig_fmt = $self->current('format');
	my $orig_cxt = $self->current('context');

    my $cgi = $self->cgi();
    my $newgroup = $cgi->param('addgroup');
    my $desc = $cgi->param('adddescription');
    my @bids = $cgi->param('bugids');
    my @cids = $cgi->param('changeids');
    my @gids = $cgi->param('groupids');
    my @nids = $cgi->param('noteids');
    my @pids = $cgi->param('patchids');
    my @tids = $cgi->param('testids');
	my @uids = $cgi->param('userids');
	my $args = "bugids(@bids), changeids(@cids), groupids(@gids), newgroup($newgroup), noteids(@nids), patchids(@pids), testids(@tids), userids(@uids)";
	my $total= (@bids.@cids.@gids.@nids.@pids.@tids.@uids.scalar($newgroup));
    my $ok   = 1;
	if (!(scalar($total)) >= 1) {
		$ok = 0;
		my $err = "Nothing($total) selected to update! -> $args";
		$self->error($err);
	} else {
		$self->debug(1, "working with $args") if $DEBUG;
	}

=pod
	foreach my $obj ($self->things()) { # ...
		my $o_obj = $self->object($obj);
		my @ids = $cgi->param("${obj}ids");
		foreach my $oid (@ids) {
			$o_obj->read($oid)->web_update($cgi);
			foreach my $rel ($o_obj->rels) {
				# my $o_rel = $o_obj->rel($rel)->set_source($o_obj);
				# if ($self->attr('type') eq 'friendly') {
				# 
				# }
				# 
			}
			print $o_obj->format; 
		}
	}
=cut
	# GROUP
	if ($ok == 1 && scalar @gids >= 1) {
		my $o_grp = $self->object('group');
		$self->debug(1, "groups(@gids)") if $DEBUG;
    	GROUP:
		foreach my $gid (@gids) {
			next GROUP unless $gid =~ /\d+/;
            next GROUP unless $ok == 1;
			my $o_grp = $self->object('group')->read($gid);
			if ($o_grp->READ) {
				my $desc = $cgi->param($gid.'_description') || '';
				my $name = $cgi->param($gid.'_name') || '';
				$o_grp->update({
					'name'			=> $name,
					'description' 	=> $desc,
				});

				my @uids = $cgi->param($gid.'_userids');
				$o_grp->relation('user')->store(\@uids) if @uids;

				my $addr = $cgi->param($gid.'_addaddress') || '';
				$o_grp->relation('address')->_assign([$addr]) if $addr;

				my @bids = $cgi->param($gid.'_addabugid');
				$o_grp->relation('bug')->assign(\@bids) if @bids;
			}
    	}
		print '<table border=1>', $self->dog(\@gids, 'h'), '</table>';
	}	
	
	# NEW GROUP
	if ($ok == 1 && $newgroup) {
		if ($newgroup !~ /^\w\w\w+$/) {
			$ok = 0;
			print "Group($newgroup) notallowed: please use at least 3 alphanumerics for group names!<hr>";
		} else {
			my $o_grp = $self->object('group');
			my @gindb = $o_grp->col('name');
			my $pri = $o_grp->primary_key;
			$o_grp->create({
				$pri	 		=> $o_grp->new_id,
				'name'			=> $newgroup,
				'description'	=> $desc,
			});
			if ($o_grp->CREATED) {
				push(@gids, $o_grp->oid); 
				my @uids = $cgi->param('addusers');
				$o_grp->relation('user')->store(\@uids) if @uids;
			}
		}
        print '<table border=1>', $self->groups(\@gids), '</table>'; 
	}

	# BUG IDs
    if ($ok == 1 && scalar @bids >= 1) {
		my $o_bug = $self->object('bug');
		$self->debug(1, "bugs(@bids)") if $DEBUG;
		$self->current({'context', 'text'}); # notify_cc
		$self->current({'format',  'a'});
    	BUG:
		foreach my $bid (@bids) {
            next BUG unless $ok == 1;
			my $o_bug = $self->object('bug')->read($bid);
			next BUG unless $o_bug->READ;
        	# my $orig = $self->current_status($bid);
			my $orig = $o_bug->format('a');	
        	$self->dok([$bid]);
			REL: # space separated(str2ids), store/assign(friendly/prejudicial)
			foreach my $rel ($o_bug->rels) { 
				next if $rel eq 'message';
				my $o_rel = $o_bug->relation($rel);
				my @update = ($rel =~ /(change|patch|note|test|parent|child)/i) 
					? split(/\s+/, $cgi->param($bid.'_'.$rel))  # space seperated
					: $cgi->param($bid."_$rel");				# plain
				if (scalar(@update) >= 1 && $update[0] =~ /\w+/) {
					my $call = 'assign';				# additional by id
					if ($rel =~ /(status|severity)/i) {	# prejudicial by id
						$call = 'store';
					} elsif ($rel =~ /(address|change|child|fixed|parent|version)/i) { # by name
						$call = ($rel =~ /(version|fixed)/i)
							? '_store'		# prejudicial by name
							: '_assign';	# additional by name
					}
					$self->debug(0, "calling $o_rel->$call(@update)") if $DEBUG;
					$o_rel->$call(\@update);
				}
			}				

			my $ix = $self->notify_cc($bid, $orig) unless $nocc eq 'nocc';
			my $i_newnoteid  = $self->doN($bid, $cgi->param($bid.'_newnote'),  '') if $cgi->param($bid.'_newnote');
			my $i_newpatchid = $self->doP($bid, $cgi->param($bid.'_newpatch'), '') if $cgi->param($bid.'_newpatch');
			my $i_newtestid  = $self->doT($bid, $cgi->param($bid.'_newtest'),  '') if $cgi->param($bid.'_newtest');
			my @cids = split(/\s+/, $cgi->param($bid.'_change'));
			
			if ($i_newpatchid =~ /\w+/ && scalar(@cids) >= 1) {
				$self->debug(2, "given both a new patchid($i_newpatchid) and changeids(@cids), updating patches too!") if $DEBUG;
				my $o_pat = $self->object('patch')->read($i_newpatchid);
				$o_pat->relation('change')->assign(\@cids) if $o_pat->READ;
			}
			my $ref = "<p>Bug ($bid) updated $Mysql::db_errstr<p>";
			$self->debug(2, $ref) if $DEBUG;
    	}

		$self->current({'context', 'html'});
		$self->current({'format', $orig_fmt});
		print '<table border=1>', $self->dob(\@bids, 'h'), '</table>';
	}	
	# PATCH IDs
    if ($ok == 1 && scalar @pids >= 1) {
		my $o_pat = $self->object('patch');
		$self->debug(1, "patches(@pids)") if $DEBUG;
    	PATCH:
		foreach my $pid (@pids) {
			next PATCH unless $pid =~ /\d+/;
            next PATCH unless $ok == 1;
			my $o_pat = $self->object('patch')->read($pid);
			next BUG unless $o_pat->READ;
        	my $cid = $cgi->param($pid.'_changeid') || '';
			$o_pat->relation('change')->assign([$cid]);
    	}
		print '<table border=1>', $self->dop(\@pids, 'h'), '</table>';
	}	
	# USER IDs
    if ($ok == 1 && scalar @uids >= 1) {
		my $o_usr = $self->object('user');
		$self->debug(1, "users(@uids)") if $DEBUG;
		my $NEWID = '';
        USER:
        foreach my $uid (@uids) {
			next USER unless $uid =~ /^\w+$/;
            next USER unless $ok == 1;
			$self->debug(2, "looking at admin($uid)") if $DEBUG;
            my $active   = $cgi->param($uid.'_active');
        	my $address  = $cgi->param($uid.'_address');
        	my @gids	 = $cgi->param($uid.'_groupids');
            my $name     = $cgi->param($uid.'_name');
        	my $password = $cgi->param($uid.'_password');
            my $pwdupdate= $cgi->param($uid.'_password_update') || 0;
            my $userid   = $cgi->param($uid.'_userid'); 
            $password    = crypt($password, substr($password, 0, 2)) if $pwdupdate;
        	my $match_address = $self->db->quote($cgi->param($uid.'_match_address'));
			my %data = (
				'password'	=> $password, 
				'address'	=> $address, 
				'name'		=> $name, 
				'match_address' => $match_address, 
				'active'	=> $active,
			);
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
			$o_usr->relation('group')->store(\@gids) if @gids;
            if ($ok == 1) { # track it and do htpass if required
				$ok = $self->htpasswd($uid, $password) if $pwdupdate || $userid eq 'newAdmin';
            }
    	}
		push(@uids, $NEWID) if $NEWID =~ /\w+/;
		print '<table border=1>', $self->dou(\@uids, 'h'), '</table>';
	}	
	# UPDATE DONE
    $self->debug(1, "update? -> '$ok'") if $DEBUG;
    return '';
}


# UTILITIES 
# ============================================================================ #

=item current_buttons

Get and set array of relevant buttons by context key 

    my @buttons = $o_web->current_buttons('search update reset', scalar(@uids), [$colspan]);

=cut

sub current_buttons {
    my $self = shift;
	my $akeys= shift;       # [submit query update]
	my $cgi  = $self->cgi();
	my $buttons = '';

    my @keys = (ref($akeys) eq 'ARRAY') ? @{$akeys} : split($akeys);
	if (scalar(@keys) >= 1 && $self->current('format') !~ /^[aAiLx]$/) { # vet
		my $reset = $cgi->reset();
		my @submit= ();
		my @name = (-'name' => 'req');
		my $pointer = 'parent.perlbug.document.forms[0].';

		if ($self->current('framed')) {
			$reset  = $cgi->submit(
				-'name'    => 'reset', -'value' => 'reset', 
				-'onClick' => $pointer.'reset();  return false;');
			@submit = ('onClick' => "request(this); return newcoms('write');");
		}

		my %map = (
			'back'      => $cgi->submit(@name, -'value' => 'back', @submit), 
			'delete'    => $cgi->submit(@name, -'value' => 'delete', @submit), 
			'home'      => $cgi->submit(@name, -'value' => 'home',    -'onClick' => 'top.location.reload()'), 
			'insert'    => $cgi->submit(@name, -'value' => 'insert', @submit), 
	        'nocc'      => $cgi->submit(@name, -'value' => 'nocc',   @submit),
			'reset'		=> $reset,
			'search'    => $cgi->submit(@name, -'value' => 'search',  -'onClick' => 'return search();'), 
	        'sql' 		=> $cgi->submit(@name, -'value' => 'SQL',    @submit),
	        'select'	=> $cgi->submit(@name, -'value' => 'select',  -'onClick' => 'return sel(1);'),
            'query'     => $cgi->submit(@name, -'value' => 'query',  @submit), # search
	        'unselect'	=> $cgi->submit(@name, -'value' => 'unselect',-'onClick' => 'return sel(0);'),
	        'update'    => $cgi->submit(@name, -'value' => 'update', @submit),
	    );

        foreach my $key (@keys) { # set
		    $buttons .= "&nbsp; $map{$key}\n";
    	} 
		$buttons .= "<br>\n";
	}   

	return $buttons; 
}


sub ranges {
	my $self = shift;
	my $req  = shift || '';
	my $cgi  = $self->cgi();

	my $rng  = $self->{'_range'};
	my $ret  = '';

	if ($rng) {
		my $o_rng 	= $self->object('range')->read($rng);
		my ($data) 	= $o_rng->col('range', $o_rng);
		my @ranges 	= split(/,\s*/, $data);
		$ret 		= $self->tenify(\@ranges);
	}

	return $ret;
}


sub file_ext { return '.html'; }


=item help_ref

creates something of the form: C<<a href="http://bugs.per.org/perlbug.cgi?req=help\#note">Note</a>>

	my $note = $self->help_ref('note');	

=cut

sub help_ref {
	my $self = shift;
	my $targ = shift || '';
	my $title= shift || $targ; 
    my $url  = $self->url;

	my $sect = ($targ =~ /\w+/) ? "\#$targ" : '';
	my $with = ($targ =~ /\w+/) ? "help with $targ parameters" : 'general help overview';
	my $hint = "click for $with";
	my $help = qq|<a 
			href="$url?req=webhelp$sect"
			onMouseOver="window.status='$hint'; return true;"
			onMouseOut="window.status='';"
		>$title</a>
	|;
	$help =~ s/\s*\n+\s*/ /g;
	return "$help\n";
}


=item case

Handle case sensitivity from web search form.

=cut

sub case {
    my $self = shift;
    my $arg = shift;
    return $self->{'attr'}{'PRE'}.$arg.$self->{'attr'}{'POST'};
}


=item format_query

Produce SQL query for bug search from cgi query.

Can be optimised somewhat ...

    my $query = $web->format_query;

=cut

sub format_query {
    my $self = shift;
    my $cgi = $self->cgi();
    $self->debug(3, "Formating web query") if $DEBUG;
    my %dates = $self->date_hash;
    # parameters
    my $admin       = ($cgi->param('admin') eq 'any') ? '' : $cgi->param('admin');
    my $andor       = $cgi->param('andor') || 'AND';
    my $body	    = $cgi->param('body') || '';
    my $bugid       = $self->wildcard($cgi->param('bugid')) || '';
    my $case        = $cgi->param('case') || '';
    my $group       = ($cgi->param('group') eq 'any') ? '' : $cgi->param('group');
    my $changeid    = $cgi->param('changeid') || '';
    my $date        = ($cgi->param('dates') eq 'any') ? '' : $cgi->param('dates');
    my $fixed		= $cgi->param('fixedin') || '';
    my $index		= $cgi->param('index') || '';
    my $msgid       = $self->wildcard($cgi->param('messageid')) || '';
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
	my $sql = '';
    if ($date =~ /\w+/) {
        my $crit = $dates{$date};
        $sql .= " $crit ";
    } else {
        # let's default to all of them :-)
        $sql .= " bugid IS NOT NULL ";
    }

	my $o_bug    = $self->object('bug');
	if ($index =~ /^yes$/i && $subject =~ /^\s*([%_\*\d\.]+)\s*$/) { # shortcut	
		my $match = $1; 
		$match =~ s/\*/%/g; 
		# $match =~ s/\+/_/g;
		print "running shortcut($1)<br>\n";
		$sql .= " $andor bugid LIKE '$1'";
	} else { 					# full search
		my $o_addr   = $self->object('address');
		my $o_grp    = $self->object('group');
		my $o_msg    = $self->object('message');
		my $o_usr    = $self->object('user');

		my $o_note   = $self->object('note');
		my $o_patch  = $self->object('patch');
		my $o_test   = $self->object('test');

		my $o_change = $self->object('change');
		my $o_child  = $self->object('child');
		my $o_parent = $self->object('parent');
		my $o_project= $self->object('project');
		my $o_osname = $self->object('osname');
		my $o_severity = $self->object('severity');
		my $o_status = $self->object('status');
		my $o_version= $self->object('version');

		if ($admin =~ /^(\w+)$/) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_usr->relation('bug')->ids("userid = '$x'");
			print "Found ".@ids." user_bug relations from claimants($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($patchid =~ /^(\w+)$/) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_patch->relation('bug')->ids("patchid LIKE '$x%'");
			print "Found ".@ids." bug_patch relations from patchid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($testid =~ /^(\w+)$/) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_test->relation('bug')->ids("testid LIKE '$x%'");
			print "Found ".@ids." bug_test relations from testid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($noteid =~ /^(\w+)$/) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_note->relation('bug')->ids("noteid LIKE '$x%'");
			print "Found ".@ids." bug_note relations from noteid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($patch =~ /(.+)/) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_patch->ids("body LIKE '%$x%'");
			my $ids = join("', '", @ids);
			$fnd += @ids = $o_patch->relation('bug')->ids("patchid IN ('$ids')");
			print "Found ".@ids." bug_patch relations from patch content($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($test =~ /(.+)/) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_test->ids("body LIKE '%$x%'");
			my $ids = join("', '", @ids);
			$fnd += @ids = $o_test->relation('bug')->ids("testid IN ('$ids')");
			print "Found ".@ids." bug_test relations from test content($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($note =~ /(.+)/) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_note->ids("body LIKE '%$x%'");
			print "Found ".@ids." bug_note relations from note content($x)<br>";
			my $ids = join("', '", @ids);	
			$fnd += @ids = $o_note->relation('bug')->ids("noteid IN ('$ids')");
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($changeid =~ /^(.+)$/) {
			my $x = $1;
			$wnt++;
			my @ids  = ();
			$fnd += my @pids = $o_change->relation('patch')->ids("changeid LIKE '$x%'");
			if (scalar(@pids) >= 1) {
				$self->debug(2, "Found ".@pids." patch change relations from changeid($x)<br>") if $DEBUG;
				my $found = join("', '", @pids);	
				$fnd += @pids = $o_patch->relation('bug')->ids("patchid IN ('$found')");
			} else {
				$self->debug(2, "No patches found with changeid($x), trying with bugs...<br>") if $DEBUG; 
				$fnd += @pids = $o_change->relation('bug')->ids("changeid LIKE '$x%'");
				$self->debug(2, "Found ".@ids." bug change relations from changeid($x)<br>") if $DEBUG;
			}
			my $found = join("', '", @ids);	
			print "Found bugids(".@ids.") with changeid($x)<br>";
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($body =~ /(.+)/) {
			my $x = $1;
			$wnt++;
			$fnd += my @mids = $o_msg->ids("body LIKE '%$x%'");
			print "Found ".@mids." messageids from body($x)<br>";
			my $mids = join("', '", @mids);	
			$fnd += my @ids = $o_msg->relation('bug')->ids("messageid IN ('$mids')");
			print "Found ".@ids." message_bug relations from message content($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($msgid =~ /(.+)/) {
			my $x = $1;
			$wnt++;
			$fnd += my @mids = $o_msg->ids("LOWER(header) LIKE LOWER('%Message-Id: $x%')");
			print "Found ".@mids." messageids from header LIKE(%Message-Id: $x%)<br>";
			my $mids = join("', '", @mids);	
			$fnd += my @ids = $o_msg->relation('bug')->ids("messageid IN ('$mids')");
			print "Found ".@ids." message_bug relations from messageid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}

		if ($bugid =~ /^\s*(.*\w+.*)\s*$/) {
			my $x = $1;
			$sql .= " $andor bugid LIKE '$x' ";
		}
		if ($version =~ /(.+)/) {
			my $x = $1;
			$wnt++;
			($x) = $o_version->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_version->relation('bug')->ids("versionid LIKE '$x%'");
			print "Found ".@ids." bug_version relations from versionid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($fixed =~ /.+/) {
			$sql .= " $andor fixed LIKE '$fixed' ";
		}
		if ($status =~ /(\w+)/) {
			my $x = $1;
			$wnt++;
			($x) = $o_status->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_status->relation('bug')->ids("statusid = '$x'");
			print "Found ".@ids." bug_status relations from statusid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($group =~ /(\w+)/) {
			my $x = $1;
			$wnt++;
			($x) = $o_grp->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_grp->relation('bug')->ids("groupid = '$x'");
			print "Found ".@ids." bug_group relations from groupid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($severity =~ /(\w+)/) {
			my $x = $1;
			$wnt++;
			($x) = $o_severity->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_severity->relation('bug')->ids("severityid= '$x'");
			print "Found ".@ids." bug_severity relations from severityid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($osname =~ /(\w+)/) {
			my $x = $1;
			$wnt++;
			($x) = $o_osname->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_osname->relation('bug')->ids("osnameid = '$x'");
			print "Found ".@ids." bug_osname relations from osnameid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($subject =~ /.+/) {
			$sql .= " $andor subject LIKE '%".$self->case($subject)."%' ";
		}
		if ($sourceaddr =~ /.+/) {
			$sql .= " $andor sourceaddr LIKE '%".$self->case($sourceaddr)."%' ";
		}    
	}
	# 
	if ($wnt >= 1 && $fnd == 0 && $andor eq 'AND') { #  && $withbug eq 'Yes') {
		$self->debug(1, "appear to want($wnt) unfound($fnd) andor($andor) withbug($withbug) data!") if $DEBUG;
		$sql .= " $andor 1 = 0 "; 
	} 
	# ref
	# $self->result("want($wnt) fnd($fnd) andor($andor) withbug($withbug)");
	# $self->result("SQL: $sql<hr>"); 
	
	$sql .= " ORDER BY bugid $order"; #?
	print "SQL: $sql<hr>" if $sqlshow =~ /y/i;

	$self->debug(2, "SQL built: '$sql'") if $DEBUG;
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


=item tenify

Create range of links to split (by tens or more) bugids from web query result.

	$self->tenify(\@_bids, 7); # in chunks of 7

=cut

sub tenify {
    my $self    = shift;
    my $a_bids  = shift;
    my $given   = shift || 25;
    my $slice   = (($given >= 1) && ($given <= 10000)) ? $given : 25;
	my $rng     = $self->{'_range'};
	my $ret     = '';

    if (ref($a_bids) ne 'ARRAY') {
		$self->error("Duff bug arrayref given to tenify($a_bids)");
	} else {
		my ($cnt, $min, $max) = (0, 1, 0);
	    my $url = $self->current('url');
        my $fmt = $self->current('format');
		my $range = $rng =~ /\w+/ ? "&range=$rng" : '';
		my $bids  = '';
		my @bids = @{$a_bids};
		foreach my $bid (@bids) {
	        $cnt++;
	        $max++;
	        $bids .= "&bug_id=$bid"; 
	        if (($cnt == $slice) || ($max == $#bids + 1)) { # chunk
	            $ret .= qq|<a href="$url?req=bug_id$bids&format=$fmt&trim=${slice}$range">$min to $max</a>&nbsp;\n|;
	            $min = $max + 1; 
	            $bids = '';
	            $cnt = 0;
	        } 
	    }
    }

	return $ret;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999 2000

=cut

1;

