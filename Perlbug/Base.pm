# Perlbug base class 
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Base.pm,v 1.91 2001/12/03 10:39:20 richardf Exp $
# 
# TODO
# see scan
# 

=head1 NAME

Perlbug::Base - Module for bringing together Config, Log, Do(wrapper functions), Database, all Objects etc.

=head1 DESCRIPTION

Perlbug application interface, expected to be subclassed by actual interfaces, and/or used as configuration manager/reader.

see L<Perlbug::Interface::Cmd>, L<Perlbug::Interface::Web> etc.

=cut

package Perlbug::Base;
use strict; 
use vars qw($AUTOLOAD @ISA $VERSION); 
$VERSION = do { my @r = (q$Revision: 1.91 $ =~ /\d+/go); sprintf "%d."."%02d" x $#r, @r }; 
@ISA = qw(Perlbug::Do Perlbug::Utility); 
$| = 1; 

# internal utilities
use Perlbug; # version, debug and docs
use Perlbug::Config;
use Perlbug::Database;
use Perlbug::Do;
use Perlbug::Utility;
#use Perlbug::File; 
#use Perlbug::Object;
#use Perlbug::Relation;

# external utilities
# use Devel::Trace;
use Benchmark;
use Carp; 
use CGI qw(:standard);
use Data::Dumper;
use HTML::Entities;
use Mail::Address;
use Email::Valid;

my %CACHE_OBJECT = ();
my %CACHE_SQL    = ();
my %CACHE_TIME   = ();
my %CACHE_BUGIDS = ();
my $o_CONF = undef;
my $o_DB   = undef;
my $o_LOG  = undef;
my %DB     = ();

$Perlbug::i_LOG = 0;


=head1 SYNOPSIS

	my $o_base = Perlbug::Base->new;

	print "System maintainer contact: ".$o_base->system('maintainer');

	print "Total bugs: ".$o_base->object('bug')->ids;

	my $o_user = $o_base->object('user')->read('richard');

	print 'User('.$o_user->attr('name').') data: '.$o_user->format('l');


=head1 METHODS

=over 4

=item new

Create new Perlbug object, (see also L<Description> above):

	my $o_base = Perlbug::Base->new();

Loading casualties from the log:

	[0]  INIT (18214) scr(/usr/local/httpd/htdocs/perlbug/admin/perlbug.cgi), debug(01xX) Perlbug::Log=HASH(0x860ef1c)
	[1]  Connect host(localhost), db(perlbug), user(perlbug), pass(sqlpassword)
	[2]  Connected to perlbug: 42 tables
	[3]  Perlbug 2.52 loaded 21 objects(@objects)

		Startup:  0 wallclock secs ( 0.10 usr +  0.00 sys =  0.10 CPU)
        Loaded :  0 wallclock secs ( 0.27 usr +  0.00 sys =  0.27 CPU)
        Runtime:  0 wallclock secs ( 0.06 usr +  0.00 sys =  0.06 CPU)
        Alltook:  0 wallclock secs ( 0.43 usr +  0.00 sys =  0.43 CPU)
				  including 44 SQL statements  

=cut

sub new { 
    my $proto  = shift;
    my $class  = ref($proto) || $proto; 

	my $self = {};
    bless($self, $class);
	$self = $self->init(@_);

	return $self;
}


=item init

Initialize Base object

	my $self = $o_base->init;

=cut

sub init {
	my $self = shift;

	$self->clean_cache([], 'force');

	$o_CONF = $self->conf(@_); 

	$CACHE_TIME{'INIT'} = Benchmark->new if $Perlbug::DEBUG;
	$Perlbug::i_LOG = 0;
	%DB 	= $o_CONF->get_all('database');
	$o_DB   = Perlbug::Database->new(%DB);
	$o_LOG  = Perlbug::File->new($self->current('log_file'));

	$self->set_user($self->system('user'));	

    my $enabler = $self->system('enabled');
    if (!($enabler)) {     # OK 
        croak($self, "Enabler($enabler) disabled($Perlbug::VERSION) - not OK ($$ - $0) - cutting out!");
    } else {
		$CACHE_TIME{'PREP'} = Benchmark->new if $Perlbug::DEBUG; 
		my $version = $self->version;
		my $userid  = $self->isadmin;
		$self->debug(0, "INIT $version ($$) debug($Perlbug::DEBUG) scr($0)  user($userid)") if $Perlbug::DEBUG; 

		my $i_obj = 0;
		my $preload = $self->system('preload');
		if ($preload) {
			my @objs = $self->objects();
			my $title = $self->system('title');
			foreach my $obj (@objs) { # 21+ (see below) 
				my $o_obj = $self->object($obj);
				$i_obj++ if ref($o_obj);
				$self->debug(3, "Base: $title $version loaded($i_obj) $obj object($o_obj)") if $Perlbug::DEBUG; 
			}
		}
		$CACHE_TIME{'LOAD'} = Benchmark->new if $Perlbug::DEBUG;
	}

    return $self;
}


=item conf

Return Config object

	my $o_conf = $o_base->conf;

=cut

sub conf {
	my $self = shift;

	$o_CONF = ref($o_CONF) ? $o_CONF : Perlbug::Config->new(@_);

	return $o_CONF;
}


=item cgi

Get and set CGI->new object

=cut

sub cgi {
	my $self = shift;
	my $req  = shift;

	my $cgi  = $self->{'_cgi'} || 'uninitialised';

	if (ref($req)) {
		$cgi = $self->{'_cgi'} = $req;
	}

	unless (ref($cgi)) {
		$req = '-nodebug' unless $0 =~ /cgi$/; # context eq 'http'
		$cgi = $self->{'_cgi'} = CGI->new($req, @_);
	}
		
	return $cgi;
}


=item db 

get database object

=cut

sub db { 
	my $self = shift; 
	
	$o_DB = ref($o_DB) ? $o_DB : Perlbug::Database->new(%DB); 

	return $o_DB;
}


=item log

get log object

=cut

sub log { 
	my $self = shift; 

	$o_LOG = ref($o_LOG) ? $o_LOG : Perlbug::File->new($self->current('log_file')); 

	return $o_LOG;
}


=item debug

Debug method, logs to L</log_file>, with configurable levels of tracking:

Controlled by C<$ENV{'Perlbug_DEBUG'}> or $Perlbug::DEBUG or $o_base->current('debug')

Note that current('debug') will always override any local setting, being 
as it purports to be the application debug level, unless it is set to an 
empty string => ' '
 
	0 = login, interface, function (basic)	(if debug =~ /\w+/)	
	1 = decisions							(sets 01) 
	2 = data feedback from within methods 	(sets 012msX)
	3 = more than you want					(sets 0123mMsSxX)

	m = method names
	M = Method names (fully qualified)
	s = sql statements (num rows affected)
	S = SQL returns values (dump)
	x = execute statements (not SELECTs)
	X = EXecute returned n-results

=cut

sub debug {
    my $self = shift;
    my $flag = shift;

	# confess("called($flag) DEBUG($Perlbug::DEBUG)");
	my $DATA = '';
	if (!(defined($flag) && $flag =~ /^[mMsSxX0123]$/o)) {
		$self->logg("XXX: unsupported call($self, $flag, data(@_)");
	} else {	
		# print "flag($flag) Perlbug::DEBUG($Perlbug::DEBUG)\n";
		if ($flag =~ /^[$Perlbug::DEBUG]$/) {
			$DATA = "@_";
			if ($Perlbug::DEBUG =~ /[mM23]/o) { # DATA 
				my @caller = caller();
				CALLER:
				foreach my $i (0..4) {
					@caller = caller($i);
					last CALLER if $caller[3] !~ /debug/i;
				}
				my $caller = $caller[3];
				$caller =~ s/^(?:\w+::)+(\w+)$/$1/ unless $Perlbug::DEBUG =~ /M/o; 
				$DATA = "$caller: @_ <= debug_flag($flag)"; 
			}
			$self->logg($DATA) if $DATA;
		}
    }
	return $DATA;
}


=item _debug

Quiet form of B<debug()>, just calls the file method, and will never carp or confess, 
so the user generally won't see the contents of the message

=cut

sub _debug {
	my $self = shift;
	return $self->logg(@_);
}


=item logg

Files args to log file

	$o_base->logg('Done something');

=cut

sub logg {
    my $self = shift if ref($_[0]);
    my @args = @_;
    my $data = "[$Perlbug::i_LOG] ".join(' ', @_, "\n"); 
    if (length($data) >= 25600) {
        $data = "Excessive data length(".length($data).") called!\n"; 
    }
	$self->log->append($data);
	# print $data if $0 =~ /bugdb/;
    $Perlbug::i_LOG++;
}


=item get_rand_msgid

Returns randomised recognisableid . processid . rand(time)

	my $it = get_rand_msgid();

An alternative might be:

	my $msgid = "<19870502_$$.$time.$count@rfi.net>"; 

=cut

sub get_rand_msgid {
	my $self = shift;

	my $msgid = '<'.(join('_', 
		$self->system('title').'-tron',
		$$,
		rand(time).'@'.$self->email('domain'),
	)).'>';

	return $msgid;
}


=item splice

Returns a given Mail::Internet object s(p)liced up into useful bits.

    my ($o_hdr, $header, $body) = $self->splice($o_int); # todo ---sig

=cut

sub splice {
    my $self  = shift;
	my $o_int = shift;

	my @data = ();
	if (!ref($o_int)) {	
		$self->debug(0, "Can't splice inappropriate mail($o_int) object")
	} else {
		# $o_int->remove_sig;
		@data = (
			$o_int->head,
			join('', @{$o_int->head->header}),
			join('', @{$o_int->body}),
		);
	}

	return @data;
}


=item object

Return appropriate (cached) object:

	my $o_bug = $o_obj->object('Bug'); 

	my $o_usr = $o_obj->object('User'); 

For a relationship, the correct syntax would, (though deprecated, unsupported and generally disparaged :), be of the form source->target eg;

	my $o_bug_patch = $o_obj->object('bug->patch', '', 'to');

A relationship is taken care of by a special method: see L<Perlbug::Object::relation()>

All Object know what relationships they have: see L<Perlbug::Object::relations()>

etc.


=cut

sub object {
	my $self 	= shift;
	my $req  	= lc(shift);
	my $o_input = shift || '';
	my $type    = shift || '';
	my $o_obj 	= '';

	if (!$req) { 
		$self->error("requires a request($req) object: req($req) input($o_input) type($type)");
	} else { 
		if (ref($o_input)) {	# update cache
			my ($key, $hint) = ($o_input->attr('key'), $o_input->attr('hint'));
			if ($key eq $req || $hint eq $req) {
				$CACHE_OBJECT{$req} = $o_input; # x not parent/child x
			}
		}

		$o_obj = $CACHE_OBJECT{$req} if $self->system('cachable');

		if (!(ref($o_obj))) {	# get a new one
			my @args = ($self);
			my $request	= 'Perlbug::Object::'.ucfirst($req);
			if ($req =~ /^(\w+)\-\>(\w+)$/o) { # relation key
				$request = 'Perlbug::Relation'; 
				push(@args, $1, $2, $type);
			}
			my ($sep) = $self->system('separator');
			my $required = "$request.pm"; $required =~ s/::/$sep/g;
			# $DB::single=2;
			eval { require "$required" }; # :-\
			if ($@) {
				$self->error("failed to get req($req), request($request), required($required) $!\n");
			} else {
				$o_obj = $request->new(@args); 	# <-- !!!
				$CACHE_OBJECT{$req} = $o_obj;   # if $self->system('cachable');
				if (!(ref($o_obj))) { 
					$self->error("failed to request($req) object($o_obj) -> '$request->new(@args)' $!\n");
				}
			}
		}
	}

	$self->debug(3, qq|req($req), input($o_input), type($type) -> obj($o_obj)<br>\n|) if $Perlbug::DEBUG;
	return $o_obj;
}


=item version

Get Perlbug::Version

	my $vers = $o_base->version;

=cut

sub version { return $Perlbug::VERSION; }


=item isatest

Get and set isa test status

	my $i_isatest = $o_base->isatest( [01] );

=cut

sub isatest { 
	my $self = shift;
	my $arg  = shift || '';
	my $res  = my $orig = $self->current('isatest');

	if ($arg =~ /^([01])$/o) {
		$res = $self->current({'isatest', $1});
	}

	$self->debug(2, "isatest($arg) orig($orig) => res($res)") if $Perlbug::DEBUG;

	return $res;
}


=item myurl

Store and return the given url.

	my $url = $o_base->myurl( $url );

=cut

sub myurl { # 
    my $self = shift;
    my ($url) = shift || $self->cgi->url;

	$url =~ s/[^_](perlbug\.cgi)/_$1/gsi unless $self->current('framed');

    if (defined($url)) { # may be blank
        $self->current({'url', $url});
    }
    return $self->current('url');
}


=item href

Cheat Wrapper for Object::href

=cut

sub href {
	my $self = shift;

	my $o_obj = $self->object('bug');

	return $o_obj->href(@_);
}


=item dodgy_addresses

Returns quotemeta'd, OR-d dodgy addresses prepared for a pattern match ...|...|...

	my $regex = $o_obj->dodgy_addresses('from'); 
	
	# $regex  = 'perlbug\@perl\.com|perl5\-porters\@perl\.org|...'

=cut

# rjsf: Should be addresses()

sub dodgy_addresses { # context sensitive (in|out|to|from)
    my $self  = shift;
    my $scope = shift; # (from|to|cc|test...
	my $dodgy = '';

	my @duff  = (qw(MAILER-DAEMON postmaster)); 
	my @targs = $self->get_vals('target');
	my @frwds = $self->get_vals('forward');
	if ($scope =~ /^(from|sender)$/io) {					# FROM - don't accept mails from here
		push(@duff, @targs, @frwds,
				    $self->email('bugdb'),      $self->email('bugtron'));
	} elsif ($scope =~ /^(to|cc|reply-to)$/io) {			# TO   - don't send mails in this direction
		push(@duff, @targs, $self->email('bugdb'), $self->email('bugtron'));
	} elsif ($scope =~ /^test$/io) {						# TEST
		push(@duff, $self->email('test'), $self->target('test'), $self->forward('test'));
	} else { 											# ANY
		push(@duff); # could get paranoid :-)
	}
	chomp(@duff); # just in case

	DUFF:
    foreach my $duff ( map {split(/\s+/, $_) } @duff) {
        next unless $duff =~ /\w+/o;
        $dodgy .= quotemeta($duff).'|';
    }
    chomp $dodgy; # just in case again

    $dodgy =~ s/^(.+)?\|/$1/;
	$self->debug(3, "addresses($scope) -> '$dodgy'") if $Perlbug::DEBUG;

	return $dodgy; # regex 
}


sub format_overview {
	my $self = shift;
	my $ref  = shift;
	my $fmt  = shift || $self->current('format');
	return $self->SUPER::overview($ref, $fmt);
}

sub mypre {
	my $self = shift;
	my $fmt  = shift || $self->current('format');
	my $cxt  = $self->current('context');

	my $ret  = ($cxt =~ /^[hH]/o && $fmt =~ /[aAlixX]/o) ? '<pre>' : '';

	return $ret;
}

sub mypost {
	my $self = shift;
	my $fmt  = shift || $self->current('format');
	my $cxt  = $self->current('context');

	my $ret  = ($cxt =~ /^[hH]/o && $fmt =~ /[aAlixX]/o) ? '</pre>' : '';

	return $ret;
}


=item objects 

Return list of names of objects in application, by type 

	my @objnames = $o_pb->objects('mail');

	my @flags = $o_pb->objects('flag');

=cut

sub objects { # 
	my $self = shift;
	my $type = shift || '_%';

	my @names = $self->object('object')->col('name', "type LIKE '$type'");

	return @names;
}


=item flags

Returns array of options for given type.

    my @list = $pb->flags('group');

=cut

sub flags {
    my $self = shift;
    my $arg  = shift;
    my @flags = ();

	# my $types = join('|', qw(group osname project severity status version)); # yek
	my $types = join('|', ($self->object('object')->names("type = 'flag'"), 'group'));
    if ($arg !~ /^($types)$/) {
        $self->error("Can't get flags for invalid arg($arg)");
    } else {
		@flags = $self->object($arg)->col('name');
    }

    return @flags;
}


=item all_flags

Return all flags available in db keyed by type/ident.

    my %flags = $pb->all_flags;

	%flags = ( # now looks like this:
		'group'		=> ['core', 'docs', 'install'], 	# ...
		'status'	=> ['open', 'onhold', 'closed'], 	# ...
		# ...
	);

=cut

sub all_flags {
    my $self  = shift;
    my %flags = ();
	# my @types = qw(fixed group osname project severity status version); # yek
	my @types = ($self->object('object')->names("type = 'flag'"), 'group');
	foreach my $flag (@types) {
		my @flags = $self->flags($flag);
		$flags{$flag} = \@flags;        
    }
    return %flags;
}


=item date_hash

Returns convenient date hash structure with sql query for values

	my %dates = $o_base->date_hash;


	# 'this week' => 'TO_DAYS(SYSDATE()) - TO_DAYS(created) <= 7'

=cut

sub date_hash {
    my $self = shift;
    my %dates = (
	    'any'               => '',
	    'today'             => ' TO_DAYS(SYSDATE()) - TO_DAYS(created) <= 1  ',
	    'this week'         => ' TO_DAYS(SYSDATE()) - TO_DAYS(created) <= 7  ',
	    'less than 1 month' => ' TO_DAYS(SYSDATE()) - TO_DAYS(created) <= 30 ',
	    'less than 3 months'=> ' TO_DAYS(SYSDATE()) - TO_DAYS(created) <= 90 ',
	    'over 3 months'     => ' TO_DAYS(SYSDATE()) - TO_DAYS(created) >= 90 ',
	);
    return %dates;
}


=item help

Returns help message for perlbug database.

	my $help = $pb->help;

=cut

sub help {
    my $self = shift;

	my $email = $self->email('bugdb');
	my $url = $self->web('hard_wired_url');
	my $maintainer = $self->system('maintainer');
	my $title = $self->system('title');

	my $help = qq|
	A searchable live reference database of email-initiated bugs, patches and tests, etc.

	Email: $email

	WWW: $url 
	
    Comments, feedback, suggestions to: $maintainer.
	|;	

    return $help;
}


=item spec

Returns spec message for perlbug database.

	print $pb->spec;

=cut

sub spec {
    my $self = shift;

	my $ehelp = $self->email('help');
	my $o_bug = $self->object('bug');
	my $o_usr = $self->object('user');
	my $o_status = $self->object('status');

	my $bids = $o_bug->count();
	my ($openid) = $o_status->name2id(['open']);
	my $open = my @open = $o_status->read($openid)->rel_ids('bug');
	my $admins = my @admins = $o_usr->ids("active = '1'");
	my ($bugdb, $cgi, $title) = ($self->email('bugdb'), $self->web('hard_wired_url'), $self->system('title'));
my $info = qq|
The $title bug tracking system $Perlbug::VERSION: $bids bugs ($open open). 

------------------------------------------

Anyone may search the database via the web:

	$cgi
		
or the email interface:
		
	To: $ehelp

------------------------------------------
	|;	

    return $info;
}


=item check_user

Checks given user is registered in the database as an admin.  

Sets userid in L<admin> and thereby L<status> for later reference.

	$pb->check_user($user_name);

=cut

sub check_user { 
    #default administrator check (email uses from, web uses user/pass)
	my $self = shift;
	my $user = shift || 'generic';
	$self->debug(2, "check_user($user)") if $Perlbug::DEBUG;
	my $o_usr = $self->object('user');
    if ($self->system('restricted')) {
		$self->debug(2, "restricted...") if $Perlbug::DEBUG;
		my @ids = $o_usr->ids("userid = '$user' AND active IN ('1', '0')");
		$self->debug(2, "ids(@ids)") if $Perlbug::DEBUG;
	    ID:
	    foreach my $id (@ids) {
			next if $id =~ /generic/io;
	        if (($id =~ /^\w+$/o) && ($id =~ /$user/)) {
				$self->current({'admin', $id});
	            # $self->current({'switches', $self->system('user_switches').$self->system('admin_switches')});
	            $self->debug(1, "given param ($user) taken as admin id ($id)"); # , switches set: ".$self->current('switches')) if $Perlbug::DEBUG;
	            last ID;
	        } else {
				$self->debug(1, "unrecognised user($user) id($id)") if $Perlbug::DEBUG;
			}
        }
	} else {
		$self->debug(2, "unrestricted...") if $Perlbug::DEBUG;
        $self->current({'admin', $user});
        # $self->current({'switches', $self->system('user_switches').$self->system('admin_switches')});
	    $self->debug(1, "Non-restricted user($user) taken as admin id"); # , switches set: ".$self->current('switches')) if $Perlbug::DEBUG;
	}
	$self->debug(1, "check_user($user)->'".$self->isadmin."'") if $Perlbug::DEBUG;
	return $self->isadmin;
}


=item isadmin

Returns current admin userid (post check_user), checks whether system is restricted or not.

	print 'current user: '.$pb->isadmin; # name | ''

=cut

sub isadmin { # retrieve admin flag (and id)
    my $self = shift;

    my ($user) = ($self->system('restricted')) 
		? grep(!/generic/i, $self->current('admin')) 
		: $self->current('admin');

    return $user;
}


=item switches

Returns array of appropriate switches based on B<isadmin> or arg.

	my @switches = $o_pb->switches([admin|user]); # exlusive

=cut

sub switches { # admin|user
    my $self = shift;
	my $arg  = shift || '';
	my @switches = ();

	my @admin = split(//, $self->system('admin_switches'));
	my @user  = split(//, $self->system('user_switches'));

	if ($arg eq 'admin') {
		@switches = @admin;
	} elsif ($arg eq 'user') {
		@switches = @user;
	} else {
		@switches = ($self->isadmin) ? (@admin, @user) : @user;
	}

	@switches = sort grep(/^\w$/, @switches);
	
	$self->debug(2, "in($arg) out(".join(', ', @switches).')') if $Perlbug::DEBUG;

    return @switches;
}


=item create_file

Create new file with this data:

    $ok = $self->create("$dir/$file.tmp", $data);

=cut

sub create {
    my $self = shift;
    my $file = shift;
    my $data = shift;
	my $perm = shift || '0766';
	my $o_file = '';
    
    # ARGS
    if (!(($file =~ /\w+/o) && ($data =~ /\w+/o))) {
        $self->errors("Duff args given to create($file, $data, $perm)");
    } else {
    	$o_file = Perlbug::File->new($file, '>', $perm);
        if (ref($o_file)) {
			$o_file->append($data);
        } else {
            $self->error("failed to create file($file) -> o_file($o_file)");
        }
    }
    
    return $o_file;
}


=item prioritise

Set priority nicer by given integer, or by 12.

=cut

sub xprioritise {
    my $self = shift;
    # return "";  # disable
    my ($priority) = ($_[0] =~ /^\d+$/o) ? $_[0] : 12;
	my $pre = getpriority(0, 0);
	setpriority(0, 0, $priority);
	my $post = getpriority(0, 0);
	$self->debug(2, "Priority($priority): pre ($pre), post ($post)") if $Perlbug::DEBUG;
	return $self;
}


=item set_user

Sets the given user to the runner of this script.

=cut

sub set_user {
    my $self = shift; # ignored
    my $user = shift;
    my $oname  = getpwuid($<); 
    my $original = qq|orig($oname, $<, [$(])|;
    my @data = getpwnam($user);
    ($>, $), $<, $() = ($data[2], $data[3], $data[2], $data[3]);
    my $pname  = getpwuid($>); 
    my $post = qq|curr($pname, $<, [$(])|;
	$self->debug(2, "pre($original) current($post)") if $Perlbug::DEBUG;
	return $self;
}


=item read

First we look in site, then docs...

	my @data = $o_base->read('header'); # or footer or mailhelp	

=cut

sub read {
    my $self = shift;
	my $tgt  = shift;

	my $file = $self->target2file($tgt);
	if (!(-e $file)) {
		$self->error("can't read duff target($tgt) file($file): $!");
	} else {
		my $o_file = Perlbug::File->new($file, '<');
        if (!defined ($o_file)) {
            $self->error("failed to prep read of file($file) -> o_file($o_file)");
        } else {
			return $o_file->read();
        }
	}
 
	return ();
}


=item target2file

Return appropriate dir/file.ext for given target string

	my $filename = $o_base->target2file('header'); # -> '~/text/header'

=cut

sub target2file {
	my $self = shift;
	my $tgt  = shift;
	my $file = '';

	if ($tgt !~ /\w+/) {
		$self->error("can't remap duff target($tgt)!");
	} else {
		$file = $self->directory('text').$self->system('separator').$tgt;
	}

	return $file;
}


=item clean_cache

Application objects/methods may call this to clean the sql and/or object cache, particularly useful when objects or their relationships are being created or deleted:

It will not do so while application cacheing is on unless used with the 'force' command.

See also L<cachable()>

Returns self

	my $o_obj = $o_obj->clean_cache([], [force]); 		# all (sql, objects, time)

	my $o_obj = $o_obj->clean_cache('sql', [force]); 	# just sql

	my $o_obj = $o_obj->clean_cache('object', [force]); # just objects

=cut

sub clean_cache {
	my $self = shift;
	my $tgt  = shift;
	my $force= shift || '';

	if ($tgt !~ /\w+/) {
		$self->error("requires target($tgt) to clean and optional force($force)?");
	} else {
		if (ref($tgt) eq 'ARRAY') { # flush
			%CACHE_BUGIDS = ();
			%CACHE_OBJECT = ();
			%CACHE_SQL    = ();
			%CACHE_TIME   = ();
		} else {
			%CACHE_BUGIDS = () if $tgt =~ /bugids/io && ($force || !$self->system('cachable')); 
			%CACHE_OBJECT = () if $tgt =~ /object/io && ($force || !$self->system('cachable')); 
			%CACHE_SQL    = () if $tgt =~ /sql/io  	 && ($force || !$self->system('cachable')); 
			%CACHE_TIME   = () if $tgt =~ /time/io   && ($force || !$self->system('cachable')); 
		}
	}	

    return $self;
}


=item get_list

Returns a simple list of items (column values?), from a sql query.

Optional second parameter overrides sql statement/result cacheing.

	my @list = $pb->get_list('SELECT COUNT(bugid) FROM db_table', ['refresh']);

=cut

sub get_list {
	my $self = shift;
	my $sql  = shift; 
	my $refresh = shift || '';

	return $self->get_data($sql, $refresh, 'list');
}


=item get_data

Returns a list of hash references, from a sql query.

Optional second parameter overrides sql statement/result cacheing.

	my @hash_refs = $pb->get_data('SELECT * FROM db_table', ['refresh']);

=cut

sub get_data {
	my $self = shift;
	my $sql  = shift;	
	my $refresh = shift || '';
	my $list    = shift || '';

	my $a_info = [];
	my $a_cache = $CACHE_SQL{$sql}; # unless $refresh;

	if (defined($a_cache) && ref($a_cache) eq 'ARRAY' && $refresh eq '') { 
		$a_info = $a_cache;
		$self->debug('s', "reusing CACHED SQL: $sql($a_cache)") if $Perlbug::DEBUG;
	} else {
		$self->debug('s', "SQL: $sql") if $Perlbug::DEBUG;
		my $sth = $self->db->query($sql);
 		if (!defined($sth)) {
        	$self->error("undefined cursor for get_data: '$DBI::errstr'");
    	} else {
			if ($list eq 'list') {
				while ( (my $info) = $sth->fetchrow) { #? fetchrow.$ref(_hashref)
					push (@{$a_info}, $info) if defined $info;
				}
			} else {
				while (my $info = $sth->fetchrow_hashref) { # 
					push (@{$a_info}, $info) if ref($info) eq 'HASH';
				}
			}
			# $self->rows($sth);
			$CACHE_SQL{$sql} = $a_info if $self->system('cachable');
    		$self->debug('S', 'found '.$sth->rows." rows($a_info): ".Dumper($a_info)) if $Perlbug::DEBUG;
    	}
		undef $sth;
	}
	# $self->debug('S', $a_info) if $Perlbug::DEBUG;
	return @{$a_info}; 
}    


=item exec

Returns statement handle from sql query.

	my $sth = $pb->exec($sql);

=cut

sub exec {
	my $self = shift;
	my $sql  = shift;

	$self->debug('x', $sql) if $Perlbug::DEBUG;

	my $i_ok = 0;
	my $sth = $self->db->query($sql);
	if (defined($sth)) { 
		$i_ok++;
		my $i_rows = $sth->rows;
		$self->debug('X', "affected rows($i_rows)") if $Perlbug::DEBUG;
	} else {
	    $self->error("Exec($sql) error: $Mysql::db_errstr");
	}

	return $sth;
}


=item extant

Track bugids from this session

	my @extant = $o_base->extant($bugid);

=cut

sub extant {
	my $self = shift;
	my $bugid = shift || '';
	
	$CACHE_BUGIDS{$bugid}++ if $bugid;

	return keys %CACHE_BUGIDS;
}


=item exists

Does this bugid exist in the db?

=cut

sub exists {
	my $self = shift;
	my $bid = shift || '';
	
	my $i_ok = ($self->object('bug')->exists([$bid])) ? 1 : 0;

	return $i_ok;
}


=item notify

Notify all relevant parties of incoming item

	my $i_ok = $o_base->notify('bug', '19870502.007');

=cut

sub notify {
	my $self = shift;
	my $obj  = shift;
	my $oid  = shift;
	my $i_ok = 0;

	if (!($obj =~ /^\w+$/o && $oid =~ /\w+/o)) {
		$self->error("requires valid object($obj) and id($oid)!");
	} else {
		my $o_obj = $self->object($obj)->read($oid);
		if (!($o_obj->READ)) {
			$self->error("requires valid object($obj) and id($oid)!");
		} else {
			my $header = $o_obj->data('header');
			my $body   = $o_obj->data('body');

			if (!$self->current('mailing')) {
				$self->debug(0, "not mailing(".!$self->current('mailing').")") if $Perlbug::DEBUG;
			} else {
				my $o_int = $self->setup_int($header, $body);
				my ($o_hdr, $header, $body) = $self->splice($o_int);
				if (!ref($o_hdr)) {
					$self->debug(0, "no header($o_hdr) for notification!");
				} else {
					my ($from, $orig, $replyto, $subject, $to) = ('', '', '', '', '');
					my @cc   = $o_hdr->get('Cc'); @cc = () unless @cc;
					$from    = $o_hdr->get('From');
					$orig    = $o_hdr->get('Subject');
					$replyto = $o_hdr->get('Reply-To');
					$to      = $o_hdr->get('To');
					chomp(@cc, $from, $orig, $replyto, $subject, $to); 
					$subject  = ($obj =~ 'bug' ? '' : ucfirst($obj))." [ID $oid] $orig";

					# ACKNOWLEDGE - noack
					if (grep(/noack/io, $to, @cc) || $body =~ /(ack(knowledge)*=no)/iso) {
						$self->debug(1, "body(to|cc) contains ack(\w+)=no -> not acknowledging!") if $Perlbug::DEBUG;
					} else {
						$self->debug(1, "body(to|cc) doesn't contain ack(\w+)=no -> acknowledging") if $Perlbug::DEBUG;
						my $o_ack = $self->get_header($o_hdr);
						$o_ack->replace('Subject', "Ack - $subject");
						$o_ack->replace('To', $self->from($replyto, $from)); 
						my $response = join('', $self->read('response'));
						my $footer   = join('', $self->read('footer'));
						$response =~ s/(An ID)/A $obj ID ($oid)/;	    # clunk
						$response =~ s/(Original\ssubject:)/$1 $orig/;	# clunk
						$i_ok = $self->send_mail($o_ack, $response.$footer);
					}

					# NOTIFY - nocc
					if (grep(/no(cc|notify)/io, $to, @cc)) {
						$self->debug(1, "to($to), cc(@cc) contains no(cc|notify) -> not notifying!") if $Perlbug::DEBUG;
					} else {
						$self->debug(1, "to($to), cc(@cc) doesn't contain no(cc|notify) -> notifying") if $Perlbug::DEBUG;
						my @ccs = ($obj eq 'bug' ) ? $self->bugid_2_addresses($oid, 'new') : ();
						$o_hdr  = $self->addurls($o_hdr, $obj, $oid);
						$o_hdr->replace('Subject', $subject);
						my $type = ($subject =~ /^\s*OK/io) ? 'ok' : 'remap';
	$DB::single=2;
						my $o_notify = $self->get_header($o_hdr, $type);	
	$DB::single=2;
						$o_notify->replace('Cc', join(', ', @ccs));
						$i_ok = $self->send_mail($o_notify, $body); # auto
					}
				}
			}
		}
    }

	return $i_ok;
}


=item setup_int

Setup Mail::Internet object from given args, body is default unless given.

	my $o_int = $o_base->setup_int(\%header, [$body]);   # 'to' => 'to@x.net'
	
or

	my $o_int = $o_base->setup_int($db_header, [$body]); # could be folded

=cut

sub setup_int {
	my $self   = shift;
	my $header = shift;
	my $body   = shift || 'no-body-given';
	my $o_int  = undef;
	
	my %header   = ();
	if (ref($header) eq 'HASH') {
		%header = %{$header};
	} else {
		if ($header =~ /^([^:]+:\s*\w+.*)/mo) { 
			$header =~ s/\r?\n\s+/ /sog; # unfold
			%header = ($header =~ /^([^:]+):(.*)$/gmo);	
		} else { 
			$self->debug(0, "Can't setup int from invalid header($header)!");
		}
	}

	if (keys %header) {
		my $o_hdr    = Mail::Header->new;
		TAG:
		foreach my $tag (keys %header) {
			my @tags = (ref($header{$tag})) eq 'ARRAY' ? @{$header{$tag}} : ($header{$tag});
			$tag =~ s/^\s*//; $tag =~ s/\s*$//; # stray newlines creeping in?
			$o_hdr->add($tag, @tags);
		}
		$o_hdr->add('Message-Id', $self->get_rand_msgid) unless $o_hdr->get('Message-Id'); 
		$o_hdr->add('Subject', q|some irrelevant subject|) unless $o_hdr->get('Subject'); 

		$o_int = Mail::Internet->new('Header' => $o_hdr, 'Body' => [map { "$_\n" } split("\n", $body)]);
		my $to   = $o_int->head->get('To') || '';
		my $from = $o_int->head->get('From') || ''; 
		if (!($to =~ /\w+/o && $from =~ /\w+/o)) { 
			$self->error("Invalid mail($o_int) via header: ".Dumper(\%header));
			undef $o_int;
		}
	}

	return $o_int;
}


=item notify_cc

Notify db_bug_address addresses of changes, given current/original status of bug.

	my $i_ok = $o_base->notify_cc($bugid, $orig);

=cut

sub notify_cc {
	my $self  = shift;
	my $bid   = shift;
	my $orig  = shift || '';
	my $i_ok  = 1;

	$self->clean_cache([]);
	my $o_bug = $self->object('bug');

	if (!($o_bug->ok_ids([$bid]) and $self->exists($bid))) {
		$i_ok = 0;
		$self->error( "notify_cc requires a valid bugid($bid)");
	} else {
		my $bugdb = $self->email('bugdb');
		my $url = 'http://'.$self->web('domain').'/'.$self->web('cgi')."?req=bug_id&bug_id=$bid\n";
		my ($bug) = $o_bug->read($bid)->format('a'); # a bit less more data :-)
		my $diff = $o_bug->diff($orig, $bug);
		my $status = qq|The status of bug($bid) has been updated:
$bug

The difference from the original:
$diff
		|;
		$status .= qq|
To see this (and more) data on the web, visit:

	$url

		|;
		my ($addr) = $o_bug->col('sourceaddr');
		my ($o_to) = Mail::Address->parse($addr);
		my ($to) = (ref($o_to)) ? $o_to->format : $self->system('maintainer');
		my @ccs = $self->bugid_2_addresses($bid, 'update');
		use Perlbug::Interface::Email; # yek
		my $o_email = Perlbug::Interface::Email->new;
		my $o_notify = $o_email->get_header($o_bug->data('header'));
		$o_notify->add('To', $to);
		# $o_notify->add('Cc', join(', ', @ccs)) unless grep(/nocc/i, @unknown, @versions);
		$o_notify->add('From', $self->email('bugdb'));
		$o_notify->add('Subject', $self->system('title')." $bid status update");
		$i_ok = $o_email->send_mail($o_notify, $status) if $self->current('mailing') == 1;
		$self->debug(3, "notified($i_ok) <- ($bid)") if $Perlbug::DEBUG;
	}

	return $i_ok;
}


sub todo {
	my $self  = shift;
	my $todo  = shift;

	my $i_ok  = 1;
	if ($todo !~ /\w+/) {
		$i_ok = 0;
		$self->error("requires a something todo($todo)");
	} else {
		my $fmt = $self->current('format');
		$self->current({'format', 'a'});
		my $to = $self->system('maintainer');
		require Perlbug::Interface::Email; # yek
		my $o_email = Perlbug::Interface::Email->new;
		my $o_todo = $o_email->get_header;
		$o_todo->add('To', $to);
		$o_todo->add('From', $self->email('bugdb'));
		$o_todo->add('Subject', $self->system('title')." todo request");
		$i_ok = $o_email->send_mail($o_todo, $todo);
		$self->debug(3, "todo'd($i_ok) <- ($todo)") if $Perlbug::DEBUG;
		$self->current({'format', $fmt});
	}

	return $i_ok
}


=item track

Track some function or modification to the db.

	$sth = $self->track($obj, $id, $entry);

=cut

sub track {
	my $self 	= shift;
	my $key     = shift;
	my $id		= shift;
	my $entry	= shift; # 

	my $userid  = $self->isadmin;
	my ($quoted)= $self->db->quote($entry);

	my $insert = qq|INSERT INTO pb_log SET 
		created		= SYSDATE(),
		modified	= SYSDATE(),
		entry		= '$quoted', 
		userid		= '$userid', 
		objectid	= '$id', 
		objectkey	= '$key'
	|;	

	# $o_log->create($track);
	my $sth = $self->db->query($insert);
  	if (!defined($sth)) {
		$self->error("track failure ($insert) -> result($sth)");
	}		

	return $sth;
}


=item ck822

Email address checker (RFC822) courtesy Tom Christiansen/Jeffrey Friedl.

    print (($o_email->ck822($addr)) ? "yup($addr)\n" : "nope($addr)\n");

=cut

sub ck822 {
    my $self = shift;
    my $addr = shift;

	my $i_ok = 0;
    if (!(Email::Valid->address($addr))) {
		$self->debug(0, "rfc822 failure on '$addr'") if $Perlbug::DEBUG; 
	} else {
		$i_ok++;
		$self->debug(3, "rfc822 success on '$addr'") if $Perlbug::DEBUG; 
	}

	return $i_ok;
}



=item htpasswd

Modify, add, delete, comment out entries in .htpasswd

    $i_ok = $o_web->htpasswd($userid, $pass);   # entry ok?

    @entries = $o_web->htpasswd;                # returns list of entries ('userid:passwd', 'user2:pass2'...)

=cut

sub htpasswd { #
    my $self = shift;
    my $user = shift;
    my $pass = shift; 
    my $htpw = $self->directory('config').'/.htpasswd';
    $self->debug(1, "htpasswd($user, $pass) with($htpw)") if $Perlbug::DEBUG;
    my @data = $self->log->copy($htpw, $htpw.'.bak', '0660'); # backitup
    my $i_ok = 1;
    if (!(($i_ok == 1) or (scalar(@data) >= 1))) {
        $self->error("copy($htpw, $htpw.'.bak') must have failed?");
    } else {
		my $htpass = join('', grep(/\w+/, @data));
        $self->debug(2, "Existing htpasswd file: '$htpass'") if $Perlbug::DEBUG;
        if (!(($user =~ /^\w+$/o) && ($pass =~ /\w+/o))) {
			$i_ok = 0;
            my $err = "Can't open htpasswd file($htpw)! $!";
            $self->error($err);
        } else {
            $self->debug(1, "HTP: working with user($user) and pass($pass)") if $Perlbug::DEBUG;
            if ($htpass !~ /^$user:(.+)$/m) {	# modify?
                $htpass .= "$user:$pass\n";
                $self->debug(1, "HTP: adding new user($user) / pass($pass)") if $Perlbug::DEBUG;
            } else {                        	# add!
                my $found = $1;
                $self->debug(3, "found($found)") if $Perlbug::DEBUG;
                if ($found ne $pass) {
                    $htpass =~ s/^$user:(.+)$/$user:$pass/m;
                    $self->debug(1, "HTP: changing user($user) found($found) to pass($pass)") if $Perlbug::DEBUG;
                } else {
                    $self->debug(1, "Not changing user($user) or pass($pass) with found($found)") if $Perlbug::DEBUG;
                }
            } 
            $htpass =~ s/^\s*$//gmo; 
			$i_ok = $self->create($htpw, $htpass, '0660'); # file
            $self->debug(3, "Modified($i_ok) htpasswd file: '$htpass'") if $Perlbug::DEBUG;
    	}
    }
    return $i_ok; # (wantarray ? @data : $i_ok);
}


=item clean_up

Clean up previous logs activity whenever run, and report briefly on how long this process took.

Exits when done.

=cut

sub clean_up {
    my $self = shift;
    my $max  = shift || $self->system('max_age');
    $self->debug(3, "clean_up($max)") if $Perlbug::DEBUG;
	my $found = 0;
    my $cleaned = 0;

	$self->tell_time() if $Perlbug::DEBUG;

	my $o_range = $self->object('range');
	my @defunct = $o_range->ids("TO_DAYS(modified) < (TO_DAYS(SYSDATE()) -10)");
	$self->debug(3, "deletable ranges(@defunct)") if $Perlbug::DEBUG;
	# $o_range->delete(\@defunct);
	# $o_range->relation('bug')->delete(\@defunct);
	if ($max =~ /^\d+/o) {
		foreach my $DIR (qw(logs temp)) { # 
			my $dir = $self->directory('spool')."/$DIR";
			$self->debug(3, "cleaning($dir)") if $Perlbug::DEBUG;
        	if (-d $dir) {
	    		my ($remcnt, $norem) = (0, 0); 
	    		opendir DIR, $dir or $self->error("Can't open dir ($dir) for clean up $!");
	    		my @files = grep(/\w+\.\w+$/, readdir DIR);
	    		$found += scalar(@files);
				$self->debug(3, 'Found: '.scalar(@files).' files') if $Perlbug::DEBUG;
	    		close DIR;
	    		foreach my $file (@files) {
	        		next unless -f "$dir/$file";
	        		my $FILE = "$dir/$file";
	        		if (-M $FILE >= $max) { # remove file if old 
	            		if (!unlink($FILE)) {
	                		$self->error("Unable to remove file '$FILE' $!");
	                		$norem++;
	            		} else {
	                		$self->debug(3, "Removed ($FILE)") if $Perlbug::DEBUG;
	                		$remcnt++;
	            		}
	        		} else {
	            		$self->debug(3, "Ignoring recent file '$FILE'") if $Perlbug::DEBUG;
	        		}
	    		}
            	$self->debug(3, "Process ($$): dir($dir) fertig: rem($remcnt), norem($norem) of ".@files) if $Perlbug::DEBUG;
            	$cleaned += $remcnt;
        	} else {
            	$self->error("Can't find directory: '$dir'");
        	}   
		}
    }
    $self->debug(3, "Cleaned up: age($max) -> files($cleaned) of($found)") if $Perlbug::DEBUG;
	
	return ();
}


=item tell_time

Put runtime info in log file, if $Perlbug::DEBUG 

	my $feedback = $o_base->tell_time(Benchmark->new);

=cut

sub tell_time {
	my $self = shift;
	my $feedback = ' ';

	if ($Perlbug::DEBUG) {
		my $now  = shift || Benchmark->new; 

		$CACHE_TIME{'DONE'} = $now;

		my $start = $CACHE_TIME{'INIT'} || 0;
		my $prep  = $CACHE_TIME{'PREP'} || 0;
		my $load  = $CACHE_TIME{'LOAD'} || 0;
		my $done  = $CACHE_TIME{'DONE'} || 0;
		my $x = qq|start($start), prep($prep), load($load), done($done)|;

		my $started = timediff($prep, $start);
		my $loaded  = timediff($load, $prep);
		my $runtime = timediff($done, $load);
		my $total   = timediff($done, $start);

		$feedback = ($started && $loaded && $runtime && $total) 
			? qq|$0 debug($Perlbug::DEBUG)
		Startup: @{[timestr($started)]}
		Loaded : @{[timestr($loaded)]}
		Runtime: @{[timestr($runtime)]}
		Alltook: @{[timestr($total)]}
			including $Perlbug::Database::SQL SQL statements 
			using $Perlbug::Database::HANDLE database handle/s
		|
			: '';
		$self->debug(1, $feedback); 
	}

	return $feedback;
} 


=item parse_str

Returns hash of data extracted from given string.

Matches are 'nearest wins' after 4 places ie; clos=closed.

	my %cmds = $o_obj->parse_str('5.0.5_444_aix_irix_<bugid>_etc' | (qw(patchid bugid etc));

	%cmds = (
		'bugids'		=> \@bugids,
		'change'	=> {
			'ids'	=> [qw(3)],
			'names'	=> [qw(553)],
		},
		'osname'	=> {
			'ids'	=> [qw(12 14)],
			'names'	=> [qw(aix macos irix)],
		},
		'unknown'	=> {
			'ids'	=> [qw(0123456789)],
			'names'	=> [qw(etc)],
		},
	);

=cut

sub parse_str {
	my $self = shift;
	my $str  = shift;
	my @args = split(/(\s|_)+/, $str);
	my %cmds = (); 
	
	my $o_bug = $self->object('bug');
	my @flags = grep(!/fixed/i, $self->objects('flag'), 'group');
	my @names = map { substr($_, 0, 4) } map { $self->object($_)->col('name') } @flags;
	my %seen  = ();

	ARG:
	foreach my $arg (@args) {
		next ARG unless $arg =~ /\w+/o;
		next ARG if $seen{$arg};
		my $arg4 = substr($arg, 0, 4);
		# print "arg($arg) => arg4($arg4)<hr>";
		if ($o_bug->ok_ids([$arg])) {	# bugid
			push(@{$cmds{'bug'}{'ids'}}, $arg);
		} elsif (grep(/^\Q$arg4/i, @names)) {				
			foreach my $flag (@flags) {					# flag
				my $o_obj = $self->object($flag);
				my @types = $o_obj->col('name');
				my ($argtype) = ($flag =~ /^(group|severity|status)$/) 
					? grep(/^$arg/i, @types) 	# loose 
					: grep(/^$arg$/i, @types);	# tighter (eg; osname...)
				if ($argtype =~ /\w+/) {			    # type 
					my ($id) = $o_obj->name2id([$arg]);
					push(@{$cmds{$flag}{'ids'}}, $id) if $id;
					push(@{$cmds{$flag}{'names'}}, $argtype);
				}
			}
		} else {										# unknown
			my $key = ($arg	=~ /^\d+$/o) ? 'ids' : 'names';
			push(@{$cmds{'unknown'}{$key}}, $arg);
		}
		$seen{$arg}++;
	}
	# $DB::single=2;
	$self->debug(1, "parse in($str), out-> ".Dumper(\%cmds)) if $Perlbug::DEBUG;

	return %cmds;
}


=item scan

Scan for perl relevant data putting found or default switches in $h_data.

Looking for both group=docs and '\brunning\s*under\ssome\s*perl' style markers.

    my $h_data = $o_mail->scan($body);

Migrate to return parse_str() style hashref

=cut

sub scan { # ids/names
    my $self    = shift;
    my $body    = shift;
    my %data 	=  (); 

    my $i_cnt   = 0;
	$self->debug(2, "Scanning mail (".length($body).")") if $Perlbug::DEBUG;
    my %flags = $self->all_flags;
	$flags{'category'} = $flags{'group'};

	LINE:
    foreach my $line (split(/\n/, $body)) {         # look at each line for a type match
        $i_cnt++;
		next LINE unless $line =~ /\w+/o;
		$self->debug(2, "LINE($line)") if $Perlbug::DEBUG;
		TYPE:
        foreach my $type (keys %flags) {     					# status, group, severity, version...
            $self->debug(2, "Type($type)") if $Perlbug::DEBUG;
            my @setindb = @{$flags{$type}} if ref($flags{$type}) eq 'ARRAY';
            $self->debug(2, "Setindb(@setindb)") if $Perlbug::DEBUG;
			SETINDB:
			foreach my $indb (@setindb) {                   	# open closed onhold, core docs patch, linux aix...
				next SETINDB unless $indb =~ /\w+/o;
				next SETINDB if $type eq 'version' && $indb !~ /\d$/;
				if ($line =~ /\s*$type\s*=\s*(3d)*$indb\s*/i) {			# osname=(3d)*winnt|macos|aix|linux|...
					$data{$type}{$indb}++;
					$self->debug(2, "Bingo: flag($type=$indb)") if $Perlbug::DEBUG;
					# next TYPE; tut tut - we want all we can get
				}	
			} 

			my @matches = $self->get_keys($type);               # SET from config file
            $self->debug(2, "Matches(@matches)") if $Perlbug::DEBUG;
			MATCH:
			foreach my $match (@matches) {                  	# \bperl|perl\b, success\s*report, et
				next MATCH unless $match =~ /\w+/o;
				$self->debug(2, "Match($match)?") if $Perlbug::DEBUG;
				if ($line =~ /$match/i) {                   	# to what do we map?
					if ($type eq 'version') {               	# bodge for version
						$^W = 0;
						my $num = $1.$2.$3.$4.$5;				#
						$^W = 1;
						if ($num =~ /^\d[\d\.]+?\d$/o) {
							$data{$type}{$num}++;
							my $proj = $num;
							$proj =~ s/^(\d).*/$1/;
							$data{'project'}{"perl$proj"}++;
							$self->debug(1, "Bingo: line($line) version ($num) proj($proj)-> next LINE") if $Perlbug::DEBUG;
							next TYPE;
						}
					} else { # attempt to set flags based on data found
						next MATCH unless $line =~ /=/o;		# short circuit
						my $target = $self->$type($match);  	# open, closed, etc.
						if (grep(/^$target/i, @setindb)) {  	# do we have an assignation?
							$data{$type}{$target}++;
							$self->debug(1, "Bingo: target($target) -> next LINE") if $Perlbug::DEBUG;
							next TYPE;
						}
					}
				}
			}

		}
    }

	# workaround for category/group mish-mash
	if ($data{'category'}) {
		$data{'group'} = (ref($data{'group'})) 
			? { %{$data{'group'}}, %{$data{'category'}} } 
			: { %{$data{'category'}} }; 
		delete $data{'category'};
	}

	# convert to parse_str style
	my %rel = ();
	foreach my $key (keys %data) {
		# $data{$key} = [$self->default_flag($key)] unless ref($data{$key}) eq 'ARRAY'; 
		push(@{$rel{$key}{'names'}}, keys %{$data{$key}});
	}
	$rel{'status'}{'names'} = [qw(open)] unless ref($rel{'status'}{'names'}) eq 'ARRAY';

    my $rel = scalar keys %rel;
    $self->debug(2, "Scanned count($i_cnt), found($rel): ".$self->dump(\%rel)) if $Perlbug::DEBUG;  

    return \%rel;
}


=item bugid_2_addresses

Return addresses based on context

	my @addrs = $o_email->bugid_2_addresses($bugid);

=cut

sub bugid_2_addresses {
    my $self  = shift;
    my $bid   = shift;
    my $context = shift || 'auto'; # or new|update...

    my $feedback = $self->feedback($context); # (active|admin|cc|maintainer|group|master|source)
    $self->debug(2, "generating bugid($bid) context($context) feedback($feedback)") if $Perlbug::DEBUG; 
    my @addrs = ();
    my $o_bug = $self->object('bug')->read($bid);

	if ($o_bug->READ) {
		my $o_grp = $self->object('group');
		my $o_usr = $self->object('user');

		if ($bid !~ /\w+/) {
			$self->debug(1, "require bugid($bid)") if $Perlbug::DEBUG;
		} else {
			if ($feedback =~ /active/o) {
				my @active = $o_usr->col('address', "active='1'");
				push(@addrs, @active);
			}
			if ($feedback =~ /admin/o) {
				my @uids = $o_bug->rel_ids('user');
				if (@uids) {
					my @admins = map { $o_usr->read($_)->data('address') } @uids;
					push(@addrs, @admins);
				}	
			}
			if ($feedback =~ /maintainer/o) {
				push(@addrs, $self->system('maintainer'));
			}
			if ($feedback =~ /cc/o) {
				my @ccs = $o_bug->rel_ids('address');
				push(@addrs, @ccs);
			}
			if ($feedback =~ /group/o) {
				my $gid = $o_bug->rel_ids('group');
				if ($gid) {
					# print "gid($gid)".$o_bug->format;
					my @uids = $o_grp->read($gid)->rel_ids('user');
					if (@uids) {
						my @gaddrs = map { $o_usr->read($_)->data('address') } @uids; 
						push(@addrs, @gaddrs);
					}
				}
			}
			if ($feedback =~ /sourceaddr/o) { # always
				my ($srcaddr) = $o_bug->sourceaddr;	
				push(@addrs, $srcaddr);
			}
		}
    }


    return @addrs;
}


=item compare

Compare two arrays: returns 1 if identical, 0 if not.

    my $identical = compare(\@arry1, \@arry2); # tomc

=cut

sub compare {           # 
	my $self = shift;
    my ($first, $second) = @_;
	local $^W = 0;  # silence spurious -w undef complaints
	return 0 unless @$first == @$second;
	for (my $i = 0; $i < @$first; $i++) {
    	return 0 if $first->[$i] ne $second->[$i];
	}
	return 1;
}


sub AUTOLOAD {
	my $self = shift;

	my $meth = $AutoLoader::AUTOLOAD = $AUTOLOAD;

    return if $meth =~ /::DESTROY$/io; 
    $meth =~ s/^(.*):://o;

	# if ($meth =~ /^debug(\w)$/) {
	#	return $self->debug($1, @_); # migration debug(2, $msg) => debug2($msg) support
	# } else {
		return $self->conf->$meth(@_); 
	# }
}


$SIG{'INT'} = sub {
	carp "Perlbug interupted: bye bye!";
	exit(1);	
};


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 1999 2000 2001

=cut

# 
1;
