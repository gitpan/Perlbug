# $Id: Fix.pm,v 1.6 2000/08/10 10:50:40 perlbug Exp perlbug $ 

=head1 NAME

Perlbug::Fix - Command line interface to fixing perlbug database.

=cut

package Perlbug::Fix;
use Data::Dumper;
# use Getopt::Std;
use File::Spec; 
use lib File::Spec->updir;
use Perlbug::Cmd;
@ISA = qw(Perlbug::Cmd);
use strict;
use vars qw($VERSION);
$VERSION = 1.03;
$|=1;

my %ARG = (
    "h" => '', "t" => 0, 'd' => 0, 'p' => '', 'u' => '',
);
# getopts('htdpu:', \%ARG);      


=head1 DESCRIPTION

Command line interface to fixing incorrect perlbug data.

=head1 SYNOPSIS

    datafix
	
	> h		# help
	
	> H		# Helpful help
	
	> f		# view erroneous flags
	
	> F		# Fix erroneous flags
	
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
	'p' => 'patches',	'ph' => 'trashes patch_ticket relationship where no (bugid|patchid)',
	'q' => 'doq',	    'qh' => 'query the database (Q for the schema)',
  # 't' => 'tests',	    'th' => 'deletes non-valid tests',
    'u' => 'user',
  	'x' => 'xspecial',  'xh' => 'xtra-special runs -> ?',
  	'x1' => 'x1',       'x1h' => 'update tm_claimants from tm_logs by userid',
    'x2' => 'x2',		'x2h' => 'mails that were new but did not make it out to p5p',
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
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_notes");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "DELETE FROM tm_notes WHERE ticketid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows = $sth->rows;
			$self->result("tm_notes removed($rows) non-existent bug references");
			$self->track('f', 'tid2notes?', $sql);
		} else {
			$self->result("tm_notes have ".@notok." non-existent bug references");
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
	
	my @ok = $self->get_list("SELECT patchid FROM tm_patches");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT patchid FROM tm_patch_ticket");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	my $notok = join("', '", @notok);
	
	$self->debug(1, "ok($ok), notok($notok)");
	$self->result("ok(".@ok."), notok(".@notok.")");
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "DELETE FROM tm_patch_ticket WHERE patchid IN ('$notok')";
			my $sth = $self->exec($sql);
			$rows= $sth->rows;
			$self->result("tm_patch_ticket removed($rows) non-existent patchid references");
			$self->track('f', 'patch2tid?', $sql);
		} else {
			$self->result("tm_patch_ticket has ".@notok." non-existent patchid references");
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


=item x1

Update tm_claimants from tm_logs by userid

=cut

sub x1 { # x1
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
				my $sql = "INSERT INTO $target values (NULL, '$tid', '$_[0]')";
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

=item x2

Assumes bugids in db, messages in dir, find messages which were not forwarded, forward them.

Not the same as an historic trawl, which is looking for new/replies, etc.

=cut

sub x2 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	$self->result("fixing($FIX) x2");
	
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
				my $sql = "INSERT INTO $target values (NULL, '$tid', '$_[0]')";
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
