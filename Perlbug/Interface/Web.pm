# Perlbug WWW interface
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Web.pm,v 1.113 2002/02/01 08:36:47 richardf Exp $
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
$VERSION = do { my @r = (q$Revision: 1.113 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1; 

use lib qw(../);
use lib qw(/usr/lib/perl5/site_perl/5.005/i586-linux);
use Apache::Constants qw(:common); # handler
use CGI qw(:standard);
use CGI::Carp 'fatalsToBrowser';
use Data::Dumper;
use HTML::Entities;
use Perlbug::Base; 
use Perlbug::Format; # href's
use Perlbug::JS;
use URI::Escape;

=head1 SYNOPSIS

	my $o_web = Perlbug::Interface::Web->new;

	print $o_web->top;

	print $o_web->request('help');

	print $o_web->links;

=head1 METHODS

=over 4

=item new

Create new Perlbug::Interface::Web object.

	my $web = Perlbug::Interface::Web->new;

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $self  = Perlbug::Base->new(@_);
	bless($self, $class);

	$self->cgi(@_);

    $self->setup; # default pars etc.

	return $self;
}

=item setup

Setup Perlbug::Interface::Web

    $o_web->setup($cgi);

=cut

sub setup {
    my $self = shift;
    my $cgi  = $self->cgi();

    $self->{'_range'} = $cgi->param('range') || '';

	my $framed = ($0 =~ /_([a-z]+\.{0,1})cgi$/o) ? 0 : 1;
	$self->current({'framed', $framed}); 
	$self->current({'format', $cgi->param('format') || 'h'});
	$self->current({'context', 'http'});
	$self->current({'admin', ''});
	$self->check_user($ENV{'REMOTE_USER'});

    return $self;
}

sub handler {
	my $self = shift; # Apache

	return OK unless $self->is_initial_req;

	my ($code, $pass) = $self->get_basic_auth_pw;
	return $code unless $code == OK; # 

	my $conn = $self->connection;
	my ($user, $type) = ($conn->user, $conn->auth_type);
	my $o_web = Perlbug::Interface::Web->new('-nodebug');
	print STDERR "$$: type($type), code($code) - ";

	my ($dbpass) = $o_web->object('user')->col('password', "userid = '$user'");
	undef $o_web;

	if ($user && $dbpass && $dbpass eq crypt($pass, $dbpass)) {
		print STDERR "valid user($user) db($dbpass) :-)\n";
		return OK;
	} else {
		$self->note_basic_auth_failure;
		print STDERR "INVALID user($user) db($dbpass) :-(\n";
		return AUTH_REQUIRED;
	}
	return FORBIDDEN;
}

=item check_user

Access authentication via http, we just prime ourselves with data from the db as well.

=cut

sub check_user { 
	my $self = shift;
	my $remote_user = shift || '';

	my $user = '';
    if (defined($ENV{'REQUEST_URI'}) && ($ENV{'REQUEST_URI'} =~ /\/admin/io)) {
		$user = $self->SUPER::check_user($remote_user); # Base
	} else {
		$user = $self->SUPER::check_user(''); # Base
	}

	return $user; 
}

# SETUP 
# ============================================================================ #
#

=item menus 

Return menu of system, designed for vertical format.  Wraps logo, title and links

	print $o_web->menus();

=cut

sub menus {
	my $self = shift;
	
	my $ret = $self->logo.$self->get_title.$self->summary.$self->links;
	# links = (menus) ? menus : links=~s/tr/br/

	$ret =~ s/<(table|tr|td)[^>]*(?:>)//gsio;
	$ret =~ s/<\/td>/<br>/gsio;
	$ret =~ s/<\/(tr|table)>//gsio;
	$ret .= '<hr>'.$self->isadmin;

	return $ret;
}

=item logo 

Return logo of system with href=hard_wired_url 

	print $o_web->logo();

=cut

sub logo {
	my $self = shift;
	my $logo = '';
	
	my $home = $self->web('hard_wired_url');
    $logo = qq|<center><a href="$home" target="_top">|.$self->web('logo').'</a></center>';

	return $logo;
}

=item get_title

Return title of current page

	print $o_web->get_title();

=cut

sub get_title {
	my $self = shift;

    my $title = '<center><h3>'.$self->system('title').' '.$self->version.'</h3></center>';

	return $title;
}

=item summary

Return summary of open/closed bugs

	print $o_web->summary();

=cut

sub summary {
	my $self = shift;

	my $o_bug  = $self->object('bug');
	my $o_sta  = $self->object('status');
	my $o_bs   = $o_bug->rel('status');

	my ($oid)  = $o_sta->ids("name = 'open'");
	my $i_summ = $o_bug->count;
	my $i_open = $o_bs->count("statusid = '$oid'");

	# my $href   = $self->href('query&status=open&commands=write', [], $i_open, 'open bugs', [], "newcoms('write')");
	my $href   = $self->href('query&status=open', [], $i_open, 'open bugs', [], '');

    my $sum = qq|<center>$i_summ($href) bugs</center>|;

	return $sum;
}

=item links 

Return links of system, with adminfaq inserted if appropriate, configured links and object search forms.

	print $o_web->links();

=cut

sub links { 
	my $self = shift;
	my $links = '&nbsp; links';
	
    $links = join('', $self->read('footer'));

	my $url = $self->myurl;
    if ($self->isadmin) {
		my $target = ($self->isframed) ? 'perlbug' : '_top';
		$links =~ s#\Q<!-- FAQ -->\E#<td><a href="perlbug.cgi?req=adminfaq" target="$target" onClick="return go('adminfaq');">Admin FAQ<\/a><\/td>#;
	}

	# Links
	foreach my $target ($self->link()) { # qw(archive database language os webserver)) {
		my $link = $self->link($target);
		$links =~ s#\Q<!-- $target link -->\E#$link#;
	}

	# Object search forms
	foreach my $obj ($self->objects('mail'), 'group', 'user') { 
		my ($search) = $self->object($obj)->link('H', '', "return go('${obj}_id');");
		if ($self->isadmin) {
			my ($create) = $self->object($obj)->href($obj.'_initform', [], 'create', "Create a new $obj", '', "return go('${obj}_id')");
			$search = $search.'&nbsp;-&nbsp;'.$create
				if $self->isadmin eq $self->system('bugmaster');
				# unless $obj eq 'user' && $self->isadmin ne $self->system('bugmaster');
		}
		$links =~ s#\Q<!-- $obj search -->\E#$search#;
	}
	# $links =~ s/(perlbug\.cgi)/_$1/gi unless $self->current('framed'); # url =~ /_perlbug\.cgi/i;

	return $links;
}

=item index 

Display the index results here...

=cut

sub index {
	my $self = shift;
	my $ret  = '';
	
	my $url   = $self->myurl;
	my $ehelp = $self->email('help');
	$ret .= $self->logo;
	$ret .= $self->get_title;
	$ret .= qq|
		<center>
		<h4>
		Anyone may search the bug Database via either the <a href="mailto:$ehelp">email</a> 
		or the <a href="$url">web</a> interface.
		</h4>
		<hr>

		<a href="perlbug.cgi?req=search"><h3>Enter BUG squashing arena!</h3></a>
		<a href="_perlbug.cgi?req=search&frames=no" target="_top"><h5>No Frames version!</h5></a>

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

=item get_request

Return the B<req> value for this request

	my $req = $self->get_request;

=cut

sub get_request {
	my $self = shift;
	my $cgi  = $self->cgi;

	my ($req) = my @req  = grep(/\w+/, $cgi->param('req'));
	$req = lc($req);

	$self->debug(2, "req($req)") if $Perlbug::DEBUG;
	unless ($req) {
		$self->debug(0, "indecent req($req) ".$self->dump($cgi)); 
		$req = 'help';
	}

	return $req;
}

=item set_command

Set the command type for the rest of the process, based on the input and operation

	my $cmd = $o_web->set_command($req);

=cut

sub set_command { # start all home nix read write commands
	my $self = shift;
	my $swit = shift; # switched request
	my $cgi  = $self->cgi;

	my $req  = $self->get_request;
	my $cmd  = $cgi->param('commands') || '';

	if ($self->isadmin) {									# params
		if ($req =~ /(date|headers{0,1}|query|update)$/io) {	# request
			$cmd = 'write';				# -> write
		}

		my %par = ();
		PAR:
		foreach my $par (sort $cgi->param) {
			my $i_params = my @params = $cgi->param($par);
			if ($par =~ /id$/io && $i_params >= 1) {
				$par{'_id'}++;			# -> write
				$cmd = 'write';
			} 
			if ($par =~ /_query$/io) {
				$par{'_query'}++;		# -> write
				$cmd = 'write';
			}
			if ($par =~ /_transfer$/io && $i_params >= 1) {
				$par{'_transfer'}++;	# -> read
				$cmd = 'read'; last PAR;
			}
		}
		$self->debug(3, 'par: '.Dumper(\%par)) if scalar(keys %par) >= 1 && $Perlbug::DEBUG;

		# $cmd = 'all' if $self->isbugmaster;
	}
	$self->debug(2, "given($swit) req($req) -> cmd($cmd) from ".Dumper($cgi)) if $Perlbug::DEBUG;

	return $cmd;
}

=item commands

Return command menu buttons for request given

	print $o_web->commands($req);

=cut

sub commands { # -> current_buttons
	my $self = shift;
	my $cmd  = shift || $self->cgi->param('commands') || '';
	my $ret  = '';

	my %comm = ( # back home refresh search
		'all'		=> [qw(query update select unselect admin noadmin reset create delete home search back nocc)], 
		'nix'		=> [qw()],
		'read'		=> [qw(query reset home search back)], 	# default
		'write'		=> [qw(update select unselect admin noadmin reset home search back)], 
	);
	my $a_cmds = $comm{$cmd} || $comm{'read'}; 			# read!
	
	$ret = '<br>'.$self->current_buttons($a_cmds).'<br>';

	$self->debug(2, "given($cmd) -> cmds(@{$a_cmds})") if $Perlbug::DEBUG;

	return $ret;
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
    my $cgi  = $self->cgi();
	my $req  = my $orig = $self->get_request;

    if (defined($req)) {
		$req = 'headers' 	if $req =~ /^(\w+)_header$/io; 	
		$req = 'object_handler' 
			if $req =~ /^(\w+)_(create|id|initform|query|search)$/io; # ? template
		$req = 'object_create' 
			if $req =~ /^(\w+)_(create)$/io; 
		$req = 'spec' 		if $req =~ /^info$/io;
		$req = 'update' 	if $req =~ /^nocc$/io;
		$req = 'web_query' 	if $req =~ /^query$/io;
    }
	$self->debug(1, "requested($orig) -> switched($req)") if $Perlbug::DEBUG ;

	return $req;
}

=item start

Return appropriate start header data for web request, includes start table.

	print $o_web->start();

=cut

sub start {
	my $self = shift;
	my $swit = shift; # already been swapped!
	my $ret  = '';

    my $cgi  = $self->cgi();

	my $req = $self->get_request;
	my $cmd = $self->set_command($req); # based loosely on request
	$ret = $self->top($req, $cmd); # commands|update, home|read|write

	unless ($self->current('framed')) {
		$ret .= $self->logo($req);
		$ret .= $self->get_title($req);
	}

	my $target = ($req =~ /^(menus|commands)$/io) ? $1 : 'perlbug';
	$ret .= $self->form($target).qq|
		<table border="0" valign="top"><COLGROUP cellvalign="top">\n
	|;

	unless ($self->current('framed')) {
		$ret .= $self->commands($cmd);
	}

	return $ret;
}

=item form

Return form with appropriate name and target etc.

	print $o_web->form('menus');

=cut

sub form {
	my $self = shift;
	my $name = shift || 'undefined_form';

	my $cgi  = $self->cgi;
	my $url  = $self->myurl;
	my $req  = $cgi->hidden(
			-'name' 	=> 'req', 
			-'default' 	=> '', 
			-'override'	=> 1
	); # unless $cgi->param('req') =~ /\w+/io; # has it's own

	my $form = qq|
		<FORM name="$name" method="post" action="$url">
		$req
	|;
	$self->debug(0, "form($form)") if $Perlbug::DEBUG;

	return $form;
}

=item top 

Return consistent top of page.

	print $o_web->top($req, $cmd);

=cut

sub top { # start
    my $self = shift;
	my $req  = shift;
	my $cmd  = shift;
	my $ret  = '';

    my $cgi  = $self->cgi();
	my $url  = $self->myurl;
	my $title = $self->system('title');
	my $version = $self->version;

	#$ret .= $cgi->header(
	#	-'expires'	=> '+15m',
	#	-'type'		=> (($req eq 'graph') ? '/image/png' : 'text/html'),	
	#);

	$title = qq|$title Web Interface $version $req|; 
	my $call = ($req =~ /(commands|menus)/o) ? $1 : 'perlbug';
	my $functions = Perlbug::JS->new($self->isframed)->$call();

	$ret .= $cgi->start_html(
		-'bgcolor'	=> $self->web('bgcolor'),
		-'onLoad'	=> "return onPageLoad('$req', '$cmd');", # onpageload
		-'script'	=> $functions,
		-'title'	=> $title,
	);

	$self->debug(3, "req($req) -> $call -> top($ret)") if $Perlbug::DEBUG;

    return $ret;
}

=item request

Handle all web requests (internal print)

	$o_web->request($call);

=cut

sub request {
    my $self = shift;
	my $req  = shift;
	my $ret  = '';

	$self->debug(1, "req($req): ".Dumper($self->cgi)) if $Perlbug::DEBUG;

	if ($req =~ /^create|delete|sql|update$/i && !$self->isadmin) {
		$self->error("User(".$self->isadmin.") not permitted for action($req)");
	} else {
		unless ($self->can($req)) {
			$self->error("Invalid request($req)");
		} else {
			$DB::single=2;
			print $self->$req();
		}	
	}

	$self->debug(1, "Web::request($req) done") if $Perlbug::DEBUG;

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

Varies with framed, includes table finish 

	print $o_web->finish($req);

=cut

sub finish { # index/display/bottom/base - see also start
	my $self = shift;
	my $req  = shift;
	my $ret  = '';

    my $cgi   = $self->cgi();
	my $range = $self->{'_range'};
	if ($self->current('framed')) {
		$ret .= $cgi->hidden(
			-'name' 	=> 'range', 
			-'default' 	=> $range,
			-'override'	=> 1
		);
	}
	$ret .= '</table>';
	$ret .= '<hr>'.$self->ranges($self->{'_range'}).'<hr>' if $range;

	unless ($self->current('framed')) {
		$ret .= $self->commands($self->set_command($req));
		$ret .= $self->links($req);
	}

	$ret .= $cgi->end_form.$cgi->end_html;

	$self->debug(3, "ret($ret)") if $Perlbug::DEBUG;

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
		next unless $key =~ /^(\w+)$/o;
		next unless $$data{$flag}{$key} =~ /^(\d+)$/o;
		push(@keys, "$key ($$data{$flag}{$key})");
		push(@vals, $$data{$flag}{$key});
	}

	# GRAPH
	eval { require GD::Graph::pie; }; # make non-fatal at least until required :-)
	if ($@) {
		my $maintainer = $self->system('bugmaster');
		print "<h3>Graph functionality unsupported, talk to the webmaster($maintainer) :-(</h3><br>";
		$self->error("Failed to load GD::Graph $!"); 
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
    $self->debug(1, "date($date)") if $Perlbug::DEBUG;
    my $filter = '';

    if ($date =~ /^\d{8}$/o) {
		$filter = "TO_DAYS($date)";	
		$self->debug(1, "using given date($date)") if $Perlbug::DEBUG;
    } elsif ($date =~ /^\d+$/o) {
		$filter = "TO_DAYS($date)";	
		$self->debug(1, "using non-norm given date($date)") if $Perlbug::DEBUG;
    } elsif ($date =~ /^\-(\d+)$/o) {
		$filter = "(TO_DAYS(now())-$1)";	
		$self->debug(1, "using minus given num($date)") if $Perlbug::DEBUG;
    } else {
		$filter = "TO_DAYS(now()) - 10";	
		$self->debug(1, "unrecognised date($date) format(should be of the form: 20001015), using($filter)") if $Perlbug::DEBUG;
    }

	my $o_bug = $self->object('bug');
    my @bids = $o_bug->ids("TO_DAYS(created) >= $filter ORDER BY created DESC"); 

	my $max = $cgi->param('trim') || 10;

	my $s = (scalar(@bids) == 1) ? '' : 's';
	print "found ".@bids." bug$s ($filter) showing max($max)<br>\n";
	($#bids) = ($max - 1) if scalar(@bids) > $max;
	foreach my $id (@bids) {
		print $o_bug->read($id)->format;
	}

    return '';
}

=item create

Wrapper for object creation

	$o_web->create($obj, \%data);

=cut

sub create {
    my $self   = shift;
	my $obj    = shift;
	my $h_data = shift;
	my $id     = '';

	if (!$self->isadmin) {
		$self->error("Not permitted!");
	} else {
		my $o_obj = $self->object($obj);
		my $doit = 'do'.uc(substr($obj, 0, 1));
		($id) = $self->$doit($h_data); 			# 
	}

	$self->debug(2, "new $obj => oid($id)") if $Perlbug::DEBUG;

    return $id;
}

=item object_handler

Wrapper for object access: no ids = search form

	$o_web->object_handler($me_thod, $oid); # o_cgi comes from the heavens

=cut

sub object_handler {
    my $self   = shift;
	my $passed = shift || ''; # maybe
	my $oid    = shift || ''; # maybe
    my $cgi    = shift || $self->cgi();

	my ($req) = $passed || $self->get_request;
	if ($req !~ /^(\w+)_(\w+)$/o) {
		print "<h3>unrecognised request($req)</h3>";
	} else {
		my ($obj, $call) = ($1, $2);
		$self->debug(1, "req($req) -> obj($obj) call($call)") if $Perlbug::DEBUG;
		my $objects = join('|', $self->objects('mail'), $self->objects('item'), $self->objects('flag'));
		if ($obj !~ /^($objects)$/o) {
			print "<h3>unrecognised obj($obj) request($req) in $objects</h3>";
		} else {
			$self->debug(0, "req($req) -> obj($obj) call($call)") if $Perlbug::DEBUG;
			my $trim = $cgi->param('trim') || 15;
			my @ids  = ($oid =~ /\w+/o) ? ($oid) : $cgi->param("${obj}_id");
			my $o_obj = $self->object($obj);

			if ($call =~ /init/io && !$self->isadmin) {		# 
				$self->error("Not permitted!");
			} else {
				my $h_query = $o_obj->massage($cgi, $oid);	# DOIT
				if ($call eq 'create') {
					@ids = $self->create($obj, $h_query);	# create
				} else {
					@ids = $o_obj->$call($h_query, $oid);	# id|initform|query|search|slurp|transfer|update|webupdate|etc.
				}
			}
				
			my $i_ids = @ids;
			if ($i_ids >= 1) {								# SHOW
				$#ids = $trim -1 if $i_ids > $trim;
				my $i_trimmed = @ids;
				my $curfmt = $self->current('format');
				my $fmt = ($i_trimmed == 1) ? uc($curfmt) : lc($curfmt);
				$self->debug(3, "format($fmt) from($curfmt) i_ids($i_ids) trim($trim) via call($call)"); 
				foreach my $oid (@ids) {
					$o_obj->read($oid);
					print $o_obj->format($fmt) if $o_obj->READ;
				}
			} else { # ?
				print '<h3>',
					$self->help_ref('object_search', 'Object search help'),
					$self->help_ref('wildcards', 'and sql wildcards usage'),
					$o_obj->search,
				'</h3>' unless $call eq 'initform';
			}
			$self->debug(3, "$obj $call => ids(@ids)") if $Perlbug::DEBUG;
		}
    }

    return ();
}

=item hist

History mechanism for bugs and users.

Move formatting to Formatter::history !!!

=cut

sub hist {
    my $self = shift;
    my $cgi  = $self->cgi();

    my ($bid) = $cgi->param('hist');
    $self->debug(1, "hist: bid($bid)") if $Perlbug::DEBUG;

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
			my $h_usr = $o_usr->htmlify($o_usr->_oref('data'), 'noadmin');
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

	$o_web->headers('patch', $id);	

=cut

sub headers {
    my $self = shift;
    my $cgi  = $self->cgi();

	my ($obj) = my ($req) = $self->get_request;
	$obj =~ s/^(\w+)_header$/$1/;
    my ($id)  = $cgi->param("${obj}_header"); # only going to support one for the moment

	my $objects = join('|', $self->objects('mail'), $self->objects('item'), $self->objects('flag'));
	$self->debug(1, "req($req) obj($obj) object($objects) ids($id)") if $Perlbug::DEBUG;

	if ($obj !~ /^($objects)$/) {
		$self->error("Can't do invalid obj($obj) id($id) header request($req)");
	} else {
		$obj = 'bug' if $obj =~ /parent|child/io;
    	my ($item) = $self->href($obj.'_id', [$id], $id, '', [], qq|return go('${obj}_id&${obj}_id=$id')|);
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


=item bidmid

Wrapper for bugid and messageid access

=cut

sub bidmid {
    my $self = shift;
    my $cgi  = $self->cgi();

    my @bids = $cgi->param('bidmid');
	my $o_msg= $self->object('message');

	$self->dof('H');
	foreach my $bid (@bids) {
		print $self->dob([$bid]);
        my @mids = $self->object('bug')->rel_ids('message');
        print $self->dom(\@mids);
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
		</table>
		<hr>
		$spec
	|;
	print $dynaspec;
    return ();
}


=item webhelp

Web based help for perlbug.

	print $web->webhelp;

=cut

sub webhelp {
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
	$webhelp
    |;	
	print $help;

	return ();
}

=item mailhelp

Web based mail help for perlbug.

	print $web->mailhelp;

=cut

sub mailhelp { #mailhelp 
	my $self = shift;
	my $url  = $self->myurl;
	my $email = $self->email('domain');
	my $bugdb = $self->email('bugdb');
	my ($perlbug_help) = $self->SUPER::doh; # Base

	my $help = join('', $self->read('mailhelp'));
	# $perlbug_help =~ s/\b(http\:.+?perlbug\.cgi(?:\?.+)*)*\b/<a href="$1">$1<\/a>/gio;
	# $perlbug_help =~ s/\b([\<\w+\-_\.\>]+\@.+?\.(?:com|org|net|edu))\b/<a href="mailto:$1">$1<\/a>/gio;
	my $HELP = qq|
		<table align=center>
			<tr><td><pre>$perlbug_help</pre><hr></td></tr>
		</table>
		<hr>
		$help
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

	my ($objids) = grep(/^[a-z]+?id$/, $cgi->param);
	my @ids = $cgi->param($objids);
	my $obj = $objids;
	$obj =~ s/^([a-z]+)?id$/$1/; 

	my $admin = $self->isadmin;
	my $o_obj = $self->object($obj);

	if (!($admin)) {
		print "<h3>Can't delete $obj ids if not an admin</h3><hr>";
	} else {
		if ($obj eq 'user' && $admin ne $self->system('bugmaster')) {
			my $maintainer = $self->system('maintainer');
			print "Cannot delete administrator from web interface, see maintainer($maintainer)";
		} else {
			my $i_del = $o_obj->delete(\@ids)->DELETED;
			my $s = (scalar(@ids) == 1) ? '' : 's';
			print '<h3>'.@ids." record$s".(
				($i_del) ? '' : " <b>not</b>"
				)." deleted($i_del)<h3>";
		}
	}
	print $o_obj->search;

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
	if (defined($tup) && $tup =~ /\w+/o && length($tup) < 500) {
		# just append it
		my $spacer = '       '; # 7
		$self->debug(1, "Appending to todo: data($tup)") if $Perlbug::DEBUG;
		$self->append('todo', "\n$spacer $tup\n"); 
		# my $i_todo = $self->SUPER::todo($tup); # mail out
	}
	my $todo = join('', $self->read('todo'));
    print $todo;
    return ();
}


=item adminfaq

adminFAQ

=cut

sub adminfaq { # ...
    my $self = shift;
	my $cgi = $self->cgi();
	my $adminfaq = join('', $self->read('adminfaq'));
    print $adminfaq;
    return ();
}


=item web_query

Form bugid search web query results

# results - don't map to query() unless Base::query modified

=cut

sub web_query {
    my $self = shift;
    my $cgi  = $self->cgi();

    my $sql = $self->format_query($cgi);

	my $o_bug = $self->object('bug');
	my $found = my @bids = $o_bug->ids($sql);
	$self->debug(1, "sql($sql) bugids: ".@bids) if $Perlbug::DEBUG;
	my $s = ($found == 1) ? '' : 's';
	print "Found $found relevant bug id$s<br>";

	if (@bids) {
		my $o_rng = $self->object('range');
		$o_rng->create({
			'name'		=> 'bug',
			'rangeid'	=> $o_rng->new_id,
			'processid'	=> $$,
			'range'		=> $o_rng->rangeify(\@bids), 
			# $o_rng->relation('bug')->assign(\@bids); # ouch!
		});
		$self->{'_range'} = $o_rng->oid if $o_rng->CREATED; 
	}

	my $trim = $cgi->param('trim') || 25;
	if (($trim !~ /^\d+$/) || ($trim >= 1501)) {
		print "Sorry trim($trim) is not conducive to system health - reducing to 101<br>\n";
		$trim = 101;
	}

	if ($found >= $trim) {
        print "Showing '$trim'<br>" if $trim =~ /\d+/o;
		$#bids = $trim - 1 if scalar(@bids) > $trim;
    } 

	print map { $o_bug->read($_)->format } @bids; # :-)

	return '';
}

=item search

Construct search form 

	with chosen params as defaults...

=cut

sub search {
    my $self = shift;
    my $cgi = $self->cgi();
	my $o_bug = $self->object('bug');
	# my @bugs  = $o_bug->ids;
	# my @sourceaddr = $o_bug->col('sourceaddr');

	# Elements
    $self->debug(3, "Setting search form elements...") if $Perlbug::DEBUG;   
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
	my $msgid    = $cgi->textfield(-'name'  => 'messageid',   -'default' => '', -'size' => 30, -'maxlength' => 40, -'override' => 1);

	my $admins   = $self->object('user')->popup('admin', 'any');
	my $group    = $self->object('group')->popup('group', 'any');
	my $osnames  = $self->object('osname')->popup('osname', 'any');
	my $project  = $self->object('project')->popup('project', 'any');
	my $severity = $self->object('severity')->popup('severity', 'any');
	my $status   = $self->object('status')->popup('status', 'any');

	my %dates    = $self->date_hash; # 'labels' => \%dates ?
	my @dates    = keys %dates;
	my $date     = $cgi->popup_menu(-'name' => 'dates',     -'values' => \@dates,      -'default' => 'any', -'override' => 1);
	# no case sensitivity in mysql => indexOf($str)
    # $case     = 'Case: '.$cgi->popup_menu(-'name' => 'case',      -'values' => ['Sensitive', 'Insensitive'], -'default' => 'Insensitive');
    my $andor_def = ($cgi->param('andor') =~ /^(AND|OR)$/o) ? $1 : 'AND';
    my $andor    = $cgi->radio_group(-'name'=> 'andor',     -'values' => ['AND', 'OR'], -'default' => $andor_def, -'override' => 1);
    my $msgs_def = ($cgi->param('msgs') =~ /^(\d+\+*)$/o) ? $1 : 'ALL';
    my $msgs     = $cgi->popup_menu(-'name' => 'msgs',      -'values' => ['All', '0', '1', '1+', '5+', '20+'],  -'default' => $msgs_def, -'override' => 1);
    my $restrict_def = ($cgi->param('trim') =~ /^(\d+)$/o) ? $1 : 10;
    my $restrict = $cgi->popup_menu(-'name' => 'trim',      -'values' => ['All', '5', '10', '25', '50', '100'],  -'default' => $restrict_def, -'override' => 1);
    my %format   = ( 'h' => 'Html list', 'H' => 'Html block', 'L' => 'Html lean', 'a' => 'Ascii list', 'A' => 'Ascii block', 'l' => 'Ascii lean',); 
	# my %format   = ( 'h' => 'Html list', 'H' => 'Html block', 'a' => 'Ascii list', 'A' => 'Ascii block', 'l' => 'Ascii lean', -'override' => 1); 
	my $format   = $cgi->radio_group(-'name' => 'format',  -values => \%format, -'default' => 'h', -'override' => 1);
    my $sqlshow_def = ($cgi->param('sqlshow') =~ /^(Yes|No)$/io) ? $1 : 'No';
    my $sqlshow  = $cgi->radio_group(-'name' => 'sqlshow',	-'values' => ['Yes', 'No'], -'default' => $sqlshow_def, -'override' => 1);
    my $url = $self->myurl;
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
	my $MSGS    = $self->help_ref('messages', 'Number of messages');
	my $RESTRICT= $self->help_ref('restrict', 'Restrict returns to');
	my $FMT		= $self->help_ref('format', 'Formatter');
	my $SHOWSQL = $self->help_ref('show_sql', 'Show SQL');
	my $ANDOR	= $self->help_ref('boolean', 'Boolean');
	my $ASCD	= $self->help_ref('asc_desc', 'Asc/Desc by bugid');
	my $NOTE	= $self->help_ref('note', 'Note ID');	# <a href="$url?req=webhelp">help</a>	
	my $PATCH 	= $self->help_ref('patch', 'Patch ID');
	my $TEST	= $self->help_ref('test', 'Test ID');
	my $PROJECT = $self->help_ref('project', 'Project');
	my $form = qq|
	    <table border=1><tr><td colspan=5><i>
	    Select from the options (see <a href="$url?req=webhelp">help</a>) available, then click the query button.<br>  
	    </td></tr>
	    <tr><td><b>$BUG:</b><br>$bugid</td><td><b>$VERSION:<br></b>&nbsp;$version</td><td><b>$FIXED:<br></b>&nbsp;$fixedin</td><td><b>$CHANGE</b><br>$changeid</td></tr>
	    <tr><td><b>$STAT:</b><br>$status</td><td><b>$CAT:</b><br>$group</td><td><b>$SEV:</b><br>$severity</td><td><b>$OS:</b><br>$osnames</td></tr>
	    <tr><td colspan=2><b>$SUBJ:</b>&nbsp;$subject</td><td colspan=2><b>$SRCADDR:</b>&nbsp;$sourceaddr</td></tr>
	    <tr><td colspan=2><b>$BODY:&nbsp;&nbsp;&nbsp;</b>&nbsp;$body</td><td colspan=2><b>$MSGID:</b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$msgid</td></tr>
	    <tr><td><b>$DATES:</b><br>$date</td><td><b>$ADMIN</b><br>$admins</td><td><b>$RESTRICT</b>:<br>$restrict</td><td><b>$MSGS</b>:<br>$msgs</td></tr>
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
    $self->debug(3, "Form: '$form'\nSQLinput: '$sqlinput'") if $Perlbug::DEBUG;
=cut
    return $form;
}

=item update

For all application objects, wraps to B<object_handler>

	$o_web->update(); # args ignored here for passing purposes

=cut

sub update {
    my $self = shift;
    my $req  = shift;
    my $cgi  = $self->cgi();
	my $i_transfer = 0;

	OBJ:
	foreach my $obj ($self->objects()) { # -> object_handler
		my $o_obj = $self->object($obj);
		my @ids = $cgi->param("${obj}id"), $cgi->param("${obj}ids");
		next OBJ unless scalar(@ids) >= 1;
		OID:
		foreach my $oid (@ids) {
			next OID unless $o_obj->ok_ids([$oid]);
			my $transfer = $cgi->param($oid.'_transfer'); # web transfer
			my $method = $obj.'_webupdate';
			if ($transfer =~ /\w+/) {
				$method = $obj.'_transfer';
				$i_transfer++;
			}
			$self->object_handler($method, $oid, $cgi);
		}
		$self->{'_i_transfer'} = $i_transfer;
		# last OBJ if $i_transfer >= 1;
	}

    return ();
}


# UTILITIES 
# ============================================================================ #

=item current_buttons

Get and set array of relevant buttons by context key 

    my @buttons = $o_web->current_buttons('search update reset', scalar(@uids), [$colspan]);

=cut

sub current_buttons { # <- commands
    my $self = shift;
	my $akeys= shift;       # [submit query update]
	my $cgi  = $self->cgi();
	my $buttons = ''; 

    my @keys = (ref($akeys) eq 'ARRAY') ? @{$akeys} : split($akeys);
	if (scalar(@keys) >= 1 && $self->current('format') !~ /^[aAiLx]$/) { # vet
		my $reset  = $cgi->reset();
		my @submit = ();
		my @name   = (-'name' => 'req');
		my $pointer = 'parent.perlbug.document.forms[0].';
		if ($self->current('framed')) {
			$reset  = $cgi->submit(
				-'name'    => 'reset', -'value' => 'reset', 
				-'onClick' => $pointer.'reset();  return false;');
			@submit = ('onClick' => "return request(this);");
		}

		my %map = (
			'admin'     => $cgi->submit(@name, -'value' => 'admin',  -'onClick' => 'return admin(1)'), 
			'back'      => $cgi->submit(@name, -'value' => 'back',   -'onClick' => 'return goback()'), 
	        'create'    => $cgi->submit(@name, -'value' => 'create', @submit),
			'delete'    => $cgi->submit(@name, -'value' => 'delete', @submit), 
			'home'      => $cgi->submit(@name, -'value' => 'home',   -'onClick' => 'top.location.reload()'), 
			'insert'    => $cgi->submit(@name, -'value' => 'insert', @submit), 
			'noadmin'   => $cgi->submit(@name, -'value' => 'noadmin', -'onClick' => 'return admin(0)'), 
	        'nocc'      => $cgi->submit(@name, -'value' => 'nocc',   @submit),
            'query'     => $cgi->submit(@name, -'value' => 'query',  @submit), # search
			'reset'		=> $reset,
			'search'    => $cgi->submit(@name, -'value' => 'search',  -'onClick' => "return request(this)"), 
	        'select'	=> $cgi->submit(@name, -'value' => 'select',  -'onClick' => 'return sel(1);'),
	        'sql' 		=> $cgi->submit(@name, -'value' => 'SQL',    @submit),
	        'unselect'	=> $cgi->submit(@name, -'value' => 'unselect',-'onClick' => 'return sel(0);'),
	        'update'    => $cgi->submit(@name, -'value' => 'update', @submit),
	    );

        foreach my $key (@keys) { # set
		    $buttons .= "&nbsp; $map{$key}\n";
    	} 
		$buttons .= '&nbsp;'.$self->help_ref('submit', 'Help', [], "return request('help')")."<br>\n";
	}   
	$self->debug(3, "in(@keys)out(\n$buttons)") if $Perlbug::DEBUG;

	return $buttons; 
}

sub ranges {
	my $self = shift;
	my $req  = shift || '';
	my $cgi  = $self->cgi();

	my $req  = $self->get_request;
	my $rng  = $self->{'_range'};
	my $ret  = '';

	if ($rng) {
		my $o_rng 	= $self->object('range')->read($rng);
		my ($data) 	= $o_rng->col('range', $o_rng);
		my $name    = $o_rng->data('name');
		$self->debug(0, "req($req) rng($rng) name($name)") if $Perlbug::DEBUG;
		if ($req =~ /$name/i) {
			my $a_ranges= $o_rng->derangeify($data);
			$ret 		= $self->tenify($a_ranges, $name);
		}
	}

	return $ret;
}


sub file_ext { return '.html'; }


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
    my $msgs        = ($cgi->param('msgs') eq 'ALL') ? '' : $cgi->param('msgs');
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
	if ($case =~ /Insensitive/o) {
	    $self->{'attr'}{'PRE'} = 'UPPER(';
	    $self->{'attr'}{'POST'} = ')';
	}
	my $wnt = 0;
	my $fnd = 0;
	
    # Work through parameters given above to generate appropriate sql.
	my $sql = '';
    if ($date =~ /\w+/o) {
        my $crit = $dates{$date};
        $sql .= " $crit ";
    } else {
        # let's default to all of them :-)
        $sql .= " bugid IS NOT NULL ";
    }

$DB::single=2; # rjsf
	my $o_bug    = $self->object('bug');
	if ($index =~ /^yes$/io && $subject =~ /^\s*([%_\*\d\.]+)\s*$/o) { # shortcut	
		my $match = $1; 
		$match =~ s/\*/%/go; 
		# $match =~ s/\+/_/go;
		print "running shortcut($1)<br>\n";
		my $comp = $self->db->comp($match);
		$sql .= " $andor bugid $comp '$match'";
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
		my $o_fixed  = $self->object('fixed');
		my $o_parent = $self->object('parent');
		my $o_project= $self->object('project');
		my $o_osname = $self->object('osname');
		my $o_severity = $self->object('severity');
		my $o_status = $self->object('status');
		my $o_version= $self->object('version');

		if ($admin =~ /^(\w+)$/o) {
			my $x = $1;
			$wnt++;
			$fnd += my @ids = $o_usr->relation('bug')->ids("userid = '$x'");
			print "Found ".@ids." user_bug relations from claimants($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($patchid =~ /^(\w+)$/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my $comp = $self->db->comp($x);
			$fnd += my @ids = $o_patch->relation('bug')->ids("patchid $comp '$x%'");
			print "Found ".@ids." bug_patch relations from patchid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($testid =~ /^(\w+)$/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my $comp = $self->db->comp($x);
			$fnd += my @ids = $o_test->relation('bug')->ids("testid $comp '$x%'");
			print "Found ".@ids." bug_test relations from testid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($noteid =~ /^(\w+)$/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my $comp = $self->db->comp($x);
			$fnd += my @ids = $o_note->relation('bug')->ids("noteid $comp '$x%'");
			print "Found ".@ids." bug_note relations from noteid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($patch =~ /(.+)/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my $comp = $self->db->comp($x);
			$fnd += my @ids = $o_patch->ids("body $comp '%$x%'");
			my $ids = join("', '", @ids);
			$fnd += @ids = $o_patch->relation('bug')->ids("patchid IN ('$ids')");
			print "Found ".@ids." bug_patch relations from patch content($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($test =~ /(.+)/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my $comp = $self->db->comp($x);
			$fnd += my @ids = $o_test->ids("body $comp '%$x%'");
			my $ids = join("', '", @ids);
			$fnd += @ids = $o_test->relation('bug')->ids("testid IN ('$ids')");
			print "Found ".@ids." bug_test relations from test content($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($note =~ /(.+)/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my $comp = $self->db->comp($x);
			$fnd += my @ids = $o_note->ids("body $comp '%$x%'");
			print "Found ".@ids." bug_note relations from note content($x)<br>";
			my $ids = join("', '", @ids);	
			$fnd += @ids = $o_note->relation('bug')->ids("noteid IN ('$ids')");
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($changeid =~ /^(.+)$/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my @ids  = ();
			my $comp = $self->db->comp($x);
			$fnd += my @pids = $o_change->relation('patch')->ids("changeid $comp '$x%'");
			if (scalar(@pids) >= 1) {
				$self->debug(2, "Found ".@pids." patch change relations from changeid($x)<br>") if $Perlbug::DEBUG;
				my $found = join("', '", @pids);	
				$fnd += @pids = $o_patch->relation('bug')->ids("patchid IN ('$found')");
			} else {
				$self->debug(2, "No patches found with changeid($x), trying with bugs...<br>") if $Perlbug::DEBUG; 
				my $comp = $self->db->comp($x);
				$fnd += @pids = $o_change->relation('bug')->ids("changeid $comp '$x%'");
				$self->debug(2, "Found ".@ids." bug change relations from changeid($x)<br>") if $Perlbug::DEBUG;
			}
			my $found = join("', '", @ids);	
			print "Found bugids(".@ids.") with changeid($x)<br>";
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($body =~ /(.+)/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			my $comp = $self->db->comp($x);
			$fnd += my @ids = $o_bug->ids("body $comp '%$x%'");
			print "Found ".@ids." bugids from body($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($msgid =~ /(.+)/o) { # email_msgid
			my ($x) = $self->db->quote($1);
			$wnt++;
			$fnd += my @mids = $o_msg->ids("LOWER(header) LIKE LOWER('%Message-Id: $x%')");
			print "Found ".@mids." messageids from header LIKE(%Message-Id: $x%)<br>";
			my $mids = join("', '", @mids);	
			$fnd += my @ids = $o_msg->relation('bug')->ids("messageid IN ('$mids')");
			print "Found ".@ids." message_bug relations from messageid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($msgs =~ /(\d+)(\+)*/o) {
			my $x = $1; 
			my $comp = ($2 eq '+') ? '>=' : '=';
			$wnt++;
			$self->exec('DELETE FROM pb_bug_message_count');
			$self->exec(q|INSERT INTO pb_bug_message_count 
				SELECT bugid, COUNT(messageid) FROM pb_bug_message GROUP BY bugid|
			);
			my @replied = $o_msg->relation('bug')->ids();
			my $replied = join("', '", @replied);
			my $insert = qq|INSERT INTO pb_bug_message_count SELECT bugid, 0 FROM pb_bug WHERE bugid NOT IN ('$replied')|;
			$self->exec($insert);
			my $count = qq|SELECT DISTINCT bugid FROM pb_bug_message_count WHERE messagecount $comp $x|;
			$fnd += my @ids = $self->get_list($count);
			print "Found ".@ids." message_bug count relations with msgs($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') ";
		}
		if ($bugid =~ /^\s*(.*\w+.*)\s*$/o) {
			my ($x) = $self->db->quote($1);
			my $comp = $self->db->comp($x);
			$sql .= " $andor bugid $comp '$x' ";
		}
		if ($version =~ /(.+)/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			# ($x) = $o_version->name2id([$x]) if $x !~ /^\d+$/;
			my $comp = $self->db->comp($x);
			my @vids = $o_version->ids("name $comp '$x%'");
			$fnd += my @ids = map { $o_version->read($_)->rel_ids('bug') } @vids;
			print "Found ".@ids." bug_version relations from versionid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($fixed =~ /(.+)/o) {
			my ($x) = $self->db->quote($1);
			$wnt++;
			# ($x) = $o_fixed->name2id([$x]) if $x !~ /^\d+$/;
			my $comp = $self->db->comp($x);
			my @fids = $o_fixed->ids("name $comp '$x%'");
			$fnd += my @ids = map { $o_fixed->read($_)->rel_ids('bug') } @fids;
			print "Found ".@ids." bug_fixed relations from fixed($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($status =~ /(\w+)/o) {
			my $x = $1;
			$wnt++;
			($x) = $o_status->name2id([$x]) if $x !~ /^\d+$/;
			my $xtra = ($status =~ /open/i) ? "OR statusid = ''" : '';
			$fnd += my @ids = $o_status->rel('bug')->ids("statusid = '$x' $xtra");
			print "Found ".@ids." bug_status relations from statusid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($group =~ /(\w+)/o) {
			my $x = $1;
			$wnt++;
			($x) = $o_grp->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_grp->relation('bug')->ids("groupid = '$x'");
			print "Found ".@ids." bug_group relations from groupid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($severity =~ /(\w+)/o) {
			my $x = $1;
			$wnt++;
			($x) = $o_severity->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_severity->relation('bug')->ids("severityid= '$x'");
			print "Found ".@ids." bug_severity relations from severityid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($osname =~ /(\w+)/o) {
			my $x = $1;
			$wnt++;
			($x) = $o_osname->name2id([$x]) if $x !~ /^\d+$/;
			$fnd += my @ids = $o_osname->relation('bug')->ids("osnameid = '$x'");
			print "Found ".@ids." bug_osname relations from osnameid($x)<br>";
			my $found = join("', '", @ids);	
			$sql .= " $andor bugid IN ('$found') " if scalar(@ids) >= 1;
		}
		if ($subject =~ /(.+)/o) {
			my ($qsubject) = $self->db->quote($1);
			my $comp = $self->db->comp($qsubject);
			$sql .= " $andor subject $comp '%".$self->case($qsubject)."%' ";
		}
		if ($sourceaddr =~ /(.+)/o) {
			my ($qsourceaddr) = $self->db->quote($1);
			my $comp = $self->db->comp($qsourceaddr);
			$sql .= " $andor sourceaddr $comp '%".$self->case($qsourceaddr)."%' ";
		}    
	}
	$DB::single=2; # rjsf

	if ($wnt >= 1 && $fnd == 0 && $andor eq 'AND') { #  && $withbug eq 'Yes') 
		$self->debug(1, "appear to want($wnt) unfound($fnd) andor($andor) withbug($withbug) data!") if $Perlbug::DEBUG;
		$sql .= " $andor 1 = 0 "; 
	} 
	# $self->result("want($wnt) fnd($fnd) andor($andor) withbug($withbug)");
	
	$sql .= " ORDER BY bugid $order"; #?
	$sql =~ s/^\s*AND\s*//io;
	print "SQL: $sql<hr>" if $sqlshow =~ /y/io;

	$self->debug(3, "SQL built: '$sql'") if $Perlbug::DEBUG;
	return $sql;
}


=item wildcard

Convert '*' into '%' for sqlquery

    my $string = $self->wildcard('5.*');

=cut

sub wildcard {
    my $self = shift;
    my $str  = shift;

    $str =~ s/\*+/%/go;

    return $str;
}

=item tenify

Create range of links to split (by tens or more) bugids from web query result.

	$self->tenify(\@_bids, 'bug', 7); # in chunks of 7

=cut

sub tenify {
    my $self   = shift;
    my $a_ids  = shift;
	my $obj    = shift;
    my $given  = shift || 25;
    my $slice  = (($given >= 1) && ($given <= 10000)) ? $given : 25;
	my $rng    = $self->{'_range'};
	my $ret    = '';

    if (ref($a_ids) ne 'ARRAY') {
		$self->error("Duff arrayref given to tenify($a_ids)");
	} else {
		my ($cnt, $min, $max) = (0, 1, 0);
	    my $url = $self->current('url');
        my $fmt = $self->current('format');
		my $range = $rng =~ /\w+/o ? "&range=$rng" : '';
		my $ids   = '';
		my @ids   = @{$a_ids};
		$self->debug(3, "obj($obj) given(@ids)") if $Perlbug::DEBUG;
		foreach my $id (@ids) {
	        $cnt++;
	        $max++;
	        $ids .= "&${obj}_id=$id"; 
	        if (($cnt == $slice) || ($max == $#ids + 1)) { # chunk
	            $ret .= qq|<a href="$url?req=${obj}_id$ids&format=$fmt&trim=${slice}$range">$min to $max</a>&nbsp;\n|;
	            $min = $max + 1; 
	            $ids = '';
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

