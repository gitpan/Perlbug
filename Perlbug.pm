# Perlbug docs and placeholder
# (C) 1999 2000 2001 Richard Foley RFI perlbug@rfi.net
# $Id: Perlbug.pm,v 2.91 2002/01/11 13:51:05 richardf Exp $
#
# pod2text -la ~/Perlbug.pm > ~/docs/spec
# pod2html ~/Perlbug.pm  > ~/docs/spec.html  
#

=head1 NAME

Perlbug - PerlBug DataBase specification 

=cut

package Perlbug;           
use strict;
use vars qw($VERSION);
push @INC, qw(/home/perlbug/locallibs);
$VERSION = do { my @r = (q$Revision: 2.91 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

$Perlbug::CONFIG = $ENV{'Perlbug_CONFIG'} || $Perlbug::CONFIG || '/home/perlbug/config/Configuration';
$Perlbug::DEBUG  = $ENV{'Perlbug_DEBUG'}  || $Perlbug::DEBUG  || '0';
$Perlbug::FATAl  = $ENV{'Perlbug_FATAL'}  || $Perlbug::FATAL  || '0';

	# 0.00+ Original Perlbug 
	# 1.00+ Brought under RCS, config file, cached db entries, improved logging etc
	# 2.00  Command line interface, history mechanism, bugid parent/child relations
	#       auto-registration, multiple test suites etc
	#       patches, notes, tm_cc
	#       Fix data structure interface
	#       bug tests support, command line interface(bugdb)
	#       migrate tables and code (ticket->bug, etc.)
	# 	created, ts, table_definitions...
	#	perldoc help for web interface(bugtk)
	#	Merijn's Tk interface integrated
	#  	group support
	# 2.34	Perlbug::Objects integrated 
	# 	full read($oid)->format([alA]) facility, (hHL not-finished yet)
	# 	completed formatting support, htmlify, etc., robots.txt
	# 2.38  Object::update/insert
	# 2.40  Restructure complete db to cater for Relation::(assign|store|update|delete) etc.
	# 	category -> group, debug levels extended /[012isx]+/i
	#       rsync db and code archive dir. (thanks Ask), AUTOLOAD, 
	#	migrated tables from tm_ -> pb_, overviews with versions (a|h|H) 
	# 2.50  release from 2.4* dev 
	#   	optimisations, AUTOLOAD, Log->File(flock->process->unflock)
	# 	WWW frames, javascript for selection and navigations, 
	#  	bugfix fully functional, email(reply) fix, reintegrating tests...
	#
	# 2.60+ prep'd for rcs->cvs and ~(richard|perlbug) -> 2.70+
	# 2.70+ <--   we're here :-) migrated into perlbug.SourceForge.net
	# 2.80+ Oracle(ish) support, re-enabled debugging, admin switches, newid() etc.
	#       Revamped test email suite away from directories into managable files
	#       Tests run clean (no spurious redifined subs. etc.)
	#       Consolidated all do() parameter parsing
	#       bughist -E forwarding, template (layout) integration
	#       fixed the errant cmd_<bugid>_var@domain parse, do(\w) and feedback 
	#       indexes throughout, optimize tables, rr(rels)
	# 2.90+ templates, Web has individual (pro object) search forms, doc mods. 
	#       transfer of main object types to one another (message->patch, note->test, etc.)
	# 
	# 3.00  Full test suite and Oracle support
	# 	    ...


=head1 DESCRIPTION

Bug, and problem management, tracking system, written in perl.

Currently using Mysql, probably running on Linux with Apache.

For installation instructions see the INSTALL file.

=cut


=head1 SYNOPSIS

Note that the given addresses are configurable for individual sites, treat these examples of current usage as defaults.

New bugs are created by mailing perlbug@perl.org or perlbug@perl.com

Said bug is entered in the database, and given a new bugid, the mail is then forwarded to perl5-porters with the bugid in the subject line..

perl5-porters(p5p) is continously tracked for relevant mails to attach to said bug.

There are web(http://bugs.perl.org), email(bugdb@perl.org and help@bugs.perl.org), command line(bugdb) and Tk (bugtk) frontends to query and administrate the bugs.  See B<scripts> below

Regular overviews are emailed to p5p, and outstanding bugs are mailed to active admins for their attention.

All modules have perldocs embedded, to browse at your leisure.

	perl -MPerlbug::Base -e "print Perlbug::Interface::Cmd->new()->object('bug')->read('19870502.007')->format('A')"

=cut


=head1 COMPATIBILITY

=over 4

=item web

	Netscape is the standard benchmark, w3m is used to ensure frame/noframe 
	compatibility, which should cover the worst cases.  I don't have MSIE to 
	check against, but feedback on this is welcome if there are problems.

=item database

	Currently only Mysql is supported on UNIX(linux), though Oracle looms 
	continously, and will be implemented when I get round to it.

=back

=cut


=head1 FEATURES

	Written in perl

	Robust, with test suites:

    All tests successful.
	Files=33,  Tests=241, 127 wallclock secs (36.66 cusr +  2.66 csys = 39.32 CPU)                      

	Compare to June 2000 - (more tests in less time and/or cpus :)
    Files=28,  Tests=148, 148 wallclock secs (59.27 cusr +  2.61 csys = 61.88 CPU)

	Under CVS on sourceforge.net (previously stored under RCS)

	Documented (in perldoc -> do what I say _and_ what I do ;-)

	Freely available sourcecode (on sourceforge.net)

	Integrated with perlbug

	It has a simple (single config file) installation.

	Site configurable email newbug recognition and forwarding.

	Site configurable scanning of email bodies -> categorisation of reports.

	Standard installation*: perl Makefile.PL; make; make test; make install.

	Multiple interfaces (take your pick):

        Web             -> search, browse and destroy interface

        Tron            -> target and mailing list slurper/forwarder

        Email 1         -> subject: oriented search, report and admin   

        Email 2         -> to: oriented report and admin

        Command line    -> for local db (similar to email)

		Tk				-> search, browse the db 

	More than 5 different formatting types for all discrete objects are supported 
	across all outputs for both public and administrative, (which will become 
	configurable in the non-too-distant future), interfaces for:

        	bugs, messages, patches, notes, tests, users, groups, etc.

	Differential user/admin help for all formats.

	Several utility scripts (see below)

	Accepts target mail addresses (and thereby sets category etc.) and forwards to

		appropriate mailing list/s.

	Watches various mailing list for replies to existing bugs to slurp,

		checking subject and reply-to, message-ids, etc.

	Defense mechanisms against loops, spam, and other entertaining factors.

	Ignores previously seen message-ids, non-relevant (spam) mail.

	Test targets to email interfaces (dumps header -> originator)

	Email interface handles any of the following To lines (and more):

        close_<bugid>_@bugs.perl.org                     -> bug admin 

        busy_win32_install_fatal_<bugid>@bugs.perl.org   -> admin

        propose_close_<bugid>_@bugs.perl.org             -> bug admin proposal

        note_<bugid>_<bugid>_duplicate@bugs.perl.org     -> assign note and admin

        patch_<version>_<bugid>_<changeid>@bugs.perl.org -> assign a patch

        register_me@bugs.perl.org                        -> admin registration request

        admins@bugs.perl.org                             -> admin mail forward

        help@bugs.perl.org                               -> :-)

	And the following (not very cryptic) Subject lines:

        -h                      

        -b <bugid>+

	-s subject_search

        -H -d2 -l -A close <bugid>+ lib -g patch -e some\@one.net 

        -g pa cl wi -p3 -t1 -h -m77 812 1 21 -b <bugid>+ -B <bugid>+ -o -l -d2 -a clo inst <bugid>+ -fA

        :-) etc... (see the email help docs for more info)

	Auto database dump, email of overview and bugid->admin assignation

	Patches can be emailed in -> auto close of bug

	Notes can be assigned from any interface to any bug

	Tests can be assigned to any bug

	Non-admin emails -> converted to proposals -> mailed to active admins

	Cc: list (and admins) are optionally auto-notified of any status changes to bugs 

	Relationships between bugs (parent-child) are assignable.

	Retrieval of database via email and http and ftp and via rsync.

	Logging of all activities, admin history tracking.

	Graphical display of overview (admins, categories, severity, osname, status).

=cut


=head1 SCRIPTS

The perlbugtron contains the following scripts:

=over 4

=item bugcgi

The web interface

=item bugcron

The regular cron job interface to backups, weekly notifications etc.

=item bugdb

The command line interface

=item bugfix

A command line utility to fix various forms of duff data in the bug database

=item bughist

A parser of directories of archived mail (treated as per tron.pl).

=item bugmail

A query and administrative email front end, examining both Subject: and To: line for instructions.  Accepts mail for bugdb@perl.org and *@bugs.perl.org. 

Note - bugmail functionality is now incorporated within B<bugtron> below.

=item bugtk

The Tk interface

=item bugtron

Tracks mailing lists, relying on header information to identify new bugs and replies to existing ones.  Accepts mail for perlbug@perl.org and perlbug@perl.com and relevant target mailing lists.  See B<bugmail>

=item bugwatcher

Any mails sent to this script, if likely looking, will be forwarded FAO B<bugmaster>, to catch any which might otherwise 'fall through the cracks'.

=back

=cut


=head1 CLASSES

For those that are interested the Perlbug application module hierarchy goes something like this:

    (ISA) Do          (HASA) Config Database Log
          |                  |      |        |  
          -------     ------------------------
                |_____|
                   |
                   Base [Interface] (HAS objects)
                   |
                   --------------------------------------------------
                          |       |                         |       |
                        Cmd       Email                     Web     Tk
    -----------------------       -----------------         ---     --- 
    |       |     |       |       |       |       |         |       | 
    bugcron bugdb bughist bugfix  bugtron bugmail bugwatch  bugcgi  bugtk


While the Perlbug Objects themselves look a bit like this:

      Format + Template
      -----------------
             |
       (ISA) Object  (MAY) have Relation(s) with one another :-)
             ------             --------
             |
    Address  Bug  Group  Message  Note  Patch  Test  User  Status ...
    -------  ---  -----  -------  ----  -----  ----  ----  ------

Since moving B<status>, B<osname>, etc. over to being objects in their own 
right, and dedicated tables thereof, which may relate to each other in most 
any combination, you may notice we have a 'riesen menge' (a lot) of objects, 
some of which at first glimpse may seem overkill.  On this point, I can only 
agree.  However my defense/argument for this implementation is that I have
tried to keep it as B<clean> as possible, and that meant being somewhat 
(ob|sub)jectively pedantic now and then - so there you have it :-)

Anyone actually looking into this code will find the Objects are fairly clean 
(I hope), and should reliably relate to each other.

=cut


=head1 CODE  

Anyone considering contributing code, (and some already have), to this
project would do well (of course :-) to RTFM.  I've tried to keep the 
docs as up to date as possible.

The code is currently stored under cvs on SourceForge: 

	https://sourceforge.net/projects/perlbug/

Most recent release can also be retrieved from the CPAN at:

	http://www.cpan.org/authors/id/R/RF/RFOLEY

The live system is on onion.perl.org under the ~perlbug account, talk to 
gnat@frii.com or ask@valueclick.com for access.

Note: the output of 'make test' should be 100% succesful before commiting
any changes to the code, please!

=back


=head1 VARIABLES

There are several package variables which may be set, see the B<CONFIG> entry 
below for how to do this.  Note the replacement of '::' with '_'.

Environment variables take priority over code, which have priority over the 
configuration file entries themselves, on initial setting.

=over 4

=item CONFIG

The initial Perlbug Config(uration) file to use may be set at the top of this module:

	$Perlbug::CONFIG = '/home/perlbug/config/Configuration';

or as an environment variable (in bash):

	export Perlbug_CONFIG = './my_config_file'

=item DEBUG

The debug level - see B<Perlbug::Base::debug()> for the options

	export Perlbug_DEBUG=1

For example, to see what's going on without looking in the log file:

	export Perlbug_DEBUG=012d; perl t/31_Object.t

=item FATAL

Will cause the application to die on the first error if set to 1

If set to 0, will merely produce a message, on screen or in the logs.

	export Perlbug_FATAL=1

=back


=head1 DEVELOPMENT

A developer of any part of this system, who wishes to use the existing code
base, is encouraged to approach it in the following manner:

Initially get a B<Perlbug::Base> object which holds all the configuration 
data for the application, and from here all other B<Perlbug::Object::*>'s 
are accessible via the B<object()> call: see L<Perlbug::Base::object>.

Alternatively start with a B<Perlbug::Interface::*> which B<ISA> B<Perlbug::Base> in any case.

Once the appropriate object has been retrieved, it may be used via a B<class> 
method, or as a particular instance, where the object has been initialised.

For example using Perlbug::Base or Perlbug::Interface::(Cmd|Email|Web)->new... 

	my $o_base = Perlbug::Interface::Cmd->new();	# get a basic interface 

	my $o_bug = $o_base->object('bug');				# the appropriate object

	print "All bugids: ".join(', ', $o_bug->ids(); 	# class method

	$o_bug->read('19870502.007');					# instantiate

	print "Bug data: \n".$o_bug->format('A'); 		# instance method	

The object knows what relationships it has, so ask it:

	print "Relations: ".join(', ', $o_bug->relations); 	# group, note, user...

And so on:

	print map { $_->key.' ids: '.$o_bug->rel_ids } $o_bug->relations;

There should be no need to directly query the db with hard-wired SQL, 
everything should be do-able through the supplied object interfaces, 
(if this is not the case, speak - I/we will fix it.

Note that in the entire application there is only a single place where it has  
proved necessary to refer directly to a database tablename and this is in the 
configuration filename.  All other data is extrapolated from the objects 
themselves in a more or less predictable manner.

The output is largely controlled via formats supplied as default in 
L<Perlbug::Format>, or where this is not sufficient, in each object 
class itself.  See B<Perlbug::Format::FORMAT_[ahlxi]> etc.
Note the trailing letter defining the type of format required.  
It would be simple, for example, to add an XML format using the 
supplied placeholder in L<Perlbug::Format_x>

The format system will at some point shortly migrate into a table of 
templates that will then be applicable to any object by any registered 
user in any context...  
Which will hopefully satisfy _most_ people _most_ of the time ;-)

If something is missing, tell me, or write the code to do it and contribute.

=cut


=head1 COMMANDS

A couple of useful commands:

Send mail into the db:

	cat some_mail | ~/scripts/bugtron

Slurp up to 33 archived mails, recursively, with feedback:

	~/scripts/bughist -v -i /path/to/email/archives -m 33 -r

Send a query to the db via the email interface:

	cat my_admin_email | ~/scripts/bugmail

Or interact with it via the command line:

	~/scripts/bugdb

Send active admins unclosed bugs, remind open bug submitters their bug remains 
	open, send an overview to master_list(p5p), backup current database:

    crontab -e 3 5 * * 1 ~/scripts/bugcron

A couple of useful(?) command-lines:

	perl -MPerlbug::Base -e 'print map { "$_\n" } Perlbug::Base->new->object('bug')->ids("subject like \"%strict%\"")';

	perl -MPerlbug::Base -e 'print Perlbug::Base->new->object('group')->_read("configure")->format("a")'; 

=cut


=head1 BUGS

What bugs ?-)

You have a few choices, (with the output of 'make test TEST_VERBOSE=1' please):

	1. Mail perlbug@perl.org which will assign a bugid.

	2. Mail the author (richard@perl.org or perlbug@rfi.net) directly.

	3. Mail admins@bugs.perl.org which will Cc: to all active admins.

	4. Subscribe to bugmongers@perl.org (a mailing list for those interested in perl bugs).

	5. Or try perl5-porters@perl.org (p5p) for a more generic solution.

=cut


=head1 TODO

Oracle support

Comprehensive test suite

and a few other things...

=cut


=head1 AUTHOR

Richard Foley richard@perl.org perlbug@rfi.net (c) 1999 2000 2001

=cut


=head1 CONTRIBUTORS

The system was given a kick start by Christopher Masto, NetMonger Communications <chris@netmonger.net>.


It's development has been overseen originally by Chip Salzenburg <chip@perlsupport.com> and later by Nathan Torkington <gnat@frii.com> (who was also responsible for the original perl bug tracking system).

The current home is given a stolidly home at http://bugs.perl.org/ by Ask Bjoern Hansen <ask@valueclick.com>.


There have been numerous suggestions, feedback and even patches from various people, in particular (in purely alphabetical order):

	Merijn Brand <h.m.brand@hccnet.nl> (Tk support)

	Alan Burlison <Alan.Burlison@uk.sun.com>

	Mike Guy <mjtg@cam.ac.uk>

	Jarkko Hietaniemi <jhi@iki.fi>

	Andreas Koenig <andreas.koenig@anima.de>

	Richard Soderberg <rs@oregonnet.com>
	
	Michael Stevens <mstevens@etla.org>

	Hugo van der Sanden <hv@crypt0.demon.co.uk>

	Robert Spier <rspier@pobox.com> (adminfaq)

and many others


Special thanks to Tom Phoenix <rootbeer@redcat.com>.

=cut


=head1 COPYRIGHT

Copyright (c) 1999 2000 2001 Richard Foley richard@rfi.net. All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

# 
1;
