# Perlbug base class 
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Base.pm,v 1.75 2001/04/26 13:19:48 perlbug Exp $
# 
# get_(list|data) -> hashref/array
# $o_PB->debug('s', "<$i_SQL> ".$sql) if $DEBUG;
# carp("Database::query [$i_SQL] -> ($sql)");
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
$VERSION = do { my @r = (q$Revision: 1.75 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG  = $ENV{'Perlbug_Base_DEBUG'} || $Perlbug::Base::DEBUG || '';
@ISA = qw(Perlbug::Do); 
$| = 1; 

# external utilities
use Benchmark;
use Carp;
use CGI qw(:standard);
use Data::Dumper;
use HTML::Entities;
use Mail::Address;
use Mail::Header;

# internal utilities
use Perlbug; # version, debug and docs
use Perlbug::Config;
use Perlbug::Database;
use Perlbug::Do;
use Perlbug::File; 
use Perlbug::Object;
use Perlbug::Relation;

my %CACHE_OBJECT = ();
my %CACHE_SQL    = ();
my %CACHE_TIME   = ();
my $o_CONF = undef;
my $o_DB   = undef;
my $o_LOG  = undef;
my $i_LOG  = 0;
my %DB     = ();


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
	$self = $self->init();
	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	return $self;
}


=item init

Initialize Base object

	my $self = $o_base->init;

=cut

sub init {
	my $self = shift;
	$self->clean_cache([], 'force');

	$CACHE_TIME{'INIT'} = Benchmark->new();
	$i_LOG = 0;

	$o_CONF = Perlbug::Config->new(); # rjsf
	%DB = (
		'user'		=> $o_CONF->database('user'),
		'database'	=> $o_CONF->database('database'),
		'sqlhost'	=> $o_CONF->database('sqlhost'),
		'password'	=> $o_CONF->database('password'),
	);
	$o_DB   = Perlbug::Database->new(%DB);
	# $o_DB   = Perlbug::Database->new($self);
	$o_LOG  = Perlbug::File->new($self->current('log_file'));

	$self->set_user($self->system('user'));	

    my $enabler = $self->system('enabled');
    if (!($enabler)) {     # OK 
        croak($self, "Enabler($enabler) disabled($Perlbug::VERSION) - not OK ($$ - $0) - cutting out!");
    } else {
		$CACHE_TIME{'PREP'} = Benchmark->new;
		$self->debug(0, "INIT ($$) debug($Perlbug::DEBUG, $DEBUG) scr($0)"); # if $DEBUG

		my $i_obj = 0;
		my $version = $self->version;
		my $preload = $self->system('preload');
		if ($preload) {
			my $caller = caller();
			my $cachable = $self->cachable;
			my @things = $self->things();
			my $title = $self->system('title');
			foreach my $thng (@things) { # 21+ (see below) 
				my $o_obj = $self->object($thng);
				$i_obj++ if ref($o_obj);
				$self->debug(3, "Base: $title $version loaded($i_obj) $thng object($o_obj)") if $DEBUG; 
			}
		}
		$self->debug(0, "$version ($$) loaded($preload) $i_obj objects"); # if $DEBUG; 
		$CACHE_TIME{'LOAD'} = Benchmark->new;
	}

    return $self;
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

Controlled by C<$ENV{'Perlbug_DEBUG'}> or $o_base->current('debug')

Note that current('debug') will always override any local setting, being 
as it purports to be the application debug level, unless it is set to an 
empty string => ' '
 
	0 = login, object, function (basic)		
	1 = decisions							(sets x) 
	2 = data feedback from within methods 	(sets i, x, X)
	3 = more than you want					(sets C, I, s, S, O, X)

	m = method names
	M = Method names (fully qualified)
	s = sql statements (num rows affected)
	S = SQL returns values (dump)
	x = execute statements (not SELECTs)
	X = EXecute returned n-results

	Where a capital letter is given:
		the data is Dumper'd if it's a reference, the result of a sql query, or an object

    $pb->debug("duff usage");              			# undefined second arg (treated as level 0)
    $pb->debug(0, 	"always tracked");        		# debug off
    $pb->debug(1, 	"tracked if $debug =~ /[01]/");	# debug on = decisions
    $pb->debug(2, 	"tracked if $debug =~ /[012]/");# debug on = talkative  

=cut


sub debug { # Perlbug::Base|Interface|Object::Bug|Email::DEBUG?
    my $self = shift;
    my $flag = shift;
	
	# my $LEVEL = $Perlbug::DEBUG;
	# $Perlbug::DEBUG = $Perlbug::DEBUG || $DEBUG;	
	# $self->base->debug(@_);
	# $Perlbug::DEBUG = $ORIG;	

	my $DATA = '';
	if (!(defined($flag) && $flag =~ /^[mMsSxX012345]$/)) {
		$self->logg("XXX: unsupported call($self, $flag, data(@_)");
	} else {	
		my ($current) = $Perlbug::DEBUG; 
		if ($flag =~ /^$current$/) {
			if (!($flag =~ /[mM234]/)) { # DATA 
				$DATA = "@_";
			} else { 								# METH 
				my @caller = caller();
				CALLER:
				foreach my $i (0..4) {
					@caller = caller($i);
					last CALLER if $caller[3] !~ /debug/i;
				}
				my $caller = $caller[3];
				$caller =~ s/^(?:\w+::)+(\w+)$/$1/ unless $current =~ /M/; 
				$DATA = "$caller: @_ < -flag($flag)"; 
			}
		}
		$self->logg($DATA) if $DATA;
    }
	return $DATA;
}


=item _debug

Quiet form of B<debug()>, just calls the file method, and will never carp, 
so the user generally won't see the contents of the message

=cut

sub _debug { # quiet
	my $self = shift;
	return $self->logg(@_);
}


=item error

Handles error messages, is currently fatal(croak)

	$o_base->error($msg);

=cut

sub error {
	my $self = shift;
	my $errs = "Error: ".join(' ', @_)."<br>\n";
	$self->debug(0, $errs); # error!
	#$self->logg(0, "\n***\n".$errs."\n***\n"); # error!
	confess("ERROR: $errs"); 
}


=item logg

Files args to log file

	$o_base->logg('Done something');

=cut

sub logg { #
    my $self = shift;
    my @args = @_;
	unshift(@args, (ref($self)) ? '' : $self); # trim obj and position left side
    my $data = "[$i_LOG] ".join(' ', @args, "\n");  # uninitialised value???
    if (length($data) >= 25600) {
        $data = "Excessive data length(".length($data).") called!\n"; 
    }
	$self->log->append($data);
    $i_LOG++;
}


=item cgi

Get and set CGI->new object

=cut

sub cgi {
	my $self = shift;
	my $req  = shift;

	my $cgi  = $self->{'_cgi'} || 'unitialised';

	if (ref($req)) {
		$cgi = $self->{'_cgi'} = $req;
	}

	unless (ref($cgi)) {
		$cgi = $self->{'_cgi'} = CGI->new($req, @_);
	}
		
	return $cgi;
}


sub isabase { return 1; }


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

sub object { # rjsf: speed up 
	my $self 	= shift;
	my $req  	= lc(shift);
	my $o_input = shift || '';
	my $type    = shift || '';
	my $o_obj 	= '';

	if (!$req) { 
		$self->error("requires a request($req) object: req($req) input($o_input) type($type)");
	} else { 
		my @args = ($self);
		my $request	= 'Perlbug::Object::'.ucfirst($req);
		if ($req =~ /(\w+)\-\>(\w+)/) { # relation key
			$request = 'Perlbug::Relation'; 
			push(@args, $1, $2, $type);
		}

		if (ref($o_input)) {
			my ($key, $hint) = ($o_input->attr('key'), $o_input->attr('hint'));
			if ($key eq $req || $hint eq $req) {
				$CACHE_OBJECT{$req} = $o_input; # x not parent/child x
			}
		}
		$o_obj = $CACHE_OBJECT{$req} if ref($CACHE_OBJECT{$req}) && $self->cachable;

		if (!(ref($o_obj))) {
			my ($sep) = $self->system('separator');
			my $required = "$request.pm"; $required =~ s/::/$sep/g;
			eval { require "$required" }; # :-\
			if ($@) {
				$self->error("failed to get req($req), request($request), required($required) $!\n");
			} else {
				$o_obj = $request->new(@args); 	# <-- !!!
				$CACHE_OBJECT{$req} = $o_obj if $self->cachable;
				if (!(ref($o_obj))) { 
					$self->error("failed to request($req) object($o_obj) -> '$request->new(@args)' $!\n");
				}
			}
		}
	}

	$self->debug(3, qq|req($req), input($o_input), type($type) -> obj($o_obj)<br>\n|) if $DEBUG;
	return $o_obj;
}


=item cachable

Return cachable status for application

	my $i_ok = $o_base->cachable(); # 1 or 0

=cut

sub cachable { my $self = shift; return $self->system('cachable'); }


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
	my $arg = shift || '';
	if ($arg =~ /^([012])$/) {
		my ($res) = $self->current({'isatest', $1});
		$self->debug(1, "setting isatest($arg)->res($res)") if $DEBUG;
	}
	return $self->current('isatest');
}


=item url

Store and return the given url.

	my $url = $o_base->url( $url );

=cut

sub url { # 
    my $self = shift;
    my ($url) = shift || $self->cgi->url;

	$url =~ s/[^_](perlbug\.cgi)/_$1/gsi unless $self->current('framed');

    if (defined($url)) { # may be blank
        $self->current({'url', $url});
    }
    return $self->current('url');
}


=item quote

Quote arg for insertion into db (dbh wrapper)

	my $quoted = $o_base->quote($arg);

=cut

sub quote {
	my $self = shift;

	return $self->db->quote(@_);
}


=item href

Cheat Wrapper for Object::href

=cut

sub href {
	my $self = shift;

	my $o_obj = $self->object('bug');

	return $o_obj->href(@_);
}


=item do

Wrap a Perlbug::Do command

    my @res = $pb->do('b', [<bugid1>, <bugid2>], $body);

=cut

sub do { 
    my $self = shift;
    my $arg = shift;

	my $user = $self->isadmin;
	my @switches = $self->get_switches;
    my @res = ();
	if ($arg =~ /^[@switches]$/) {
		my @args = (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;
	    $self->debug(1, "Allowing user($user) to Do::do$arg(@args)") if $DEBUG;
		my $this = "do$arg";
    	@res = $self->$this(@_); # doit
	} else {
		$self->error("User($user) not allowed to do $arg(@_) with switches(@switches)");
	}

	return @res;
}


=item dodgy_addresses

Returns quoted, OR-d dodgy addresses prepared for a pattern match ...|...|...

	my $regex = $o_obj->dodgy_addresses('from'); # $rex = 'perlbug\@perl\.com|perl5\-porters\@perl\.org|...'

=cut

sub dodgy_addresses { # context sensitive (in|out|to|from)
    my $self  = shift;
    my $scope = shift; # (from|to|cc|test...

	my $i_ok  = 1;
	my @duff  = (qw(MAILER-DAEMON postmaster)); 
	my @targs = $self->get_vals('target');
	my @frwds = $self->get_vals('forward');
	if ($scope =~ /^(from|sender)$/i) {					# FROM - don't accept mails from here
		push(@duff, @targs, @frwds,
				    $self->email('bugdb'),      $self->email('bugtron'));
	} elsif ($scope =~ /^(to|cc|reply-to)$/i) {			# TO   - don't send mails in this direction
		push(@duff, @targs,
					$self->email('bugdb'), $self->email('bugtron'));
	} elsif ($scope =~ /^test$/i) {						# TEST
		push(@duff, $self->email('test'), $self->target('test'), $self->forward('test'));
	} else { 											# ANY
		push(@duff); # could get paranoid :-)
	}
	chomp(@duff); # just in case
	my $dodgy = '';
    foreach my $duff ( map {split(/\s+/, $_) } @duff) {
        next unless $duff =~ /\w+/;
        $dodgy .= quotemeta($duff).'|';
    }
    chomp $dodgy; # just in case again
    $dodgy =~ s/^(.+)?\|/$1/;
    undef $dodgy unless $i_ok == 1; # something in it for example?
	$self->debug(3, "dodgy_addresses($scope) -> '$dodgy'") if $DEBUG;

	return $dodgy; # regex 
}


sub format_overview {
	my $self = shift;
	my $ref  = shift;
	my $fmt  = shift || $self->current('format');
	return $self->SUPER::overview($ref, $fmt);
}

sub pre {
	my $self = shift;
	my $fmt  = shift || $self->current('format');
	my $cxt  = $self->current('context');

	my $ret  = ($cxt =~ /^[hH]/ && $fmt =~ /[aAlixX]/) ? '<pre>' : '';

	return $ret;
}

sub post {
	my $self = shift;
	my $fmt  = shift || $self->current('format');
	my $cxt  = $self->current('context');

	my $ret  = ($cxt =~ /^[hH]/ && $fmt =~ /[aAlixX]/) ? '</pre>' : '';

	return $ret;
}

=item things 

Return list of names of things in application 

	my @objnames = $o_pb->things('mail');

	my @flags = $o_pb->things('flag');

=cut

sub things { # 
	my $self = shift;
	my $type = shift || '_%';

	my @names = $self->object('thing')->col('name', "type LIKE '$type'");

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

	my $types = join('|', qw(group osname severity status version)); 
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
		'group'	=> ['core', 'docs', 'install'], 	# ...
		'status'	=> ['open', 'onhold', 'onhold'], 	# ...
		# ...
	);

=cut

sub all_flags {
    my $self  = shift;
    my %flags = ();
	my @types = qw(group osname severity status version); 
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


=item active_admins

Returns active admins from db.

    my @active = $pb->active_admins;

=cut

sub active_admins {
    my $self = shift;
	my @active = $self->object('user')->col('userid', "active = '1'");
    return @active;
}


=item active_admin_addresses

Returns active admin addresses from db.

    my @addrs = $pb->active_admin_addresses;

=cut

sub active_admin_addresses {
    my $self = shift;
	my @active = $self->object('user')->col('address', "active = '1'");
    return @active;
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

	my $spec = $pb->spec();

# rjsf: migrate to using v$Perlbug::VERSION.$etc.pod2html(Perlbug.pm) > spec.html

=cut

sub spec {
    my $self = shift;
	my $ehelp= $self->email('help');
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
	$self->debug(2, "check_user($user)") if $DEBUG;
	my $o_usr = $self->object('user');
    if ($self->system('restricted')) {
		$self->debug(2, "restricted...") if $DEBUG;
		my @ids = $o_usr->ids("userid = '$user' AND active IN ('1', '0')");
		$self->debug(2, "ids(@ids)") if $DEBUG;
	    ID:
	    foreach my $id (@ids) {
			next if $id =~ /generic/i;
	        if (($id =~ /^\w+$/) && ($id =~ /$user/)) {
				$self->current({'admin', $id});
	            $self->current({'switches', $self->system('user_switches').$self->system('admin_switches')});
	            $self->debug(1, "given param ($user) taken as admin id ($id), switches set: ".$self->current('switches')) if $DEBUG;
	            last ID;
	        } else {
				$self->debug(1, "unrecognised user($user) id($id)") if $DEBUG;
			}
        }
	} else {
		$self->debug(2, "unrestricted...") if $DEBUG;
        $self->current({'admin', $user});
        $self->current({'switches', $self->system('user_switches').$self->system('admin_switches')});
	    $self->debug(1, "Non-restricted user($user) taken as admin id, switches set: ".$self->current('switches')) if $DEBUG;
	}
	$self->debug(2, "check_user($user)->'".$self->isadmin."'") if $DEBUG;
	return $self->isadmin;
}


=item isadmin

Stores and returns current admin userid (post check_user), checks whether system is restricted or not.

	next unless $pb->isadmin;

=cut

sub isadmin { #store and retrieve admin flag (and id)
    my $self = shift;
    my $prop = shift;
    my ($user) = ($self->system('restricted')) 
		? grep(!/generic/i, $self->current('admin')) 
		: $self->current('admin');
    return $user;
}


=item ok

Checks bugid is in valid format (looks like a bugid) (uses get_id):

	&do_this($id) if $pb->ok($id);

=cut

sub ok { # rjsf: migrate -> o_bug->ok_ids
    my $self = shift;
    my $given = shift;
    my ($ok, $bid) = $self->get_id($given); 
    return $ok;
}


=item get_id

Determine if the string contains a valid bug ID

=cut

sub get_id { # rjsf: migrate -> o_bug->ok_ids
    my $self = shift;
    my $str = shift;
	my $o_bug = $self->object('bug');
	my @ids = $o_bug->str2ids($str);
    return (1, @ids);
}


=item _switches

Stores and returns ref to list of switches given by calling script.
Only these will be parsed within the command hash in L<process_commands>.

	my $switches = $pb->_switches(qw(e t T s S h l)); #sample

=cut

sub _switches { # rjsf: migrate -> switches
    my $self = shift;
    if (@_) { 
        my $switches = join(' ', grep(/^a-z$/i, @_)); 
        $self->debug(1, "Setting allowed, and order of, switches ($switches)") if $DEBUG;
        $self->current({'switches', $switches});
    }
    return $self->current('switches');
}

sub file_ext { return ''; }


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
    if (!(($file =~ /\w+/) && ($data =~ /\w+/))) {
        $self->errors("Duff args given to create($file, $data, $perm)");
    } else {
    	$o_file = Perlbug::File($file, '>', $perm);
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

sub prioritise {
    my $self = shift;
    # return "";  # disable
    my ($priority) = ($_[0] =~ /^\d+$/) ? $_[0] : 12;
	$self->debug(2, "priority'ing ($priority)") if $DEBUG;
	my $pre = getpriority(0, 0);
	setpriority(0, 0, $priority);
	my $post = getpriority(0, 0);
	$self->debug(2, "Priority: pre ($pre), post ($post)") if $DEBUG;
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

	my $o_obj = $o_obj->clean_cache('sql', [force]); # 

	my $o_obj = $o_obj->clean_cache('object', [force]); #

=cut

sub clean_cache {
	my $self = shift;
	my $tgt  = shift;
	my $force= shift || '';

	if ($tgt !~ /\w+/) {
		$self->error("requires target($tgt) to clean and optional force($force)?");
	} else {
		if (ref($tgt) eq 'ARRAY') { # flush
			%CACHE_OBJECT = ();
			%CACHE_SQL    = ();
			%CACHE_TIME   = ();
		} else {
			%CACHE_OBJECT = () if $tgt =~ /object/i && ($force || !$self->cachable); 
			%CACHE_SQL    = () if $tgt =~ /sql/i 	&& ($force || !$self->cachable); 
			%CACHE_TIME   = () if $tgt =~ /time/i 	&& ($force || !$self->cachable); 
		}
	}	

    return $self;
}


=item get_list

Returns a simple list of items (column values?), from a sql query.

	my @list = $pb->get_list('SELECT COUNT(bugid) FROM db_table');

=cut

sub get_list {
	my $self = shift;
	my ($sql) = @_; 

	my $a_info = [];
	my $a_cache = ($self->cachable) ? $CACHE_SQL{$sql} : '';
	# my $a_info = (ref($a_cache) eq 'ARRAY' && scalar(@{$a_cache}) >= 1) ? $a_cache : []; 

	if (ref($a_cache) eq 'ARRAY') { 
		$a_info = $a_cache;
		$self->debug('s', "CACHE SQL: $sql -> ".@{$a_info}." items") if $DEBUG;
	} else {
		my $csr = $self->db->query($sql);
		if (!defined($csr)) {
	    	$self->error("undefined cursor for get_list(): $Mysql::db_errstr");
		} else {
	    	while ( (my $info) = $csr->fetchrow) { #? fetchrow.$ref(_hashref)
		    	push (@{$a_info}, $info) if defined $info;
	    	}
    		$self->debug('S', 'found '.$csr->num_rows.' rows') if $DEBUG;
	    	my $res = $csr->finish;
		}
	}

	$CACHE_SQL{$sql} = $a_info if $self->cachable;
	# $self->debug('S', $a_info) if $DEBUG;
	return @{$a_info};
}


=item get_data

Returns a list of hash references, from a sql query.

	my @hash_refs = $pb->get_data('SELECT * FROM db_table');

=cut

sub get_data {
	my $self = shift;
	my ($sql) = @_;	

	my $a_info = [];
	my $a_cache = $CACHE_SQL{$sql};

	if (defined($a_cache) && ref($a_cache) eq 'ARRAY') { 
		$a_info = $a_cache;
		$self->debug('s', "CACHE SQL: $sql") if $DEBUG;
	} else {
		my $csr = $self->db->query($sql);
 		if (!defined($csr)) {
        	$self->error("undefined cursor for get_data: '$Mysql::db_errstr'");
    	} else {
    		while (my $info = $csr->fetchrow_hashref) { # 
    	    	if (ref($info) eq 'HASH') {
					push (@{$a_info}, $info) if defined $info;
            	}
    		}
			# $self->rows($sth);
    		$self->debug('S', 'found '.$csr->num_rows.' rows') if $DEBUG;
    		my $res = $csr->finish
    	}
	}
	$CACHE_SQL{$sql} = $a_info if $self->cachable;
	# $self->debug('S', $a_info) if $DEBUG;
	return @{$a_info}; 
}    


=item exec

Returns statement handle from sql query.

	my $sth = $pb->exec($sql);

=cut

sub exec {
	my $self = shift;
	my $sql = shift;

	$self->debug('x', $sql) if $DEBUG;
	my $sth = $self->db->query($sql);
	if (defined($sth)) { 
		my $rows = $sth->rows | $sth->affected_rows | $sth->num_rows;   
		$self->debug('X', "affected rows($rows)") if $DEBUG;
	} else {
	    $self->error("Exec ($sql) error: $Mysql::db_errstr");
	}

	return $sth;
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


=item notify_cc

Notify db_bug_address addresses of changes, given current/original status of bug.

	my $i_ok = $o_base->notify_cc($bugid, $orig);

=cut

sub notify_cc {
	my $self  = shift;
	my $bid   = shift;
	my $orig  = shift || '';

	my $i_ok  = 1;
	# return $i_ok; # rjsf temp

	my $o_bug = $self->object('bug');

	if (!($self->ok($bid) and $self->exists($bid))) {
		$i_ok = 0;
		$self->error( "notify_cc requires a valid bugid($bid)");
	} else {
		my $bugdb = $self->email('bugdb');
		my $url = $self->web('hard_wired_url')."?req=bug_id&bug_id=$bid\n";
		# my ($bug) = $self->dob([$bid]); # a bit less more data :-)
		my ($bug) = $o_bug->read($bid)->format('a'); # a bit less more data :-)
		my $status = qq|The status of bug($bid) has been updated:
Original status:
$orig

Current status:
|;
		$status .= $bug; 
		$status .= qq|
To see current data on this bug($bid) send an email of the following form:

	To: $bugdb
	Subject: -B $bid

Or to see this data on the web, visit:

	$url

		|;
# rjsf: The update was made with this note:
		my ($addr) = $self->object('bug')->col('sourceaddr', "bugid = '$bid'");
		my ($o_to) = Mail::Address->parse($addr);
		my ($to) = (ref($o_to)) ? $o_to->format : $self->system('maintainer');
		my @ccs = $self->bugid_2_addresses($bid, 'update');
		use Perlbug::Interface::Email; # yek
		my $o_email = Perlbug::Interface::Email->new;
		$o_email->_original_mail($o_email->_duff_mail); # dummy
		my $o_notify = $o_email->get_header;
		$o_notify->add('To', $to);
		# $o_notify->add('Cc', join(', ', @ccs)) unless grep(/nocc/i, @unknown, @versions);
		$o_notify->add('From', $self->email('bugdb'));
		$o_notify->add('Subject', $self->system('title')." $bid status update");
		$i_ok = $o_email->send_mail($o_notify, $status);
		$self->debug(3, "notified($i_ok) <- ($bid)") if $DEBUG;
	}

	return $i_ok
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
		$self->debug(3, "todo'd($i_ok) <- ($todo)") if $DEBUG;
		$self->current({'format', $fmt});
	}

	return $i_ok
}


=item track

Track some function or modification to the db.

	$i_tracked = $self->track($type, $id, $entry);

=cut

sub track { # could migrate to defensive o_log->track
	my $self 	= shift;
	    my $key     = shift;
	my $id		= shift;
	my $entry	= shift; # cmd 

	my $userid  = $self->isadmin;
	my $quoted  = $self->quote($entry);

	$self->debug(3, "key($key), id($id), entry($entry)->quoted($quoted), userid($userid)") if $DEBUG;
	# track = 0 if $key =~ /log/i || $self->object($key)->attr('track') != 1
	my $insert = qq|INSERT INTO pb_log SET 
		created=SYSDATE(),
		modified=SYSDATE(),
		entry=$quoted, 
		userid='$userid', 
		objectid='$id', 
		objectkey='$key'
	|;	

	my $i_ok = 1;
	my $res = $self->db->query($insert);
  	if (!defined($res)) {
		$i_ok = 0;
		$self->error("track failure ($insert) -> '$res'");
	}		

	return $i_ok;
}


=item ck822

Email address checker (RFC822) courtesy Tom Christiansen/Jeffrey Friedl.

    print (($o_email->ck822($addr)) ? "yup($addr)\n" : "nope($addr)\n");

=cut

sub ck822 { # RFC internet address checker
    my $self = shift;
    my $addr = shift;

    my $isok = '';
    my $i_ok = 0;
	local $_;

    # ck822 -- check whether address is valid rfc 822 address
    # tchrist@perl.com
    #
    # pattern developed in program by jfriedl; 
    # see "Mastering Regular Expressions" from ORA for details

    # this will error on something like "ftp.perl.com." because
    # even though dns wants it, rfc822 hates it.  shucks.

    ($isok = <<'EOSCARY') =~ s/\n//g;
(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n
\015()]|\\[^\x80-\xff])*\))*\))*(?:(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\
xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|"(?:[^\\\x80-\xff\n\015"
]|\\[^\x80-\xff])*")(?:(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xf
f]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*\.(?:[\040\t]|\((?:[
^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\
xff])*\))*\))*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;
:".\\\[\]\000-\037\x80-\xff])|"(?:[^\\\x80-\xff\n\015"]|\\[^\x80-\xff])*"))
*(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\
n\015()]|\\[^\x80-\xff])*\))*\))*@(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\
\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\04
0)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-
\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff])*\])(?:(?:[\040\t]|\((?
:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80
-\xff])*\))*\))*\.(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\(
(?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\040)<>@,;:".\\\[\]
\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\
\x80-\xff\n\015\[\]]|\\[^\x80-\xff])*\]))*|(?:[^(\040)<>@,;:".\\\[\]\000-\0
37\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|"(?:[^\\\x80-\xf
f\n\015"]|\\[^\x80-\xff])*")(?:[^()<>@,;:".\\\[\]\x80-\xff\000-\010\012-\03
7]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\
\[^\x80-\xff])*\))*\)|"(?:[^\\\x80-\xff\n\015"]|\\[^\x80-\xff])*")*<(?:[\04
0\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]
|\\[^\x80-\xff])*\))*\))*(?:@(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x
80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\040)<>@
,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]
)|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff])*\])(?:(?:[\040\t]|\((?:[^\\
\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff
])*\))*\))*\.(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^
\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\040)<>@,;:".\\\[\]\000-
\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-
\xff\n\015\[\]]|\\[^\x80-\xff])*\]))*(?:(?:[\040\t]|\((?:[^\\\x80-\xff\n\01
5()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*,(?
:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\0
15()]|\\[^\x80-\xff])*\))*\))*@(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^
\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\040)<
>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xf
f])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff])*\])(?:(?:[\040\t]|\((?:[^
\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\x
ff])*\))*\))*\.(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:
[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\040)<>@,;:".\\\[\]\00
0-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x8
0-\xff\n\015\[\]]|\\[^\x80-\xff])*\]))*)*:(?:[\040\t]|\((?:[^\\\x80-\xff\n\
015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*)
?(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000
-\037\x80-\xff])|"(?:[^\\\x80-\xff\n\015"]|\\[^\x80-\xff])*")(?:(?:[\040\t]
|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[
^\x80-\xff])*\))*\))*\.(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xf
f]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\040)<>@,;:".\
\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|"(?:
[^\\\x80-\xff\n\015"]|\\[^\x80-\xff])*"))*(?:[\040\t]|\((?:[^\\\x80-\xff\n\
015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*@
(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n
\015()]|\\[^\x80-\xff])*\))*\))*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff
]+(?![^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\
]]|\\[^\x80-\xff])*\])(?:(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\
xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*\.(?:[\040\t]|\((?
:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80
-\xff])*\))*\))*(?:[^(\040)<>@,;:".\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@
,;:".\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\x80-\xff\n\015\[\]]|\\[^\x80-\xff
])*\]))*(?:[\040\t]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff]|\((?:[^\\\x8
0-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*>)(?:[\040\t]|\((?:[^\\\x80-\xff\n\
015()]|\\[^\x80-\xff]|\((?:[^\\\x80-\xff\n\015()]|\\[^\x80-\xff])*\))*\))*
EOSCARY

    if ($addr =~ /^${isok}$/o) { 
        $self->debug(3, "rfc822 succeeds on '$addr'") if $DEBUG; 
        $i_ok = 1;
    } else {
        $self->debug(0, "rfc822 failure on '$addr'") if $DEBUG; 
        $i_ok = 0;
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
    $self->debug(1, "htpasswd($user, $pass) with($htpw)") if $DEBUG;
    my @data = $self->copy($htpw, $htpw.'.bak', '0660'); # backitup
    my $i_ok = 1;
    if (($i_ok == 1) or (scalar(@data) >= 1)) {
		my $htpass = join('', grep(/\w+/, @data));
        $self->debug(2, "Existing htpasswd file: '$htpass'") if $DEBUG;
        if (($user =~ /^\w+$/) && ($pass =~ /\w+/)) {
            $self->debug(1, "HTP: working with user($user) and pass($pass)") if $DEBUG;
            if ($htpass =~ /^$user:(.+)$/m) {	# modify?
                my $found = $1;
                $self->debug(3, "found($found)") if $DEBUG;
                if ($found ne $pass) {
                    $htpass =~ s/^$user:(.+)$/$user:$pass/m;
                    $self->debug(1, "HTP: changing user($user) found($found) to pass($pass)") if $DEBUG;
                } else {
                    $self->debug(1, "Not changing user($user) or pass($pass) with found($found)") if $DEBUG;
                }
            } else {                        	# add!
                $htpass .= "$user:$pass\n";
                $self->debug(1, "HTP: adding new user($user) / pass($pass)") if $DEBUG;
            } 
            $htpass =~ s/^\s*$//mg; 
			$i_ok = $self->create($htpw, $htpass, '0660'); # file
            $self->debug(3, "Modified($i_ok) htpasswd file: '$htpass'") if $DEBUG;
        } else {
			$i_ok = 0;
            my $err = "Can't open htpasswd file($htpw)! $!";
            $self->error($err);
    	}
    } else {
        $self->error("copy($htpw, $htpw.'.bak') must have failed?");
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
    $self->debug(3, "clean_up($max)") if $DEBUG;
	my $found = 0;
    my $cleaned = 0;

	$self->tell_time() if $DEBUG;

	my $o_range = $self->object('range');
	my @defunct = $o_range->ids("TO_DAYS(modified) < (TO_DAYS(SYSDATE()) -10)");
	$self->debug(2, "deletable ranges(@defunct)") if $DEBUG;
	# $o_range->delete(\@defunct);
	# $o_range->relation('bug')->delete(\@defunct);
	if ($max =~ /^\d+/) {
		foreach my $DIR (qw(logs temp)) { # 
			my $dir = $self->directory('spool')."/$DIR";
			$self->debug(4, "cleaning($dir)") if $DEBUG;
        	if (-d $dir) {
	    		my ($remcnt, $norem) = (0, 0); 
	    		opendir DIR, $dir or $self->error("Can't open dir ($dir) for clean up $!");
	    		my @files = grep(/\w+\.\w+$/, readdir DIR);
	    		$found += scalar(@files);
				$self->debug(4, 'Found: '.scalar(@files).' files') if $DEBUG;
	    		close DIR;
	    		foreach my $file (@files) {
	        		next unless -f "$dir/$file";
	        		my $FILE = "$dir/$file";
	        		if (-M $FILE >= $max) { # remove file if old 
	            		if (!unlink($FILE)) {
	                		$self->error("Unable to remove file '$FILE' $!");
	                		$norem++;
	            		} else {
	                		$self->debug(4, "Removed ($FILE)") if $DEBUG;
	                		$remcnt++;
	            		}
	        		} else {
	            		$self->debug(4, "Ignoring recent file '$FILE'") if $DEBUG;
	        		}
	    		}
            	$self->debug(4, "Process ($$): dir($dir) fertig: rem($remcnt), norem($norem) of ".@files) if $DEBUG;
            	$cleaned += $remcnt;
        	} else {
            	$self->error("Can't find directory: '$dir'");
        	}   
		}
    }
    $self->debug(2, "Cleaned up: age($max) -> files($cleaned) of($found)") if $DEBUG;
	# 
}


=item tell_time

Put runtime info in log file

	my $o_base = $o_base->tell_time(Benchmark->new);

=cut

sub tell_time {
	my $self = shift;
	my $now  = shift || Benchmark->new;

	$CACHE_TIME{'DONE'} = $now;

	my $start = $CACHE_TIME{'INIT'};
	my $prep  = $CACHE_TIME{'PREP'};
	my $load  = $CACHE_TIME{'LOAD'};
	my $done  = $CACHE_TIME{'DONE'};
	my $x = qq|start($start), prep($prep), load($load), done($done)|;

	my $started = timediff($prep, $start);
	my $loaded  = timediff($load, $prep);
	my $runtime = timediff($done, $load);
	my $total   = timediff($done, $start);

	my $feedback = qq|$0
	$x
	Startup: @{[timestr($started)]}
	Loaded : @{[timestr($loaded)]}
	Runtime: @{[timestr($runtime)]}
	Alltook: @{[timestr($total)]}
	         including $Perlbug::Database::SQL SQL statements 
	|;

	$self->debug(0, $feedback) if $DEBUG;
	return $self;
} 


=item parse_str

Returns hash of data extracted from given string:

	my %cmds = $o_obj->parse_str('5.0.5_444_aix_irix_<bugid>_etc' | (qw(patchid bugid etc));

%cmds = (
	'bugids'	=> \@bugids,
	'change'	=> [qw(444)],
	'osname'	=> [qw(aix irix)],
	'version'	=> [qw(5.0.0.5)],
	'unknown'	=> [qw(etc)],
);

=cut

sub parse_str {
	my $self = shift;
	my $args = shift;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : ($args);
	@args = map { split(/(\s|_)+/, $_) } @args;

	my %cmds = (
		'bugids'   => [],
		'unknown'  => [],
	);
	my $i_ok = 1;
	
	my @flags = $self->things('flag');
	my @names = map { $self->object($_)->col('name') } @flags;

	my $o_bug = $self->object('bug');
	ARG:
	foreach my $arg (@args) {
		next ARG unless $arg =~ /\w+/;
		if ($o_bug->ok_ids([$arg])) {	# bugid
			push(@{$cmds{'bugids'}}, $arg);
			$self->debug(2, "found bugid($arg)") if $DEBUG;
		} elsif (grep(/^$arg/i, @names)) {				
			foreach my $type (@flags) {					# flag
				my $o_obj = $self->object($type);
				my @types = $o_obj->col('name');
				if (grep(/^$arg/i, @types)) {			# type 
					push(@{$cmds{$type}}, $arg);
					$self->debug(2, "found $type($arg)") if $DEBUG;
				}	
			}
		} else {										# unknown
			push(@{$cmds{'unknown'}}, $arg);
			$self->debug(2, "ignoring arg($arg) as non-recognised bugid, changeid or version number!") if $DEBUG;
		}
	}
	# print "in(@args), out-> ".Dumper(\%cmds);

	return %cmds;
}


$SIG{'INT'} = sub {
	carp "Perlbug interupted: bye bye!";
	exit(1);	
};


=item bugid_2_addresses

Return addresses based on context

	my @addrs = $o_email->bugid_2_addresses($bugid);

=cut

sub bugid_2_addresses {
    my $self  = shift;
    my $bid   = shift;
    my $context = shift || 'auto'; # or new|update...

    my $feedback = $self->feedback($context); # (active|admin|cc|maintainer|group|master|source)
    $self->debug(2, "generating bugid($bid) context($context) feedback($feedback)") if $DEBUG; 
    my @addrs = ();
    my $o_bug = $self->object('bug')->read($bid);

	if ($o_bug->READ) {
		my $o_grp = $self->object('group');
		my $o_usr = $self->object('user');

		if ($bid !~ /\w+/) {
			$self->debug(1, "require bugid($bid)") if $DEBUG;
		} else {
			if ($feedback =~ /active/) {
				my @active = $o_usr->col('address', "active='1'");
				push(@addrs, @active);
			}
			if ($feedback =~ /admin/) {
				my @uids = $o_bug->rel_ids('user');
				if (@uids) {
					my @admins = map { $o_usr->read($_)->data('address') } @uids;
					push(@addrs, @admins);
				}	
			}
			if ($feedback =~ /maintainer/) {
				push(@addrs, $self->system('maintainer'));
			}
			if ($feedback =~ /cc/) {
				my @ccs = $o_bug->rel_ids('address');
				push(@addrs, @ccs);
			}
			if ($feedback =~ /group/) {
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
			if ($feedback =~ /sourceaddr/) {
				my ($srcaddr) = $o_bug->sourceaddr;	
				push(@addrs, $srcaddr);
			}
		}
    }


    return @addrs;
}


=item dump

Wraps Dumper() and dumps given args

	print $o_base->dump($h_data);

=cut

sub dump {
	my $self = shift;
	my @args = @_;
	my $res  = "rjsf dump: \n";

	foreach my $arg (@args) {
		$res .= "\targ($arg): ".Dumper(\$arg);
	}
	$res .= "\n";

	return $res;
}


=item html_dump

Encodes and dumps given args

	print $o_base->html_dump($h_data);

=cut

sub html_dump {
	my $self = shift;
	my @args = @_;
	my $res  = '<table><tr><td>rjsf html_dump: </td></tr>';

	foreach my $arg (@args) {
		$res .= qq|<tr><td><pre>|.encode_entities(Dumper($arg)).qq|&nbsp;</pre></td></tr>|;	
	}
	$res .= '</table>';

	return $res;
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

sub AUTOLOAD { # redirect
	my $self = shift;

	my $meth = $AutoLoader::AUTOLOAD = $AUTOLOAD;

    return if $meth =~ /::DESTROY$/i; 
    $meth =~ s/^(.*):://;
	
	$o_CONF = ref($o_CONF) ? $o_CONF : Perlbug::Config->new();
	return $o_CONF->$meth(@_);
}


=item DESTROY

Clean up

=cut

sub DESTROY {
	my $self = shift;

	$self->debug(0, "Perlbug($$) dropping out($0)") if $DEBUG;

	%CACHE_OBJECT = ();
	%CACHE_SQL    = ();
	%CACHE_TIME   = ();
	$o_CONF = '';
	$o_DB   = '';
	$o_LOG  = '';
	$i_LOG  = 0;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 1999 2000 2001

=cut

# 
1;
