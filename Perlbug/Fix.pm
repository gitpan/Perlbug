# $Id: Fix.pm,v 1.10 2000/09/14 11:09:24 perlbug Exp perlbug $ 

=head1 NAME

Perlbug::Fix - Command line interface to fixing perlbug database.

=cut

package Perlbug::Fix;
use File::Spec; 
use lib File::Spec->updir;
# use Getopt::Std;
use Data::Dumper;
use Perlbug::Cmd;
@ISA = qw(Perlbug::Cmd);
use strict;
use vars qw($VERSION);
$VERSION = 1.11;
$|=1;

my %ARG = (
    "h" => '', "t" => 0, 'd' => 0, 'p' => '', 'u' => '',
);
# getopts('htdpu:', \%ARG);      


=head1 DESCRIPTION

Command line interface to fixing incorrect perlbug data.

Note: L<mig()> will migrate from pre-2.26 database structure to current usage.

=head1 USAGE

  	lowercase is indicator/report 
	
	UPPERcase expands/effects
	
	> h		# help
	
	> H		# Helpful help
	
	> f		# view erroneous flags
	
	> F		# Fix erroneous flags
	
	> mig	# check stuff
	
	> MIG 	# Fix stuff (migrate...)
	
	> 		# etc.


=head1 METHODS

=over 4

=item new

Create new Perlbug::Fix object:

    my $o_fix = Perlbug::Fix->new();

=cut

sub new {
    my $class = shift;
    my $arg   = shift;
    my $self = Perlbug::Cmd->new(@_);
    bless($self, $class);
}

my $FIX = 0;
my %MAP = (
	'b' => 'bugs',	    'bh' => 'deletes non-valid bugid bugs',
    'c' => 'claimants',	'ch' => 'deletes non-existent userid claimants',
	'cc'=> 'cc', 		'cch'=> 'deletes non-existent bugid references, AND inserts each Cc: from tm_messages::msgheader',
	'f' => 'flags',		'fh' => 'set tm_bugs::flags(blank) where unknown in tm_flags',
	'f1' => 'flags_status',		'f1h'=> 'resolve status, also updates tm_flags!',
	'f2' => 'flags_osname',		'f2h'=> 'resolve osnames, also updates tm_flags!',
	'f3' => 'flags_category',	'f3h'=> 'resolve category, also updates tm_flags!',
	'f4' => 'flags_severity',  	'f4h'=> 'resolve severity, also updates tm_flags!',
	'h' => 'help',		'hh' => 'more detailed help',
  # 'l' => 'log', 		'lh' => 'loooooo  oogs',
	'm' => 'messages',	'mh' => 'deletes non-existent bugid messages',
	'n' => 'notes',		'nh' => 'deletes non-existent bugid notes',
	'p' => 'patches',	'ph' => 'trashes ticket_patch relationship where no (bugid|patchid)',
	'q' => 'doq',	    'qh' => 'query the database (Q for the schema)',
  # 't' => 'tests',	    'th' => 'deletes non-valid tests',
    'u' => 'user',
  	'x' => 'xspecial',  'xh' => 'xtra-special runs -> ?',
  #                            -> MIGRATE <-
    'mig'=> 'mig',      'migh'=> 'MIGRATE from 2.23 to 2.26: patches->patchid/bugid, ticketid->bugid, etc.',
    # 'x0' => 'x0',		'x0h' => 'MIGRATE logs',
    # 'x1' => 'x1',		'x1h' => 'MIGRATE notes',
    # 'x2' => 'x2',		'x2h' => 'MIGRATE patches',
    # 'x3' => 'x3',		'x3h' => 'MIGRATE tests',
    # 'x4' => 'x4',		'x4h' => 'MIGRATE claimants',
    # 'x5' => 'x5',		'x5h' => 'MIGRATE cc',
    # 'x6' => 'x6',		'x6h' => 'MIGRATE messages',
    # 'x7' => 'x7',		'x7h' => 'MIGRATE bugs',
   	# 'x8' => 'x8',		'x8h' => 'MIGRATE users',
	# 'x9' => 'x9',     'x9h' => 'MIGRATE id',
	# 'x99'=> 'x99',    'x99h'=> 'MIGRATE clean up',
   #'x31'=> 'x31',      'x31h'=> 'update tm_claimants from tm_logs by userid',
   #'x32'=> 'x32',      'x32h'=> 'mails that were new but did not make it out to p5p',
);
	
sub quit { print "Bye bye!\n"; exit; }

sub help {
	my $self = shift;
	my $i_ok = 1;
	my $help = "Fix help:\nlowercase reports, UPPERCASE does it!\n";
	foreach my $k (sort keys %MAP) {
		next if $k =~ /^\w+h$/;
		my $hint = "${k}h";
		$help .= ($FIX == 1) ? "$k = $MAP{$hint}\n" : "$k = $MAP{$k}\n";
	}
	$self->result($help);
	return $i_ok;
}

sub doq { # rewrapper :-\
	my $self = shift;
	my @args = @_;
	my $sql = join(' ', @args);
	my $query = ($FIX == 1) ? 'SUPER::doQ' : 'SUPER::doq';
	return $self->$query($sql);
}


=item process

Processes the command given, gets and truncates the results, calls scroll

=cut

sub process {
	my $self = shift;
	$self->debug('IN', @_);
	my $orig = shift;
	my @res  = ();
	my $i_ok = 1;
	my $targ = lc($orig);
	my ($call, @args) = split(/\s+/, $orig);
	
	if ($call =~ /^\w+$/ && $MAP{lc($call)} =~ /^[\w_]+$/) {
		$FIX++ if $call =~ /^[A-Z]+\d*$/;
		my $meth = $MAP{lc($call)};
		$i_ok = $self->$meth(@args);
		$FIX=0;
	} else {
		$i_ok = 0;
		print "didn't understand orig($orig), call($call), args(@args)\n";
	}
	if ($i_ok != 1) {
		$res[0] = "Command($orig) process failure($i_ok) - try 'h'\n";
	} else {
		@res = $self->get_results;
		if (!((scalar(@res) >= 1) && (length(join('', @res)) >= 1))) {
			$res[0] = "Command($orig) failed to produce any results(@res) - try 'h'\n";
		} 
		$self->truncate('res') || print "failed to truncate res file\n";
	}
	$i_ok = $self->scroll(@res);
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item flags

Set flags to '' in tm_tickets where flag is unknown in tm_flags

=cut

sub flags {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) flags");
	my $cnt = 0;

	if ($line =~ /^(\w+)$/) {
		return $self->map_flags($line);	
	} else {
		my @types = $self->get_list("SELECT DISTINCT type FROM tm_flags");
		foreach my $type (@types) {
			my @ok = $self->get_list("SELECT DISTINCT flag FROM tm_flags WHERE type = '$type'");
			my $ok = join("', '", @ok);
			my @notok = $self->get_list("SELECT ticketid FROM tm_tickets WHERE $type LIKE '_%' AND $type NOT IN ('$ok')");
			my $notok = join("', '", @notok);

			$self->debug(1, "$type: ok($ok), notok($notok)");
			$self->result("$type: ok(".@ok."), notok(".@notok.")");

			my $rows = 0;
			if (scalar(@notok) >= 1) {
				if ($FIX == 1) {
					my $sql = "UPDATE tm_tickets SET $type = '' WHERE ticketid IN ('$notok')";
					my $sth = $self->exec($sql);
					$cnt += $rows = $sth->rows;
					$self->result("$type fixed($rows)");
					$self->track('f', $type, $sql);
				} else {
					$self->result("$type: has ".@notok." flags(@notok)");
				}
			} else {
				$self->result("nothing to do (@notok)");
			}
		}
		$self->result("flags fixed($cnt)");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item map_flags

Adjust bug flags, note, this also updates the flags table with missing values!

=cut

sub map_flags { # duff flags
	my $self = shift;
	$self->debug('IN', @_);
	my $type = shift;
	my @res  = ();
	my %seen = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) flag($type)");
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_tickets");
	my $targs = join("', '", @targs);
	
	my $i_fix = 0;
	my @flags = $self->SUPER::flags($type);
	TID:
	foreach my $tid (@targs) {
		next TID unless $self->ok($tid);
		my ($db) = $self->get_list("SELECT $type FROM tm_tickets WHERE ticketid = '$tid'");
		my ($mid) = $self->get_list("SELECT MIN(messageid) FROM tm_messages WHERE ticketid = '$tid'");
		my ($msgbody) = $self->get_list("SELECT msgbody FROM tm_messages WHERE messageid = '$mid'");
		print '.'; # :-)
		if ($msgbody =~ /\b$type=(\w+)\b.*/msi) { 
			my $targ = lc($1);
			# fixes...
			next TID if (($targ =~ /^\d+$/) || ($targ =~ /\s+/));
			$targ = 'none' if $targ eq 'zero';
			$targ = $1 if $targ =~ /^3d(.+)$/i;
			if ($targ =~ /$db/i) {
				print '-'; # :-)
				# $self->result("tid($tid) was correctly marked($targ) in the db($db)");
			} else {
				$seen{$targ}++;
				if ($FIX) {
					print '+'; # :-)
					my $i_ok = $self->bug_set($tid, { $type    => $targ });
					my $msg = ($i_ok == 1) ? "Corrected($tid) db($db) -> '$targ'" : "Failed($i_ok) to correct db($db) -> '$targ'";             
        			$self->result($msg);
					$i_fix += $i_ok;
					if (!(grep(/^$targ$/i, @flags))) {
						print "inserting targ($targ) into flags($type)\n";
						my $insert = "INSERT INTO tm_flags values ('$type', '$targ')"; 
						my $i_x = $self->exec($insert);
						push(@flags, $targ);
					}
				} else {
					print '!'; # :-)
					$self->result("tid($tid) needs updating db($db) -> '$targ'");
				}
			} 
		} else {
			# $self->result("no $type found in msgbody (nothing to do)");
		}
	}
	
	print Dumper(\%seen);
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item cc

Correct tm_cc table

=cut

sub cc {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) cc");
	# 
	my @ok = $self->get_list("SELECT ticketid FROM tm_tickets");
	my $ok = join('|', @ok);
	
	my @targs = $self->get_list("SELECT ticketid FROM tm_cc");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);

	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");

	if (scalar(@notok) >= 1) {
		my $rows = 0;
		if ($FIX) {
			my $sql = "DELETE FROM tm_cc WHERE ticketid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows = $sth->rows;
			$self->result("tm_cc fixed non-existent bugids($rows)");
			$self->track('f', 'cc', $sql);
		} else {
			$self->result("tm_cc has ".@notok." non-existent bug references");
		}
	} else {
		$self->result("nothing to remove (@notok)");
	}
	
	if (1 == 1) { 
		my $cnt = 0;
		my $i_t = 0;
		my $dodgy = $self->dodgy_addresses('from');
		foreach my $tid (@ok) { 			# EACH
			$i_t++;
			my @exists = $self->get_list("SELECT DISTINCT address FROM tm_cc WHERE ticketid = '$tid'");
			my $exists = join('|', @exists, $dodgy);
			my @mids   = $self->get_list("SELECT messageid FROM tm_messages WHERE ticketid = '$tid' AND msgheader LIKE '%Cc:%'");
			foreach my $mid (@mids) { 		# AND EVERY
				my ($msgheader) = $self->get_list("SELECT msgheader FROM tm_messages WHERE messageid = '$mid'");
				my @lines = split("\n", $msgheader);
				my @cc = map { /^Cc:\s*(.+)\s*$/ } grep(/^Cc:/, @lines);
				my @o_ccs = Mail::Address->parse(@cc);
				my @addrs = ();
				CC: 
				foreach my $o_cc (@o_ccs) {
					next CC unless ref($o_cc);
					my ($addr) = $o_cc->address;
					push (@addrs, $addr) if ($addr =~ /\w+/ and $addr !~ /$exists/i and $addr =~ /\@/);
				}
				if (scalar(@addrs) >= 1) {	# ONE
					if ($FIX) {
						my ($i_res, @ccs) = $self->tm_cc($tid, @addrs);
						$self->result("$i_t($tid->$mid fixed($i_res=".@addrs.") references(@addrs)");
						$cnt += $i_res;
					} else {
						$self->result("$i_t($tid->$mid) has ".@addrs." missing reference/s(@addrs)");
					}
					print $self->get_results;
					$self->truncate('res');
				}
			}
		}
		$self->result("fixed $cnt tm_cc records");
	} 

	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item bugs

Correct tm_tickets table

=cut

sub bugs {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) bugs");
	# 
	my @ok = $self->get_list("SELECT ticketid FROM tm_tickets");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT ticketid FROM tm_tickets WHERE ticketid NOT LIKE '________.___'");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);

	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");

	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "DELETE FROM tm_tickets WHERE ticketid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows = $sth->rows;
			$self->result("tm_tickets removed($rows) strange looking bugids");
			$self->track('f', 'tids?', $sql);
		} else {
			$self->result("tm_tickets has ".@notok." strange looking bugids");
		}
	} else {
		$self->result("nothing to do (@notok)");
	}

	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item messages

Correct messages table

=cut

sub messages {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) messages");
	
	my @ok = $self->get_list("SELECT ticketid FROM tm_tickets");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_messages");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "DELETE FROM tm_messages WHERE ticketid IN ('$notok')";
			# my $sql = "UPDATE tm_messages SET ticketid = 'unknown' WHERE ticketid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows = $sth->rows;
			$self->result("tm_messages set to blank($rows) non-existent bug references -> t(T)?");
			$self->track('f', 'msg2tids', $sql);
		} else {
			$self->result("tm_messages has ".@notok." non-existent bug references(@notok)");
		}
	} else {
		$self->result("nothing to do (@notok)");
	}
	
	my @feedback = $self->get_list("SELECT DISTINCT messageid FROM tm_messages WHERE ticketid = ''");
	if (scalar(@feedback) >= 1) {
		$self->result("The following messages appear to be headless: @feedback");
	}
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item notes

Correct notes table

=cut

sub notes {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) notes");
	
	my @ok = $self->get_list("SELECT ticketid FROM tm_tickets");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_note");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "DELETE FROM tm_note WHERE ticketid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows = $sth->rows;
			$self->result("tm_note removed($rows) non-existent bug references");
			$self->track('f', 'tid2notes?', $sql);
		} else {
			$self->result("tm_note have ".@notok." non-existent bug references");
		}
	} else {
		$self->result("nothing to do (@notok)");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item claimants

Correct claimants table

=cut

sub claimants {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) claimants");
	
	my @ok = $self->get_list("SELECT userid FROM tm_users");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT userid FROM tm_claimants");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "DELETE FROM tm_claimants WHERE userid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows = $sth->rows; 
			$self->result("tm_claimants removed($rows) non-existent userid references");
			$self->track('f', 'claim2user?', $sql);
		} else {
			$self->result("tm_claimants have ".@notok." non-existent userid references");
		}
	} else {
		$self->result("nothing to do (@notok)");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item patches

Correct patch relations table

=cut

sub patches {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) patches");
	
	my @ok = $self->get_list("SELECT patchid FROM tm_patch");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT patchid FROM tm_ticket_patch");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "DELETE FROM tm_ticket_patch WHERE patchid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows= $sth->rows;
			$self->result("tm_ticket_patch removed($rows) non-existent patchid references");
			$self->track('f', 'patch2tid?', $sql);
		} else {
			$self->result("tm_ticket_patch has ".@notok." non-existent patchid references");
		} 
	} else {
		$self->result("nothing to do (@notok)");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item users

Correct users table

=cut

sub _users {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) users");
	
	my @ok = $self->get_list("SELECT DISTINCT userid FROM tm_user");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT userid FROM tm_user");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		my $sql = "UPDATE tm_user SET active = NULL WHERE userid IN ('$notok')";
		my $sth = $self->exec($sql);
		$rows = $sth->rows;
		$self->result("disabled($rows) invalid userids");
	} else {
		$self->result("nothing to do (@notok)");
	}
	
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item action

Process action on behalf of caller

	my $i_ok = $self->action('tm_table', 'UPDATE x SET y WHERE z etc...');

=cut

sub action {
	my $self = shift;
	$self->debug('IN', @_);
	my $call = shift;
	my @actions = @_;
	my $i_ok = 1;
	my $ROWS = 0;
		
	if (!(@actions >= 1)) {
		$i_ok = 0;
		$self->result("No actions supplied(@actions)");
	} else {
		ACTION:
		foreach my $action (@actions) {
			last ACTION unless $i_ok == 1;
			my $sth = $self->exec($action);
			if (defined($sth)) {
				my $rows = 0;
				$ROWS += $rows = $sth->rows;
				# $i_ok = ($rows >= 1) ? 1 : 0;
				$self->result("Action affected($rows) -> ok($i_ok)");
				$self->track('f', 'fix_action', $action) unless $call eq 'tm_log';
			} else {
				$i_ok = 0;
				$self->result("Action failed($sth) -> for action($action)");
			}
		}
	}
		
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item mig

Migrate whole database

=cut

sub mig {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('mig', 'whole database');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my $targs = 9;
	
	if ($targs >= 0) {
		if ($FIX) {
			MIG:
			foreach my $num (0..$targs, 99) { # and clean up
				last MIG unless $i_ok == 1;
				my $action = "x$num";
				$i_fix += $i_ok = $self->$action();
			}
		} else {
			$self->result("$tables has ".(++$targs)." tables to migrate");
		} 
	} else {
		$self->result("nothing to migrate ($targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

# start migration
# ------------------------------------------------------------------------------

=item x0

Migrate log

=cut

sub x0 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x0', 'tm_log');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT logid FROM $tables ");
	
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_log (
		ts timestamp(14),
		logid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
		entry blob,
		userid varchar(16),
		objectid varchar(16),
		objecttype char(1),
		PRIMARY KEY (logid)
);|;
	my $transfer = qq|INSERT INTO tm_log SELECT ts, logid, entry, userid, objectid, objecttype FROM ${tables}_data|;
	 
	my $update = qq|UPDATE tm_log set objecttype = 'b' WHERE objecttype = 't' AND objectid LIKE '%.%'|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer, $update);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item x1

Migrate notes

=cut

sub x1 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x1', 'tm_notes');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
		
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_notes");
	my $targs = join("', '", @targs);		
	my $rows = 0;
	
	my $store   = qq|ALTER TABLE tm_notes RENAME tm_notes_data|;
	my $create1	= qq|CREATE table tm_note (
	  created datetime,
	  ts timestamp(14),
	  noteid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),
	  msgheader blob,		
	  msgbody blob,
	  PRIMARY KEY (noteid)
);|;
	my $create2	= qq|CREATE TABLE tm_bug_note ( 
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  noteid bigint(20) DEFAULT '' NOT NULL
);|;
	my $transfer= qq|INSERT INTO tm_note SELECT created, ts, noteid, '', '', '', msgheader, msgbody FROM tm_notes_data|;
	my $links	= qq|INSERT INTO tm_bug_note SELECT ticketid, noteid FROM tm_notes_data|;
	
	if (scalar(@targs) >= 1) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create1, $create2, $transfer, $links);
		} else {
			$self->result("tm_notes has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item x2

Migrate patches

=cut

sub x2 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x2', 'tm_patches');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
		
	my @targs = $self->get_list("SELECT DISTINCT patchid FROM tm_patches");
	my $targs = join("', '", @targs);		
	my $rows = 0;
	
	my $store   = qq|ALTER TABLE tm_patches RENAME tm_patches_data|;
	my $create1	= qq|CREATE table tm_patch (
	  created datetime,
	  ts timestamp(14),
	  patchid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),		
	  msgheader blob,
	  msgbody blob,
	  PRIMARY KEY (patchid)
);|;
	my $create2 = qq|CREATE TABLE tm_bug_patch ( 
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  patchid bigint(20) DEFAULT '' NOT NULL
);|;	
	my $create3 = qq|CREATE TABLE tm_patch_change ( 
	  patchid bigint(20) DEFAULT '' NOT NULL,
	  changeid varchar(12) DEFAULT '' NOT NULL
);|;	
	my $create4 = qq|CREATE TABLE tm_patch_version ( 
	  patchid bigint(20) DEFAULT '' NOT NULL,
	  version varchar(12) DEFAULT '' NOT NULL
);|;
	my $transfer= qq|INSERT INTO tm_patch SELECT created, ts, patchid, subject, sourceaddr, toaddr, msgheader, msgbody FROM tm_patches_data|;
	my $refs	= qq|INSERT INTO tm_bug_patch SELECT ticketid, patchid FROM tm_patch_ticket|;
	my $change  = qq|INSERT INTO tm_patch_change SELECT patchid, changeid FROM tm_patches_data|;
	
	if (scalar(@targs) >= 1) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create1, $create2, $create3, $create4, $transfer, $refs, $change);
		} else {
			$self->result("tm_patches has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item x3

Migrate tests

=cut

sub x3 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x3', 'tm_tests');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
		
	my @targs = $self->get_list("SELECT DISTINCT testid FROM tm_tests");
	my $targs = join("', '", @targs);		
	my $rows = 0;
	
	my $store   = qq|ALTER TABLE tm_tests RENAME tm_tests_data|;
	my $create1	= qq|CREATE table tm_test (
	  created datetime,
	  ts timestamp(14),
	  testid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),		
	  msgheader blob,
	  msgbody blob,
	  PRIMARY KEY (testid)
);|;
	my $create2 = qq|CREATE TABLE tm_bug_test (
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  testid bigint(20) DEFAULT '' NOT NULL
);|;
	my $create3 = qq|CREATE TABLE tm_test_version ( 
	  testid bigint(20) DEFAULT '' NOT NULL,
	  version varchar(12) DEFAULT '' NOT NULL
);|;
	my $transfer = qq|INSERT INTO tm_test select created, ts, testid, subject, sourceaddr, toaddr, msgheader, msgbody FROM tm_tests_data|;
	my $refs	 = qq|INSERT INTO tm_bug_test SELECT ticketid, testid FROM tm_test_ticket|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create1, $create2, $create3, $transfer, $refs);
		} else {
			$self->result("tm_tests has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

sub x4 { # claimants
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x4', 'tm_claimants');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_claimants");
	
	my $store   = qq|ALTER TABLE tm_claimants RENAME tm_claimants_data|;
	my $create	= qq|CREATE table tm_bug_user (
  		bugid varchar(12) DEFAULT '' NOT NULL,
  		userid varchar(16)
);|;
	my $transfer = qq|INSERT INTO tm_bug_user SELECT ticketid, userid FROM tm_claimants_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
	
} 


sub x5 { # cc
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	
	my ($sub, $tables) = ('x5', 'tm_cc');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_cc");
	
	my $store   = qq|ALTER TABLE tm_cc RENAME tm_cc_data|;
	my $create	= qq|CREATE table tm_cc (
  		bugid varchar(12) DEFAULT '' NOT NULL,
  		address varchar(100)
);|;
	my $transfer = qq|INSERT INTO tm_cc SELECT ticketid, address FROM tm_cc_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
	
} 

sub x6 { # tm_messages
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	
	my ($sub, $tables) = ('x6', 'tm_messages');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT messageid FROM $tables");
	
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create1	= qq|CREATE table tm_message (
 		created datetime,
		ts timestamp(14),
  		messageid bigint(20) unsigned NOT NULL auto_increment,
  		subject varchar(100),		
		sourceaddr varchar(100),	
		toaddr varchar(100),	
		msgheader blob,
		msgbody blob,
		PRIMARY KEY (messageid)
);|;
	my $create2	= qq|CREATE table tm_bug_message (
  		bugid varchar(12) DEFAULT '' NOT NULL,
		messageid bigint(20) unsigned NOT NULL
);|;

	my $transfer1 = qq|INSERT INTO tm_message SELECT created, ts, messageid, '', author, '', msgheader, msgbody FROM ${tables}_data|;
	my $transfer2 = qq|INSERT INTO tm_bug_message SELECT ticketid, messageid FROM ${tables}_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_fix += $i_ok = $self->action($tables, $store, $create1, $create2, $transfer1, $transfer2);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
} 

sub x7 { # tm_tickets -> tm_bug
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	
	my ($sub, $tables) = ('x7', 'tm_tickets');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM $tables");
	
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_bug (
		created datetime,
		ts timestamp(14),
		bugid varchar(12) DEFAULT '' NOT NULL,
		subject varchar(100),
		sourceaddr varchar(100),
		toaddr varchar(100),
		status varchar(16) DEFAULT '' NOT NULL,
		severity varchar(16),
		category varchar(16),
		fixed varchar(16),
		version varchar(16),
		osname varchar(16),  	# use instead
		PRIMARY KEY (bugid)
);|;
	my $transfer = qq|INSERT INTO tm_bug 
		SELECT created, ts, ticketid, subject, sourceaddr, destaddr, status, severity, category, fixed, version, osname 
		FROM ${tables}_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_fix += $i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

sub x8 { # users
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x8', 'tm_users');
	$self->result("fixing($FIX) $sub $tables");
	
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT userid FROM tm_users");
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_user (
		created datetime,
		ts timestamp(14),
		userid varchar(16) DEFAULT '' NOT NULL,
		password varchar(16),
		address varchar(100),
		name varchar(50),
		match_address varchar(150),
		active char(1),
		PRIMARY KEY userid (userid)
);|;
	my $transfer = qq|INSERT INTO tm_user
		SELECT now(), NULL, userid, password, address, name, match_address, active 
		FROM ${tables}_data|;
	 
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
} 

sub x9 { # id
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x9', 'tm_id');
	$self->result("fixing($FIX) $sub $tables");
	
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT * FROM $tables");
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_id (
		bugid varchar(12) DEFAULT '' NOT NULL,
		PRIMARY KEY (bugid)
);|;
	my $transfer = qq|INSERT INTO tm_id SELECT ticketid FROM ${tables}_data|;
	 
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
} 

=item x99

Remove MIGRATE deadwood if everythings is OK

=cut

sub x99 { # x99
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @args = @_;
	my @res  = ();
	my $i_ok = 1;
	my $rows = 0;
	my ($sub, $tables) = ('x99', 'drop tables');
	$self->result("fixing($FIX) $sub $tables");
	
	my @drops = (
		'DROP TABLE admingroups',
		'DROP table tm_cc_data',
		'DROP table tm_claimants_data',
		'DROP table tm_id_data',
		'DROP table tm_log_data',
		'DROP table tm_messages_data',
		'DROP table tm_notes_data',
		'DROP table tm_patches_data',
		'DROP TABLE tm_patch_ticket',
		'DROP table tm_spam',
		'DROP TABLE tm_tests_data',
		'DROP TABLE tm_test_ticket',
		'DROP table tm_tickets_data',
		'DROP table tm_users_data',
	);
	
	if (@drops >= 1) {
		if ($FIX) {
			$i_ok = $self->action($tables, @drops);
			$self->result("Remember to fix Base::check_user->tm_user(s)");
		} else {
			$self->result("$sub has ".@drops." tables to fix(@args)");
		} 
	} else {
		$self->result("nothing to do (".@drops.")");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

# end migration
# ------------------------------------------------------------------------------

=item x31

Update tm_claimants from tm_logs by userid

=cut

sub x31 { # tm_claimants
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @args = @_;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) tm_claimants from tm_logs(@args)");
	my $target = 'tm_claimants';
	
	my @ok = $self->get_list("SELECT ticketid FROM $target WHERE userid = '$_[0]'");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT objectid FROM tm_log WHERE userid = '$[0]' AND objecttype = 't'");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $ROWS = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			foreach my $tid (@notok) {
				my $sql = "INSERT INTO $target values (now(), '$tid', '$_[0]')";
				my $sth = $self->exec($sql);
				$ROWS += my $rows = $sth->rows;
				$self->result("$target inserted $rows rows");
				$self->track('f', 'update2claimant?', $sql);
			}
			$self->result("$target fixed $ROWS records");
		} else {
			$self->result("$target has ".@notok." records to fix(@args)");
		} 
	} else {
		$self->result("nothing to do (@notok)");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

=item x32

Assumes bugids in db, messages in dir, find messages which were not forwarded, forward them.

Not the same as an historic trawl, which is looking for new/replies, etc.

=cut

sub x32 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) x32");
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_tickets WHERE status = 'open'");
	my $targs = join("', '", @targs);
	
	my $i_fix = 0;
	my %noticed = $self->messageids_in_dirs($self->directory('mailinglists'));
	foreach my $tid (@targs) {
		my $get = "SELECT messageid FROM tm_messages WHERE ticketid = '$tid'";
		my @got = $self->get_list($get);
		if (scalar(@got) == 1) { # some reason for this.
			my ($header) = $self->get_list("SELECT msgheader FROM tm_messages WHERE ticketid = '$tid'");
			if ($header =~ /^Message-Id:\s*(.+)\s*$/msi) {
				my $mid = $1;
				if (grep(/^$mid$/i, keys %noticed)) {
					$self->result("tid($tid) was forwarded($mid) and ignored");
				} else {
					if ($FIX) {
						$self->result("forwarding lost($tid) message($mid)");
						my ($h_data) = $self->get_data("SELECT * FROM tm_messages WHERE ticketid = '$tid'");
						my $o_mail = $self->convert_db2mail($h_data);
						if (ref($o_mail)) { # Notify p5p ...
							my ($o_hdr, $header, $body) = $self->splice($o_mail);
        					my $o_fwd = $self->get_header($o_hdr, 'remap');
							my $i_ok = $self->send_mail($o_fwd, $body); 
        					my $msg = ($i_ok == 1) ? "Re-notified OK" : "Failed($i_ok) to re-notify with original header($header)";             
        					$self->result($msg);
							$i_fix += $i_ok;
    					} else {
							$self->result("Failed to retrieve mail object($o_mail) from database with tid($tid)");
						}
					} else {
						$self->result("tid($tid) has lost message($mid)");
					}
				}
			} else {
				$self->result("Couldn't get message-id($1) for tid($tid) from header($header)");
			}
		}
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item xspecial

Specials

=cut

sub xspecial { # xspecials
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @args = @_;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) xspecials(@args) -> zip");
	return 1;
	
	my $target = 'tm_claimants';
	
	my @ok = $self->get_list("SELECT ticketid FROM $target WHERE userid = '$_[0]'");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT objectid FROM tm_log WHERE userid = '$[0]' AND objecttype = 't'");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $ROWS = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			foreach my $tid (@notok) {
				my $sql = "INSERT INTO $target values (now(), '$tid', '$_[0]')";
				my $sth = $self->exec($sql);
				$ROWS += my $rows = $sth->rows;
				$self->result("$target inserted $rows rows");
				$self->track('f', 'update2claimant?', $sql);
			}
			$self->result("$target fixed $ROWS records");
		} else {
			$self->result("$target has ".@notok." records to fix(@args)");
		} 
	} else {
		$self->result("nothing to do (@notok)");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;
