# Perlbug base class 
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Base.pm,v 1.37 2000/08/10 10:44:30 perlbug Exp perlbug $
# 

=head1 NAME

Perlbug::Base - Module for bringing together Config, Log, Format, Do, TM, Mysql etc.

=cut

package Perlbug::Base;
use File::Spec; 
use lib (File::Spec->updir);
use Perlbug;
use Perlbug::Config;
use Data::Dumper;
use Mail::Header;
use Perlbug::Do;
use Perlbug::Log;
use Perlbug::Format;
use Perlbug::TM;
use Mail::Address;
use Carp;
use CGI;
use FileHandle;
use Mysql;
@ISA = qw(Perlbug::Config Perlbug::Log Perlbug::TM Perlbug::Do Perlbug::Format); # Log!
use strict;
use vars qw($AUTOLOAD $VERSION);
$| = 1; 

$VERSION = 1.37;

eval { alarm(($0 =~ /.+?bugdb$/) ? 1200 : 124) }; 
$SIG{'ALRM'} = sub { 
    my $alert = "Perlbug ($$) timing out: (124) $0 (@_)!";
    print "$alert<br>\n";
	carp($alert);
    kill('HUP', -$$);
    croak($alert);
};


=head1 DESCRIPTION

Methods for perlbug database access, all_flags, check_user, get_list, get_data, clean_up, etc.


=head1 SYNOPSIS

	my $o_base = Perlbug::Base->new;
	
	my %user = $o_base->user_data('richard');
	
	print "User is: ".$user{'username'};	


=head1 METHODS

=over 4

=item new

Create new Perlbug object, (see also L<Description> above):

	my $pb = Perlbug->new();

=cut

sub new { 
    my $proto = shift;
    my $class = ref($proto) || $proto; 
    my $self  = Perlbug::Config->new(@_);
	bless($self, $class);
    # setup the log, results and ranges dir/files...
    my $log = $self->directory('spool').'/logs/'    . $self->current('log_file'); 
    my $res = $self->directory('spool').'/results/' . $self->current('res_file'); 
    my $rng = $self->directory('spool').'/ranges/'  . $self->current('rng_file'); 
    my $hst = $self->directory('perlbug'.'/.bugdb');
	my $tmp = $self->directory('spool').'/temp/'    . $self->current('tmp_file');
	$self->{'o_log'} = Perlbug::Log->new(
		'log_file' => $log, 
		'res_file' => $res, 
		'rng_file' => $rng, 
		'hst_file' => $hst,
		'tmp_file' => $tmp,
		'debug'    => $self->current('debug'),
		'user'     => $self->system('user'),
    );
    $self->{'flags'}    = {};  # cache
    $self->{'users'}    = {};  # cache
	$self->{'_line_break'}  = "\n";
	$self->{'_pre'}			= '';
	$self->{'_post'}		= '';
	$self->{'CGI'} = CGI->new('nodebug') unless defined $self->{'CGI'};
    my $version = $Perlbug::VERSION;
    my $enabler = $self->system('enabled');
    if ($enabler) {     # OK 
        # Perlbug::Base::debug($self, 0, "INIT ($$) call debug(".$self->current('debug').") $self, enabled($version), scr($0): (UID($<, $>), GID($(, $)))");
		Perlbug::Base::result($self, '');
    } else {            # not OK
        &fatal($self, "Enabler($enabler) disabled($version) - not OK ($$ - $0) - cutting out!");
    }
    return $self;
}

sub version {
    return $Perlbug::VERSION;
}


sub isatest { 
	my $self = shift;
	$self->debug('IN', @_);
	my $arg = shift;
	if (defined($arg) and $arg =~ /\w+/) {
		$self->current('isatest', 1);
		$self->debug(1, "setting isatest($arg)");
	}
	$self->debug('OUT', $self->current('isatest'));
	return $self->current('isatest');
}

=item url

Store and return the given url.

=cut

sub url { # should be redundant (just a bit shorter to type :)
    my $self = shift;
    my ($url) = shift;
    if (defined($url)) { # may be blank
        $self->current('url', $url);
    }
    return $self->current('url');
}

sub qm {
    my $self = shift;
	# return $self->SUPER::qm($_[0]);
    return Perlbug::TM::qm($_[0]);
}

sub quote {
	my $self = shift;
	my $dbh = $self->DBConnect;
	return $dbh->quote($_[0]);
}


=item do

Wrap a Perlbug::Do command

    my $i_ok = $pb->do('b', 'bugid');

=cut

sub do { 
    my $self = shift;
    my $arg = shift;
    $self->debug('IN', @_);
	my $user = $self->isadmin;
	my @switches = $self->get_switches;
    my @res = ();
	if ($arg =~ /^[a-z]$/i and grep($arg, @switches)) {
		my @args = (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;
	    $self->debug(1, "Allowing user($user) to Do::do$arg(@args)");
		my $this = "do$arg";
    	@res = $self->$this(@_);
	} else {
		$self->debug(0, "User($user) not allowed to do $arg(@_) with switches(@switches)");
	}
	$self->debug('OUT', scalar(@res));
	return @res;
}


=item debug

Wrap o_log->debug calls

=cut

sub debug {
    my $self = shift;
	my @caller = caller;
	$self->{'o_log'}{'caller'} = join(', ', @caller);
    return $self->{'o_log'}->debug(@_);
}

=item dodgy_addresses

Returns quoted, OR-d dodgy addresses prepared for a pattern match ...|...|...

	my $regex = $o_obj->dodgy_addresses('from'); # $rex = 'perlbug\@perl\.com|perl5\-porters\@perl\.org|...'

=cut

sub dodgy_addresses { # context sensitive (in|out|to|from)
    my $self  = shift;
	$self->debug('IN', @_);
    my $scope = shift; # (from|to|cc|test...
	my $i_ok  = 1;
	my @duff  = (qw(MAILER-DAEMON postmaster)); 
	if ($scope =~ /^(from|sender)$/i) {					# FROM - don't accept mails from here
		push(@duff, $self->get_vals('target'), $self->get_vals('forward'), 
				    $self->email('bugdb'),      $self->email('bugtron'));
	} elsif ($scope =~ /^(to|cc|reply-to)$/i) {			# TO   - don't send mails in this direction
		push(@duff, $self->get_vals('target'), 
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
	$self->debug(3, "dodgy_addresses($scope) -> '$dodgy'");
	$self->debug('OUT', $dodgy);
	return $dodgy; # regex 
}

=item link

Wrap o_log->link calls

=cut

sub link {
    my $self = shift;
    return $self->{'o_log'}->link(@_);
}

=item AUTOLOAD

Wrapper for debug functions, translates this:
	
	$o_obj->debug3($data); # to  

	$o_obj->{'o_log'}->debug(3, $data); # this

=cut

sub _AUTOLOAD {
    my $self = shift;
    my $meth = $AUTOLOAD;
	$AutoLoader::AUTOLOAD = $AUTOLOAD;
    return if $meth =~ /::DESTROY$/; 
	$meth =~ s/^(.*):://;
    my $level = 1;
	if ($meth =~ /debug(\.)/) { # one of ours :-)
        $level = $1;
		print "Perlbug::Base->$meth(@_) called debug level($level) as ($AUTOLOAD)\n";
	} else {
		$self->SUPER::AUTOLOAD(@_); 
	}
	return $self->{'o_log'}->debug($level, @_);
}


=item dump

Wrap Data::Dumper catering for www also.

=cut

sub dump {
	my $self = shift;
	my $item = shift;
	my $fmt  = shift || $self->current('format') || 'a';
	my $ITEM = Dumper($item);
	my @caller = caller(1);
	if ($fmt =~ /h/i) {
		$ITEM = "<pre>$caller[0] $caller[1] -> $ITEM</pre>\n";
	}
	return $ITEM;
}


=item can_update

Check if current user is allowed to update given item/s.

    print 'yes' if $o_perlbug->can_update([$user||$bid||$mid||$bid|$pid]);

=cut

sub can_update {
    my $self = shift;
    my $atem = shift;
	my $scope= shift || 'm'; # message, patch, test
    my $user = $self->isadmin;
    my $i_ok = 0;
    my @atem = (ref($atem) eq 'ARRAY') ? @{$atem} : ($atem);
    if (scalar(@atem) >= 1) {
    	ITEM:
        foreach my $item (@atem) { # perlbug_test_653
            # last ITEM unless $i_ok == 1;
            if ($item =~ /^([_\w]+)$/i) {           # userid
                $i_ok = 1 if (($user eq $item) || ($user eq $self->system('bugmaster')) or $self->local_conditions($1, $user));
                $self->debug(3, "userid($item)->($i_ok)");
            } elsif ($item =~ /^(\d{8}\.\d{3})$/) { # bug id
                $i_ok = 1 if $self->admin_of_bug($1, $user) or $self->isadmin or $self->local_conditions($1, $user);
                $self->debug(3, "bugid($item)->($i_ok)");
            } elsif ($item =~ /^(\d+)$/) {          # messageID or testID or patchID
                my %map = (
					'm' => 'tm_messages',
					'p' => 'tm_patches',
					't' => 'tm_tests',
				);
				my ($bugid) = $self->get_list("SELECT ticketid FROM tm_messages WHERE messageid = '$1'");
                $i_ok = 1 if $self->admin_of_bug($bugid, $user) or $self->isadmin or $self->local_conditions($1, $user);
                $self->debug(3, "messageid($item)->($i_ok)");
            } else {                                # unknown type
                # $i_ok = 0;
                # $self->debug(0, "unrecognised item($item) from user($user)");
            }
        }
    } else {
        $i_ok = 0;
        $self->debug(0, "requires something (@atem) to check");
    }
    $self->debug(0, "user($user) can_update(@atem) -> isok?($i_ok)");
    return $i_ok;
}

sub local_conditions {
	return 0;
}

=item fatal

Wrap o_log->fatal calls

=cut

sub fatal {
    my $self = shift;
    my @caller = caller(1);
    return $self->{'o_log'}->fatal(@_, @caller);
}


=item start

=cut

sub start {
    my $self = shift;
    return Perlbug::Format::start($self, @_);    
}


=item finish

=cut

sub finish {
    my $self = shift;
    return Perlbug::Format::finish($self, @_);     
}


# YUK: all these format calls should be remapped properly!

=item format

Wrap o_format->format calls

=cut

sub format {
    my $self = shift;
    my $args = shift;
    return Perlbug::Format::fmt($self, $args, $self->current('format'));
}


=item format_overview

Wrap o_format->overview calls

=cut

sub format_overview {
    my $self = shift;
    my $args = shift;
    return $self->SUPER::overview($args, $self->current('format'));
}


=item format_schema

Wrap o_format->schema calls

=cut

sub format_schema {
    my $self = shift;
    my $args = shift;
    return $self->schema($args, 'a'); # hardwire ascii formatting
}


=item copy

Wrap Log::copy

=cut

sub copy {
	my $self = shift;
	return $self->{'o_log'}->copy(@_);
}


=item flags

Returns array of options for given type.

    my @list = $pb->flags('category');

=cut

sub flags {
    my $self = shift;
    my $arg  = shift;
    # $self->debug(3, "flags called with($arg)");
	my @caller = caller(1);
	# $self->debug(3, "flags: arg($arg) from caller(@caller)");
    my @flags = ();
    if ( (defined($arg)) && ($arg =~ /^(\w+)$/) ) {
        if ((defined($self->{'flags'}{$arg})) && ($self->{'flags'}{$arg}[0] =~ /\w+/)) {
            # use existing values
            @flags = @{$self->{'flags'}{$arg}};
            # $self->debug(3, "Reusing data for $arg flags");
        } else {
            # get new values
            @flags = $self->get_list("SELECT flag FROM tm_flags WHERE type = '$arg'");
            # store them for later
            $self->{'flags'}{$arg} = \@flags;
            # $self->debug(2, "New data for flag '$arg': @flags");
        }
    } else {
        $self->fatal("Can't get flags for invalid arg($arg)");
    }
	# $self->debug(2, "Returning flags: @flags");
    return @flags;
}


=item all_flags

Return all flags available in db keyed by type.

    my %flags = $pb->all_flags;

	%flags = ( # now looks like this:
		'category'	=> ['core', 'docs', 'install'], 	# ...
		'status'	=> ['open', 'onhold', 'onhold'], 	# ...
		# ...
	);

=cut

sub all_flags {
    my $self  = shift;
    my %flags = ();
    my @types = ();
    if (defined($self->{'flag_types'}) && ref($self->{'flag_types'}) eq 'ARRAY') {
        @types = @{$self->{'flag_types'}};
    } else {
        @types = $self->get_list("SELECT DISTINCT type FROM tm_flags");
        $self->{'flag_types'} = \@types;
    }
	foreach my $flag (@types) {
		my @flags = $self->flags($flag);
		$flags{$flag} = \@flags;        
    }
    return %flags;
}


=item date_hash

=cut

sub date_hash {
    my $self = shift;
    my %dates = (
	    'any'               => '',
	    'today'             => ' TO_DAYS(NOW()) - TO_DAYS(created) <= 1  ',
	    'this week'         => ' TO_DAYS(NOW()) - TO_DAYS(created) <= 7  ',
	    'less than 1 month' => ' TO_DAYS(NOW()) - TO_DAYS(created) <= 30 ',
	    'less than 3 months'=> ' TO_DAYS(NOW()) - TO_DAYS(created) <= 90 ',
	    'over 3 months'     => ' TO_DAYS(NOW()) - TO_DAYS(created) >= 90 ',
	);
    return %dates;
}


=item active_admins

Returns active admins from db.

    my @active = $pb->active_admins;

=cut

sub active_admins {
    my $self = shift;
    my @active = $self->get_list("SELECT DISTINCT userid FROM tm_users WHERE active = '1'");
    return @active;
}

=item active_admin_addresses

Returns active admin addresses from db.

    my @addrs = $pb->active_admin_addresses;

=cut

sub active_admin_addresses {
    my $self = shift;
	my $active = join("', '", $self->active_admins);
    my @active = $self->get_list("SELECT DISTINCT address FROM tm_users WHERE userid IN ('$active')");
    return @active;
}


=item user_data

Return (cached) data on given user

    my %data = $pb->user_data('richard');

=cut

sub user_data {
    my $self = shift;
    my $user = shift;
    my $h_cache = {};
    if ((defined($self->{'users'}{$user})) && 
            (ref($self->{'users'}{$user}) eq 'HASH') &&
                ($self->{'users'}{$user}{'name'} =~ /\w+/)
        ) { # ok, give up and use it.
        $self->debug(3, "Reusing cached data for '$user'");
		$h_cache = $self->{'users'}{$user};
    } else {
        $h_cache = $self->user_get($user); # TM
        if (ref($h_cache) eq 'HASH') {
            if ($$h_cache{'name'} =~ /\w+/) {
                # store it for later
                $self->{'users'}{$user} = $h_cache;
				my ($tkts) = $self->get_list("SELECT count('ticketid') FROM tm_claimants WHERE userid = '$user'"); 
				$$h_cache{'bugs'} = $tkts;
                $self->debug(3, "New data for user: '$user': $h_cache");
            } else {
                # looks like duff data
                $self->debug(0, "Can't get any data for '$user' from '$h_cache'");
            }
        } else {
            $self->debug(0, "Duff data for '$user'");
        }
    }
	
    return $h_cache; # return whatever we got
}


=item help

Returns help message for perlbug database.

	my $help = $pb->help;

=cut

sub help {
    my $self = shift;
    $self->debug('IN', '');
	my $url = $self->web('hard_wired_url');
	my $help = qq|A searchable live reference database of email-initiated bugs and patches.|;	
	# Or request information: spec\@bugs.perl.org

	$self->debug('OUT', $help);
    return $help;
}


sub theflags { # should be in db
	my $self = shift;
    $self->debug('IN', '');
	my $info = q|
A brief explanation of the usually available flags follows:

Status:
	abandoned	
	closed	
	ok			
	onhold	
	open	
	
Category:	
	bounce		
	core 		
	docs		
	install		
	library		
	notabug		
	patch		
	unknown	
	utilities	
	
Osname:
	generic
	macos
	unix
	win32
	etc...

Severity:
	critical
	fatal
	high
	low
	medium
	none
	wishlist
	zero

	|;
    $self->debug('OUT', length($info));
	return $info;
}

=item spec

Returns spec message for perlbug database.

	my $spec = $pb->spec();

=cut

sub spec {
    my $self = shift;
    $self->debug('IN', '');
	my $data = '';
	my %flags = $self->all_flags;
	foreach my $key (keys %flags) {
	    my $vals = join(', ', $self->flags($key));
	    $data .= sprintf('%-15s', ucfirst($key).':')."$vals\n";
	}
	my $ehelp= $self->email('help');
	my $bids = my @bids = $self->get_list("SELECT ticketid FROM tm_tickets");
	my $open = my @open = $self->get_list("SELECT ticketid FROM tm_tickets WHERE status = 'open'");
	my $admins = my @admins = $self->get_list("SELECT userid FROM tm_users WHERE active = '1'");
	my ($bugdb, $cgi, $title) = ($self->email('bugdb'), $self->web('hard_wired_url'), $self->system('title'));
    # my @targets = $self->get_list("SELECT DISTINCT flag FROM tm_flags WHERE type = 'osname' AND flag != 'unix'");
	my @targets = $self->get_keys('target');
	$data .= qq|
Mail sent to the following targets will register a new bug in the database and 
forward it onto the appropriate mailing list:

|;
	foreach my $tgt (@targets) { # 
		next unless $tgt =~ /\w+/;
        my $first  = sprintf('%-15s', ucfirst($tgt).':'); 
        my @notify = split(/\s+/, $self->target($tgt));
		my $notify = join(' or ', @notify);
        my $reply  = $self->forward($tgt);
        $data .= qq|${first} ${notify} -> ($reply)\n|;
    }
	$data .= "\n";
	my $info = qq|
The $title bug tracking system: $bids bugs ($open open) with the following categories:
		
$data
Anyone may search the database via the web:

	$cgi
		
or the email interface:
		
	To: $ehelp
	
Several additional mail commands are available, send an email with an address, 
(subject line is ignored), of the following form:
		
Propose changes to the status of a bug:

	To: propose_close_bugid_install\@bugs.perl.org
	
Register to be an administrator, (currently we have $admins active admins):

	To: register_MYUSERID\@bugs.perl.org
			
Forward the body of this email to all active administrators:
		
	To: admins\@bugs.perl.org
	

Features:
	Written in perl
	Robust, with test suites:
      	All tests successful.
		Files=28, Tests=162, 148 wallclock secs (59.27 cusr +  2.61 csys = 61.88 CPU) 
	Documented (in perldoc -> do what I say _and_ what I do :)
	Downloadable open source and data.
	All under RCS -> current v$Perlbug::VERSION.
	Integrated with perlbug (configurable via Matches file).
	It has a simple (single config file) installation (other people can use it).
	Site configurable email newbug recognition and forwarding.
	Site configurable scanning of email bodies -> categorisation of reports.
	Standard installation*: make; make test; make install.
	Multiple interfaces (take your pick):
        Web             -> search, browse and destroy interface
        Tron            -> target and mailing list slurper/forwarder
        Email 1         -> subject: oriented search, report and admin   
        Email 2         -> to: oriented report and admin
        Command line    -> for local db (similar to email)
	5+ different formatting types for all discrete objects are supported across
	all outputs for both public and administrative interfaces for:
        	bugs, messages, patches, notes, tests, users
	Differential user/admin help/spec for all formats.
	Several utility scripts:
        cron.cmd        -> regular backup, notification and cleanup jobs
        fixit           -> fix issues with database inconsistencies, or ever changing
	requirements...
        hist.cmd        -> slurp data into db from archives
	Accepts target mail addresses (and thereby sets category etc) and forwards to
		appropriate mailing list/s.
	Watches various mailing list for replies to existing bugs to slurp,
		checking subject and reply-to, etc.
	Defense mechanisms against loops, spam, and other entertaining factors.
	Ignores previously seen message-ids, non-relevant mail.
	Test targets to email interfaces (dumps header -> originator)
	Email interface handles any of the following To lines:
        close_<bugid>_\@bugs.perl.org                     -> bug admin 
        busy_win32_install_fatal_<bugid>\@bugs.perl.org   -> admin
        propose_close_<bugid>_\@bugs.perl.org             -> bug admin proposal
        note_<bugid>_\@bugs.perl.org                      -> assign note
        patch_<version>_<bugid>_<changeid>\@bugs.perl.org -> assign a patch
        register_me\@bugs.perl.org                        -> admin registration request
        admins\@bugs.perl.org                             -> admin mail forward
        help\@bugs.perl.org                               -> :-)
	Or the following (not very cryptic) Subject lines:
        -h                      
        -b <bugid>+
        -c category search
		-s subject_search
        -r retrieval by original message body search criteria
        -q select * from tm_tickets
        -H -d2 -l -A close <bugid>+ lib -c patch -e some\@one.net 
        -c pa cl wi -m77 812 1 21 -b 33 -B 34 35 -o -l -d2 -a clo inst <bugid>+ -fA
        etc...
	Auto database dump, email of overview and bugid->admin assignation
	Patches can be emailed in -> auto close of bug
	Notes can be assigned from any interface to any bug
	Non-admin emails -> converted to proposals -> mailed to active
		administrators/bugmongers
	Cc: list (and admins) are optionally auto-notified of any status 
		changes to bugs 
	Relationships between bugs (parent-child) are assignable.
	Retrieval of databank via email.
	Logging of all activities, admin history tracking.
	Graphical display of overview (admins, categories, severity, osname, status).
|;
	$self->debug('OUT', $info);
    return $info;
}


=item flow

Details how the mail / web mechanism flows

=cut

sub flow {
	my $self = shift;
	$self->debug('IN', '');
	my $flow = qq|
We have bugs, messages(related to bugs), tests(against bugs), patches(against bugs and software versions), 
admins(who categorise and deal with bugs) and users(who can browse the database).

This describes the interaction between the different parts of the system:

BUGS
A bug is created by sending an email to one of the target addresses.

The mail is intered into the database, and is forwarded with a bugid onto the appropriate mailing list.

Bugs may be related to one another, where repeated, or the chain of events has been interrupted.

MESSAGES
The mailing lists are then tracked for replies to this bug, when found these are also put into the database, and assigned the appropriate bugid.

ADMINS
Registered admins are the only people permitted to alter the status of a bug.

Anyone may search the system for bugs using one of several interfaces.
Anyone may propose bug changes by emailing the administrators.

If a close_<bugid>@* mail is recieved from an admin, the contents will go as a comment against the bug.

NOTES
Admins may assign one or more comments to a bug to indicate why the status has changed.

PATCHES
Anyone may throw a patch at the system, though a non-admin mail will be forwarded to active administrators (as per proposals - above).

An accepted patch will close related bugids (if there are any), pick up the changeID and be entered in the database as a discrete object.  Patches may be assigned to more than one bug - bugs may be assigned to more than one patch.  

In this case a comment will not be entered into the db, the presence of the patch is expected to be evidence of the bug's demise.

CHANGE IDs
When a patch is recieved, it is expected to have a changeID (from the Changes... file/s), and one or more bugids.  Neither of these are mandatory - read: nice to have :-)

	CC_LIST
	
	LOG
|;
	$self->debug('OUT', $flow);
	return $flow;
}


=item administration_failure

Deal with a failed administration attempt

	my $i_ok = $self->administration_failure($bid, $user, $commands);

=cut

sub administration_failure {
	my $self = shift;
	$self->debug('IN', @_);
	my $bid  = shift;
	my $cmds = shift;
	my $user = shift || $self->isadmin;
	my $reason = shift || '';
	my $i_ok = 1;
	$self->debug(0, "XXX: bugid($bid) update($cmds) FAILED for user($user) -> $reason!");
	$self->debug('OUT', $i_ok);
	return $i_ok;
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
	$self->debug(2, "check_user($user)");
    if ($self->system('restricted')) {
        my $sql = "SELECT userid FROM tm_users WHERE userid = '$user' AND active IS NOT NULL";
	    my @ids = grep(!/generic/i, $self->get_list($sql));
	    ID:
	    foreach my $id (@ids) {
	        if (($id =~ /^\w+$/) && ($id =~ /$user/)) {
		    $self->current('admin', $id);
	            $self->current('switches', $self->system('user_switches').$self->system('admin_switches'));
	            $self->debug(2, "given param ($user) taken as admin id ($id), switches set: ".$self->current('switches'));
	            last ID;
	        }
        }
	} else {
        $self->current('admin', $user);
        $self->current('switches', $self->system('user_switches').$self->system('admin_switches'));
	    $self->debug(2, "Non-restricted user($user) taken as admin id, switches set: ".$self->current('switches'));
	}
	return $self->isadmin;
}


=item isadmin

Stores and returns current admin userid (post check_user), checks whether system is restricted or not.

	next unless $pb->isadmin;

=cut

sub isadmin { #store and retrieve admin flag (and id)
    my $self = shift;
    my $prop = shift;
    my ($user) = ($self->system('restricted')) ? grep(!/generic/i, $self->current('admin')) : $self->current('admin');
    return $user;
}


=item status

Returns 'A' or 'U' depending on whether user is an admin or a 'mere' user.

	my $thing = ($self->status eq 'A') ? 'key' : 'lock';

=cut

sub status {
    my $self = shift;
    return $self->current('admin') ? 'A' : 'U';
}


=item ok

Checks bugid is in valid format (looks like a bugid) (uses get_id):

	&do_this($id) if $pb->ok($id);

=cut

sub ok { 
    my $self = shift;
    my $given = shift;
    my ($ok, $bid) = $self->get_id($given); 
    return $ok;
}


=item get_id

Determine if the string contains a valid bug ID

=cut

sub get_id {
    my $self = shift;
    my $str = shift;
    my ($ok, $id) = $self->SUPER::get_id($str); 
    return ($ok, $id);
}


=item _switches

Stores and returns ref to list of switches given by calling script.
Only these will be parsed within the command hash in L<process_commands>.

	my $switches = $pb->_switches(qw(e t T s S h l)); #sample

=cut

sub _switches { 
    my $self = shift;
    if (@_) { 
        my $switches = join(' ', grep(/^a-z$/i, @_)); 
        $self->debug(1, "Setting allowed, and order of, switches ($switches)");
        $self->current('switches', $switches);
    }
    return $self->current('switches');
}


=item result 

Storage area (file) for results from queries, returns the FH.

	my $res = $pb->result('store this stuff'); #store

=cut

sub result { 
    my $self = shift;
	return $self->{'o_log'}->append('res', $_[0].$self->line_break);
}


=item fh

Wrapper for Log fh

=cut

sub fh {
	my $self = shift;
    return $self->{'o_log'}->fh($_[0], $_[1]);
}


=item set_site

Set the site directory for text files, headers, todos etc.

=cut

sub set_site {
	my $self = shift;
	my $tgt  = shift;
	if ($tgt !~ /^\w+$/) {
		$self->debug(0, "set_site($tgt) requires a plain target");
	}
	my $target = $self->directory('site')."/$tgt".$self->file_ext;
	if (-e $target && -f _) { 	# OK - site spec
		$self->{'o_log'}->{$tgt.'_file'} = $target;
		$self->debug(0, "target($tgt) set to '$target'");
	} else {					# give up
		croak("Can't locate target($tgt) file($target) - check directory contents?");
	}
}

sub file_ext { return ''; }

=item read

=cut

sub read {
    my $self = shift;
	my $tgt  = shift;
	if (!defined($self->{'o_log'}->{$tgt.'_file'})) { # !~ /\w+/) {
		$self->set_site($tgt);
	}  
	return join('', @{ $self->{'o_log'}->read($tgt) });  
}

=item append

Wrapper for Log append

=cut

sub append {
	my $self = shift;
	if ($self->{'o_log'}->{$_[0].'_file'} !~ /\w+/) {
		$self->set_site($_[0]);
	}  
    return $self->{'o_log'}->append($_[0], $_[1]);
}


=item get_results

Return the results of the queries from this session.

    my $a_data = $pb->get_results;

=cut

sub get_results {
    my $self = shift;
    return join('', @{ $self->{'o_log'}->read('res') });
}


=item get_list

Returns a simple list of items (column values?), from a sql query.

	my @list = $pb->get_data('SELECT ticketid FROM tm_tickets');

=cut


sub get_list {
	my $self = shift;
	$self->debug('IN', @_);
	my ($sql) = @_; 
	my @info = ();
	if ($sql) {
		my $csr = $self->query($sql);
		if (defined($csr)) {
	    	while ( (my $info) = $csr->fetchrow) { #? fetchrow.$ref(_hashref)
		    	push (@info, $info) if defined $info;
	    	}
    		$self->debug(3, 'get_list found '.$csr->num_rows.' rows');
	    	my $res = $csr->finish;
		} else {
	    	$self->debug(0, "undefined cursor for get_list(): $Mysql::db_errstr");
		}
	}
	$self->debug('OUT', scalar(@info));
	return @info;
}


=item get_data

Returns a list of hash references, from a sql query.

	my @hash_refs = $pb->get_data('SELECT * FROM tm_tickets');

=cut

sub get_data {
	my $self = shift;
	$self->debug('IN', @_);
	my ($sql) = @_;
	#? return $self->get_list($sql, '_hashref');
 	my @results = ();
 	if ($sql) {
		my $csr = $self->query($sql);
 		if (defined($csr)) {
    		while (my $info = $csr->fetchrow_hashref) {
    	    	if (ref($info) eq 'HASH') {
        			push @results, $info; 
            	}
    		}
    		$self->debug(3, 'get_data found '.$csr->num_rows.' rows');
    		my $res = $csr->finish
    	} else {
        	$self->debug(0, "undefined cursor: '$Mysql::db_errstr'");
    	}
	}
	$self->debug('OUT', scalar(@results));
	return @results; 
}    


=item exec

Returns statement handle from sql query.

	my $sth = $pb->exec("INSERT @data INTO table");

=cut

sub exec {
	my $self = shift;
	$self->debug('IN', @_);
	my ($sql) = @_; 
	$self->debug(1, "exec($sql)");
	return undef unless $sql;
	my $sth = $self->query($sql);
	if ($sth) {
	    my $rows = $sth->num_rows;
	    $self->debug(2, "Exec rows ($rows) affected.");
	} else {
	    $self->debug(0, "Exec ($sql) error: $Mysql::db_errstr");
	}
	$self->debug('OUT', $sth);
	return $sth;
}


=item exists

Does this bugid exist in the db?

=cut

sub exists {
	my $self = shift;
	$self->debug('IN', @_);
	my $bid = shift;
	my $i_ok = 0;
	if (!$self->ok($bid)) {
		$i_ok = 0;
		$self->debug(0, "bugid($bid) doesn't look good!");
	} else {
		($i_ok) = $self->get_list("SELECT ticketid FROM tm_tickets WHERE ticketid = '$bid'");
		$self->debug(2, "bugid($bid)? -> $i_ok($i_ok)");
	}
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item tm_parents_children

Assign to given bugid, given list of parent and child bugids

=cut

sub tm_parents_children {
	my $self = shift;
    $self->debug('IN', @_);
    $self->debug(0, "TPC: @_");
	my $bid = shift;
	my $a_p = shift;
	my $a_c = shift;
	my @cc = @_;
	my @ccs = ();
	my $i_ok = 1;
	if ($bid !~ /\d{8}\.\d{3}/) {
		$i_ok = 0;
		$self->debug(0, "requires bid($bid)");
	} else {
		my @parents = ();
		my @children = ();
		my @xp = @{$a_p} if ref($a_p) eq 'ARRAY';
		my @xc = @{$a_c} if ref($a_c) eq 'ARRAY';
		XP:
		foreach my $p (@xp) {
			next XP if grep(/^$p$/, @xc);
			push(@parents, $p); # otherwise
		}
		$self->debug(0, "TPC 1: p(@parents), c(@children)");
		XC:
		foreach my $c (@xc) {
			next XC if grep(/^$c$/, @xp);
			push(@children, $c); # otherwise
		}
		$self->debug(0, "TPC 2: p(@parents), c(@children)");
		PARENT:
		foreach my $p (@parents) {
			next PARENT unless $p =~ /\b\d{8}\.\d{3}\b/;
			next PARENT if $p eq $bid;
			next PARENT if grep(/^$p$/, @children);
			my ($ok) = $self->get_list("SELECT ticketid FROM tm_tickets WHERE ticketid = '$p'");
    		if ($ok) {
				my @pexists = $self->get_list("SELECT parentid FROM tm_parent_child WHERE parentid = '$p' and childid = '$bid'");
				my @cexists = $self->get_list("SELECT childid FROM tm_parent_child WHERE childid = '$p' and parentid = '$bid'");
				if (!@pexists and !@cexists) {
					my $insert = "INSERT INTO tm_parent_child values ('$p', '$bid')";
					my $sth = $self->exec($insert);
					$ok = $self->track('r', $bid, "attached parent($p)");
					$self->debug(0, "Inserted ($insert) previous(@pexists, @cexists)");
				}
			}
		}
		CHILD:
		foreach my $c (@children) {
			next CHILD unless $c =~ /\b\d{8}\.\d{3}\b/;
			next CHILD if $c eq $bid;
			next PARENT if grep(/^$c$/, @parents);
			my ($ok) = $self->get_list("SELECT ticketid FROM tm_tickets WHERE ticketid = '$c'");
    		$self->debug(0, "TPC 3: c($c) -> ok($ok)");
			if ($ok) {
				my @pexists = $self->get_list("SELECT parentid FROM tm_parent_child WHERE parentid = '$bid' and childid = '$c'");
				my @cexists = $self->get_list("SELECT childid FROM tm_parent_child WHERE childid = '$bid' and parentid = '$c'");
				if (!@pexists and !@cexists) { 
					my $insert = "INSERT INTO tm_parent_child values ('$bid', '$c')";
					my $sth = $self->exec($insert);
					$ok = $self->track('r', $bid, "attached child($c)");
					$self->debug(0, "Inserted ($insert) previous(@pexists, @cexists)");	
				}
			}
		}
	}
	$self->debug('OUT', $i_ok);
	return $i_ok; # \@parents, \@children
}

	
=item tm_cc

Assign to given bugid, given list of cc's, return current cc's

=cut

sub tm_cc {
	my $self = shift;
    $self->debug('IN', @_);
	my $bid = shift;
	my @cc = @_;
	my @ccs = ();
	my $i_ok = 1;
	my $get_cc = qq|SELECT DISTINCT address FROM tm_cc WHERE ticketid = '$bid'|;
	if (!$self->exists($bid)) {
		$i_ok = 0;
		$self->debug(2, "tm_cc requires a valid bugid($bid) for an update");
	} else {
		@ccs = $self->get_list($get_cc);
		my @o_ccs = Mail::Address->parse(@cc); # foreach @cc ?
		my @targets = map { split(/\s+/, $_) } ($self->get_vals('target'), $self->get_vals('forward'), $self->email('bugdb'), $self->email('bugtron'));
		CC:
		foreach my $o_cc (@o_ccs) {
			next CC unless ref($o_cc);
			my $cc = $o_cc->address;
			chomp($cc);
			next CC if grep(/^$cc$/i, @targets);
			next CC if grep(/^$cc$/i, @ccs);
			next CC unless $self->ck822($cc);
			my $insert = "INSERT INTO tm_cc values (NULL, '$bid', '$cc')";
			my $sth = $self->exec($insert);
			my $ok = $self->track('c', $bid, "assigned cc($cc)");
			$self->debug(0, "Assigned($bid) <- cc($cc)");	
		}
	}
	@ccs = $self->get_list($get_cc);
	
	$self->debug('OUT', $i_ok, @ccs);
	return ($i_ok, @ccs);
}



=item tm_patch_ticket

Assign to given bugid, given list of patchids, return valid, @pids

=cut

sub tm_patch_ticket {
	my $self = shift;
    $self->debug('IN', @_);
	my $bid = shift;
	my @patches = @_;
	my @pids = ();
	my $i_ok = 1;
	my $get_pids = qq|SELECT DISTINCT patchid FROM tm_patch_ticket WHERE ticketid = '$bid'|;
	if (!$self->exists($bid)) {
		$i_ok = 0;
		$self->debug(2, "tm_patch_ticket requires a valid bugid($bid) for an update");
	} else {
		my @current = $self->get_list($get_pids);
		my @exists = $self->get_list("SELECT patchid FROM tm_patches");
		PID:
		foreach my $pid (@patches) {
			next PID unless $pid =~ /^\d+$/;
			next PID unless grep(/^$pid$/, @exists);
			next PID if grep(/^$pid$/, @current);
			my $insert = "INSERT INTO tm_patch_ticket values (NULL, now(), '$pid', '$bid')";
			my $sth = $self->exec($insert);
			my $ok = $self->track('x', $bid, "assigned patchid($pid)");
			$self->debug(0, "Assigned($bid) <- patchid($pid)");	
		}
	}
	@pids = $self->get_list($get_pids);
	
	$self->debug('OUT', $i_ok, @pids);
	return ($i_ok, @pids);
}

=item tm_tests

Assign to given bugid, given list of testids, return valid, @tids

=cut

sub tm_tests {
	my $self = shift;
    $self->debug('IN', @_);
	my $bid = shift;
	my @tests = @_;
	my @tids = ();
	my $i_ok = 1;
	my $get_tids = qq|SELECT DISTINCT testid FROM tm_tests WHERE ticketid = '$bid'|;
	if (!$self->exists($bid)) {
		$i_ok = 0;
		$self->debug(2, "tm_tests requires a valid bugid($bid) for an update");
	} else {
		my @current = $self->get_list("SELECT DISTINCT testid FROM tm_test_ticket WHERE ticketid = '$bid'");
		my @exists = $self->get_list("SELECT testid FROM tm_tests");
		TID:
		foreach my $tid (@tests) {
			next TID unless $tid =~ /^\d+$/;
			next TID unless grep(/^$tid$/, @exists);
			next TID if grep(/^$tid$/, @current);
			my $insert = "INSERT INTO tm_test_ticket values (NULL, now(), '$tid', '$bid')";
			my $sth = $self->exec($insert);
			my $ok = $self->track('x', $bid, "assigned testid($tid)");
			$self->debug(0, "Assigned($bid) <- testid($tid)");	
			push(@current, $tid);
		}
	}
	@tids = $self->get_list($get_tids);
	
	$self->debug('OUT', $i_ok, @tids);
	return ($i_ok, @tids);
}

=item notify_cc

Notify tm_cc addresses of changes, current status of bug.

=cut

sub notify_cc {
	my $self  = shift;
    $self->debug('IN', @_);
	my $bid   = shift;
	my $cmds  = shift;
	my $i_ok  = 1;
	if (!($self->ok($bid) and $self->exists($bid))) {
		$i_ok = 0;
		$self->debug(0, "notify_cc requires a valid bugid($bid)");
	} else {
		my %p = $self->parse_str($cmds);
		my @unknown = (ref($p{'unknown'}) eq 'ARRAY') ? @{$p{'unknown'}} : ();
		my @versions = (ref($p{'versions'}) eq 'ARRAY') ? @{$p{'versions'}} : ();
		my $fmt = $self->current('format');
		my $bugdb = $self->email('bugdb');
		$self->context('a');
		my $url = $self->web('hard_wired_url')."?req=bid&bid=$bid\n";
		$self->{'o_log'}->setresult($self->directory('spool').'/temp/'.$self->current('tmp_file'));
		$self->dob([$bid]); # a bit less more data :-)
		my $status = qq|The status of bug($bid) has been updated:
		|;
		$status .= $self->get_results;
		$status .= qq|
To see all data on this bug($bid) send an email of the following form:

	To: $bugdb
	Subject: -B $bid

Or to see this data on the web, visit:

	$url

		|;
		$self->{'o_log'}->setresult;
		$self->context($fmt);

		my ($addr) = $self->get_list("SELECT sourceaddr FROM tm_tickets WHERE ticketid = '$bid'");
		my ($o_to) = Mail::Address->parse($addr);
		my ($to) = (ref($o_to)) ? $o_to->address : $self->system('maintainer');
		my ($i_cc, @ccs) = $self->tm_cc($bid);
		my @uids = $self->get_list("SELECT userid FROM tm_claimants WHERE ticketid = '$bid'");
		my $claimants = join("', '", @uids);
		my @claimants = $self->get_list("SELECT address FROM tm_users WHERE userid IN ('$claimants')");
		require Perlbug::Email; # yek
		my $o_email = Perlbug::Email->new;
		$o_email->_original_mail($o_email->_duff_mail); # dummy
		my $o_notify = $o_email->get_header;
		$o_notify->add('To', $to);
		$o_notify->add('Cc', join(', ', @ccs, @claimants)) unless grep(/nocc/i, @unknown, @versions);
		$o_notify->add('From', $self->email('bugdb'));
		$o_notify->add('Subject', $self->system('title')." $bid status update");
		$i_ok = $o_email->send_mail($o_notify, $status);
		$self->debug(0, "notified($i_ok) <- ($bid)");
	}
	$self->debug('OUT', $i_ok);
	return $i_ok
}


sub todo {
	my $self  = shift;
    $self->debug('IN', @_);
	my $todo  = shift;
	my $i_ok  = 1;
	if ($todo !~ /\w+/) {
		$i_ok = 0;
		$self->debug(0, "requires a something todo($todo)");
	} else {
		my $fmt = $self->current('format');
		$self->current('format', 'a');
		my $to = $self->system('maintainer');
		require Perlbug::Email; # yek
		my $o_email = Perlbug::Email->new;
		my $o_todo = $o_email->get_header;
		$o_todo->add('To', $to);
		$o_todo->add('From', $self->email('bugdb'));
		$o_todo->add('Subject', $self->system('title')." todo request");
		$i_ok = $o_email->send_mail($o_todo, $todo);
		$self->debug(0, "todo'd($i_ok) <- ($todo)");
		$self->current('format', $fmt);
	}
	$self->debug('OUT', $i_ok);
	return $i_ok
}


=item track

Track some function or modification to the db.

	$i_tracked = $self->track($type, $id, $entry);

=cut

sub track {
	my $self 	= shift;
	$self->debug('IN', @_);
    my $type    = shift;
	my $id		= shift;
	my $entry	= shift; # cmd 
	my $userid  = $self->isadmin;
	my $quoted  = $self->quote($entry);
	$self->debug(3, "type($type), id($id), entry($entry)->quoted($quoted), userid($userid)");
    my $i_ok 	= 1;
	my $insert = qq|INSERT INTO tm_log values (NULL, NULL, $quoted, '$userid', 'x', '$id', '$type')|;	
	my $res  = $self->query($insert);
  	if (!ref($res)) {
		$i_ok = 0;
		$self->debug(0, "track failure ($insert) -> '$res'");
	}		
	$self->debug('OUT', $i_ok);
	return $i_ok;	
}


=item ck822

Email address checker (RFC822) courtesy Tom Christiansen/Jeffrey Friedl.

    print (($o_email->ck822($addr)) ? "yup($addr)\n" : "nope($addr)\n");

=cut

sub ck822 { # RFC internet address checker
    my $self = shift;
    $self->debug('IN', @_);
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
        $self->debug(3, "rfc822 succeeds on '$addr'"); 
        $i_ok = 1;
    } else {
        $self->debug(0, "rfc822 failure on '$addr'"); 
        $i_ok = 0;
    }
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item htpasswd

Modify, add, delete, comment out entries in .htpasswd

    $i_ok = $o_web->htpasswd($userid, $pass);   # entry ok?

    @entries = $o_web->htpasswd;                # returns list of entries ('userid:passwd', 'user2:pass2'...)

=cut

sub htpasswd {
    my $self = shift;
    my $user = shift;
    my $pass = shift; 
    my $htpw = $self->directory('config').'/.htpasswd';
    $self->debug(1, "htpasswd($user, $pass) with($htpw)");
    my @data = $self->copy($htpw, $htpw.'.bak'); # backitup
    my $i_ok = 1;
    if (($i_ok == 1) or (scalar(@data) >= 1)) {
        open HTP, "> $htpw" or $i_ok = 0;
    	if ($i_ok == 1) {
            flock(HTP, 2);
            my $htpass = join('', @data);
            $self->debug(3, "Existing htpasswd file: '$htpass'");
            if (($user =~ /^\w+$/) && ($pass =~ /\w+/)) {
                $self->debug(1, "HTP: working with user($user) and pass($pass)");
                if ($htpass =~ /^$user:(.+)$/m) {    # modify?
                    my $found = $1;
                    $self->debug(0, "found($found)");
                    if ($found ne $pass) {
                        $htpass =~ s/^$user:(.+)?$/$user:$pass\n/gms;
                        $self->debug(1, "HTP: changing user($user) found($found) to pass($pass)");
                    } else {
                        $self->debug(1, "Not changing user($user) or pass($pass) with found($found)");
                    }
                } else {                        # add!
                    $htpass .= "$user:$pass\n";
                    $self->debug(1, "HTP: adding new user($user) / pass($pass)");
                } 
                $htpass =~ s/^\s*$//mg;
                truncate HTP, 0;
                seek HTP, 0, 0;  
    	        print HTP $htpass or $self->debug(0, "Can't print new htpass($htpass) to htp(HTP)");
                $self->debug(3, "Modified htpasswd file: '$htpass'");
            }
            @data = split("\n", $htpass);
            flock(HTP, 8);
    	    close HTP;
        } else {
            my $err = "Can't open htpasswd file($htpw)! $!";
            $self->result($err);
            $self->debug(0, $err);
    	}
    } else {
        $self->debug(0, "copy($htpw, $htpw.'.bak') must have failed?");
    }
    return (wantarray ? @data : $i_ok);
}


=item clean_up

Clean up previous (logs and results) activity whenever run.

Exits when done.

=cut

sub clean_up {
    my $self = shift;
    my $max  = shift || $self->system('max_age');
    $self->debug(3, "clean_up($max)");
	my $found = 0;
    my $cleaned = 0;
	if ($max =~ /^\d+/) {
		foreach my $DIR (qw(results logs temp ranges)) { 
			my $dir = $self->directory('spool')."/$DIR";
			$self->debug(4, "cleaning($dir)");
        	if (-d $dir) {
	    		my ($remcnt, $norem) = (0, 0); 
	    		opendir DIR, $dir or $self->debug(0, "Can't open dir ($dir) for clean up $!");
	    		my @files = grep(/\w+\.\w+$/, readdir DIR);
	    		$found += scalar(@files);
				$self->debug(4, 'Found: '.scalar(@files).' files');
	    		close DIR;
	    		foreach my $file (@files) {
	        		next unless -f "$dir/$file";
	        		my $FILE = "$dir/$file";
	        		if (-M $FILE >= $max) { # remove file if old 
	            		if (!unlink($FILE)) {
	                		$self->debug(0, "Unable to remove result file '$FILE' $!");
	                		$norem++;
	            		} else {
	                		$self->debug(4, "Removed ($FILE)");
	                		$remcnt++;
	            		}
	        		} else {
	            		$self->debug(4, "Ignoring recent file '$FILE'");
	        		}
	    		}
            	$self->debug(4, "Process ($$): dir($dir) fertig: rem($remcnt), norem($norem) of ".@files);
            	$cleaned += $remcnt;
        	} else {
            	$self->debug(0, "Can't find directory: '$dir'");
        	}   
		}
    }
    $self->debug(2, "Cleaned up: age($max) -> files($cleaned) of($found)");
}


sub delete_from_table { # where
	my $self  = shift;
	$self->debug('IN', @_);
	my $table = shift;
	my $where = shift;
	my $i_ok  = 1;
	if (!($table =~ /^tm_\w+$/ and $where =~ /^WHERE\s+\w+/i)) {
		$i_ok = 0;
		$self->debug(0, "can't operate with table($table) and where($where) clause");
	} else {
		my $del = qq|DELETE FROM $table $where|;
		my $sth = $self->exec($del);
		if (!defined($sth)) {
			$i_ok = 0;
			$self->debug(0, "failed");
		}
	}
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item insert_bug

Insert a bug into the database

	my ($i_ok, $bid, $mid) = $o_obj->insert_bug(@args);

=cut

sub insert_bug { # into db
    my $self = shift;
    $self->debug('IN', @_);
    my ($subject, $from, $to, $header, $body) = @_;
    $self->debug(3, "insert_bug($subject, $from, $to...)");
    my $ok = 1;
    my $title = $self->system('title');
    my ($bid, $mid, $err) = ('', '', '');
    if ($ok == 1) {
        ($ok, $bid) = $self->bug_new({ 
            'subject'     => $subject,
            'sourceaddr'  => $from,
            'destaddr'    => $to, 
        });
        if ($ok != 1) {
            $err = 'NEW_TKT failure';
        }
    }
    if ($ok == 1) {
        # Add the message
        # $body =~ s/^(.*)\n---\n$title: .*$/$1/m; 
        $self->debug(2, "Adding message ($ok, $bid).");
        ($ok, $mid) = $self->message_add($bid,{  
            'author'    => $from,
            'msgheader' => $header,
            'msgbody'   => $body,
        });
        if ($ok != 1) {
            $err = 'NEW_MSG failure';
        }
    } 
    $self->debug('OUT', $bid, $mid);
    return ($ok, $bid, $mid);
}


=item parse_flags

Return the 'AND ...' or 'SET ...' condition for a tm_ticket query given the 
flags from the status, category and severity columns WITHOUT the leading 'AND' 
or a leading ', ' separator.

    my $stuff = $pb->parse_flags([('o', 'build')], 'AND'); 
    # $stuff is now "status = 'open' AND category = 'build'"
    my $sql = "SELECT * FROM some_table WHERE $stuff";
    # or 
    my $stuff = $pb->parse_flags([('o', 'build')], 'SET'); 
    # $stuff is now "status = 'open', category = 'build'"
    my $sql = "UPDATE tm_tickets SET $stuff WHERE ticketid = 'xyz'";
    
=cut

sub parse_flags { 
    my $self = shift;
    my ($str, $type) = @_;
	$str = (ref($str) eq 'ARRAY') ? join(' ', @{$str}) : $str;
    my $this = ($type eq 'AND') ? 'AND ' : ',   '; # AND|SET
    $self->debug(2, "Parsing str ($str), type ($type) ... this ($this)");
    my @tm_flags = $self->get_list('SELECT DISTINCT type FROM tm_flags');
	my $sql = undef;
    my %seen = ();
	FLAG: 
	foreach my $f (@tm_flags) {
        $self->debug(3, "Parsing flag ($f)");
        my @opts = $self->get_list("SELECT flag FROM tm_flags WHERE type = '$f'");
        OPT: 
		foreach my $opt (@opts) {
            $self->debug(4, "Comparing str ($str) and opt ($opt)");
            STR: 
			foreach my $bit (split ' ', $str) {
                next unless $bit =~ /\w/;
                if ($opt =~ /\b$bit/i) {
                    my $line = " $this $f = '$opt' ";
					$seen{$opt}++;
                    $self->debug(4, "Flag ($f) matched, line ($line) made.");
                    $sql .= $line;
                    next FLAG;
                } else {
                    $self->debug(4, "Flag ($f) not matched: opt($opt) bit($bit)");
                }
            }
        }
        $self->debug(3, "Flag ($f) set sql ($sql)");
    }
	$sql =~ s/^(.+)?$type\s*$/$1/;
	$sql =~ s/^[\,\s]+(\w.+)$/ $1/;
	if (!(scalar(keys %seen) >= 1)) {
		$sql .= " AND ticketid = 'non-plaus_ible bug id!' AND ticketid = 'no flag found protector :-)' ";
		$self->debug(0, "Setting duff flag to protect against all bugs being returned: '$sql': ".Dumper(\%seen));
	}
    # $sql = (length($sql) > 4) ? substr($sql, 4) : $sql; #   start
	$self->debug(2, "Parse ($str, $type) result: sql($sql)");
    return $sql;
}


=item parse_str

	my %cmds = $o_obj->parse_str('patch_<bugid>_etc' | (qw(patchid bugid etc));

=cut

sub parse_str {
	my $self = shift;
	$self->debug('IN', @_);
	my $args = shift;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : ($args);
	@args = map { split(/(\s|_)+/, $_) } @args;
	my %cmds = (
		'bugids'   => [],
		'flags'    => [],
		'changeids'=> [],
		'versions' => [],
		'unknown'  => [],
	);
	my $i_ok = 1;
	
	my @tids = $self->get_list("SELECT DISTINCT ticketid FROM tm_tickets");
	my @flags = $self->get_list("SELECT DISTINCT flag FROM tm_flags");
	
	ARG:
	foreach my $arg (@args) {
		next ARG unless $arg =~ /\w+/;
		if ($self->ok($arg) and length($arg) == 12) {	# bugid
			push(@{$cmds{'bugids'}}, $arg);
		} elsif (grep(/^$arg/, @flags)) {				# flag
			push(@{$cmds{'flags'}}, $arg);
		} elsif ($arg =~ /^(\d\d+)$/) {					# changeid			
			push(@{$cmds{'changeids'}}, $arg);								
		} elsif ($arg =~ /^\d+\.[\d+\.]+$/ and !$self->ok($arg)) { # version number		
			push(@{$cmds{'versions'}}, $arg);			
		} else {										# unknown
			push(@{$cmds{'unknown'}}, $arg);
			$self->debug(0, "ignoring arg($arg) as non-recognised bugid, changeid or version number!");
		}
	}
	# print "in(@args), out-> ".Dumper(\%cmds);
	# $self->result("parsed input(@args) -> \n".Dumper(\%cmds));
	$self->debug('OUT', Dumper(\%cmds));
	return %cmds;
}


$SIG{'INT'} = sub {
	carp "Perlbug interupted: bye bye!";
	exit(1);	
};

sub DESTROY {
	my $self = shift;
}


=back

=cut

# 
1;
