# Perlbug functions
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Do.pm,v 1.28 2000/08/10 10:43:24 perlbug Exp perlbug $
#
# CREATE TABLE tm_parent_child ( parentid varchar(12) DEFAULT '' NOT NULL, childid varchar(12) DEFAULT '' NOT NULL);
# 

=head1 NAME

Perlbug::Do - Commands (switches) for generic interface to perlbug database.

=cut

package Perlbug::Do; 
use Data::Dumper;
use File::Spec; 
use lib File::Spec->updir;
# use Mail::Internet;
# use Mail::Address;
# use Mail::Send;
use strict;
use vars qw($VERSION);
$| = 1; 

$VERSION = 1.27;

=head1 DESCRIPTION

Methods for various functions against the perlbug database.  

=cut


=head1 SYNOPSIS

Use like this:

	$o_obj->dod(2); # set debug level to '2'
	
=head1 METHODS

=over 2


=item new

Create new Perlbug::Do object:

	my $do = Perlbug::Do->new();

=cut

sub new { # 
    my $proto = shift;
   	my $class = ref($proto) || $proto; 
   	bless({}, $class);
}


=item get_switches

Returns array of current switches, rather than string

	my @switches = $o_mail->get_switches('user');

=cut

sub get_switches { # current or admin|user
    my $self = shift;
	$self->debug('IN', @_);
	my $arg  = shift || '';
	my @switches = ();
	if ($arg eq 'admin') {
		@switches = split(//, $self->system('admin_switches'));
	} elsif ($arg eq 'user') {
		@switches = split(//, $self->system('user_switches'));
	} else {
		@switches = split(//, $self->current('switches'));
	}
	@switches = grep(/^\w$/, @switches);
	$self->debug('OUT', @switches);
    return @switches;
}


=item doh

Returns help message built from a hash_ref, commands may be overwritten by sending in a hash.

Syntax for the hash is 'key => description (sample args)':

	$o_obj->doh({
		'e' => 'email me a copy too (email@address.com)', 	# add
		'H' => 'Help - more detailed info ()',				# replace
		'z' => '', 											# unrequired
	});

=cut

sub doh { # command line help
    my $self = shift;
	$self->debug('IN', @_);
    $self->start('-h');
	my $data = qq|
Switches are sent on the subject line, dash may be omitted if only option:
--------------------------------------------------------------------------------
|;
	# A = Admin
	# B = Bugmaster
	# C = Cc list (or master list or admin)
	# 
	my %data = (
		'a' => 'administration command - cmds bugids      (close b 19990606.002 [...])',	# A
		'A' => 'Administration command and return bugs    (c build 19990606.002 [...])', 	# A
		'b' => 'bug retrieval by bugid                    (19990606.002 [...])', 
		'B' => 'bug retrieval including messages          (19990606.002 [...])', 
		'c' => 'category bug retrieval, status, etc.      ([status/ctgry/sev...])', 
		'C' => 'Category as per -B                        ([status/ctgry/sev...])', 
		'd' => 'debug flag data goes in logfile           ()', 								# A
		'D' => 'Dump database for backup                  ()',    							# A
	  # 'e' => 'copy', 
		'f' => 'format of data ascii|html|lean            ([aA|hH|l])', 
	  # 'g' => '',
      ##'i' => 'initiate new admin - inc. htpasswd        (-i)',								# B
		'h' => 'help - this message                       ()', 
		'H' => 'more detailed help                        ()',
	  # 'j' => '', 
	    'k' => 'claim a bug with optional email addr      (19990606.002 me@here.net [...])',# C
		'K' => 'unClaim this bug - remove from cc         (19990606.002 me@here.net [...])',# C
		'l' => 'log of current process                    ()', 								# A
		'L' => 'Logfile - todays complete retrieval       ()', 								# A
		'm' => 'retrieval by messageid                    (13 47 23 [...])', 
		'n' => 'note retrieval                            (76 33 1  [...])',
	  # 'N' => 'INSERT a Note against a bugid             (19990606.002 some_note)',
		'o' => 'overview of bugs in db                    ()', 
	    'p' => 'patch retrieval                           (patchid)', # change
	  # 'P' => 'INSERT input',
	  	'q' => 'query the db directly                     (select * from tm_flags where 1 = 0)', 
		'Q' => 'Query the schema for the db               ()', 
		'r' => 'body search criteria                      (d_sigaction=define)', 
		'R' => 'body search criteria as per -B            (d_sigaction=define)', 
		's' => 'subject search by literal                 (bug in docs)', 
		'S' => 'Subject search as per -B                  (bug in docs)', 
	    't' => 'test retrieval by testid                  (77 [...])', 
	  # 'T' => 'INSERT a Test against a bugid|patch       (19990606.002 test|patch)', 
		'u' => 'user retrieval by userid                  (richardf [...])', 				# A
	  	'v' => 'volunteer bug category etc.               (19990606.002 close)',
	  # 'V' => 'Volunteer as admin',  
		'x' => 'xterminate bug - remove bug               (19990606.002 [...])', 			# A
		'X' => 'Xterminate bug - and messages             (19990606.002 [...])', 			# A
	  # 'y' => 'xxx',
	  ##'z' => 'Disable interface or update script  		(-z)',							# B
		@_,																					# Overwrite
	);
	SWITCH:
    foreach my $key (sort { lc($a) cmp lc($b) } keys %data) {
		next SWITCH unless grep(/^$key$/, $self->get_switches); # 
		next SWITCH unless $key =~ /^\w$/;
		if ($data{$key} =~ /^\s*(.+)\s*(?:\((.*)\))\s*$/) {
			my ($desc, $args) = ($1, $2);
			$desc =~ s/\s+/ /g;
			$args =~ s/\s+/ /g;
			my $combo = length($desc) + length($args);
			my $x = ($combo >= 1 && $combo <= 70) ? 71 - $combo : 1; # allow 9 for wrapping (may run over)
			my $spaces = ' ' x $x;
			$data .= "$key = $desc".$spaces."(-$key $args)"."\n"; 	 # 80?
		}
	}
    # 
	$self->debug(3, 'help retrieved');    
    $self->result($data, 0);
    $self->finish;
	$self->debug('OUT', length($data));
	return $data;
}


=item dod

Switches debugging on (1).

=cut

sub dod { # debug
    my $self = shift;
	$self->debug('IN', @_);
    my ($d) = @_;
	my $i_ok = 1;
    my $level = (@{$d}[0] =~ /^\d$/) ? @{$d}[0] : 1;
    if ($level =~ /\d/) {
		$Perlbug::Debug = $level;
        $self->current('debug', $level);
        $self->debug(2, "Debugging ($level) switched on");
		$self->result("Debug level($level) set");
    }
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doD

Dumps database for backup and recovery.

=cut

sub doD { # Dump Database (for recovery)
    my $self = shift;
	$self->debug('IN', @_);
    my $ok = 1;
	my $admin = $self->isadmin;
    $self->debug(0, "DB dump requested by '$admin'");
	# 
	my $adir = $self->directory('arch');
	my $date = $self->current('date');
	my $tdir = $self->directory('spool').'/temp';
	my $pdir = $self->directory('perlbug');
	my $dump = $self->database('backup');
	my $last = File::Spec->canonpath($tdir.'/'.$self->database('latest'));
	$last =~ s/^(.+?\.)gz/${1}$date/;
	my $arch = File::Spec->canonpath($adir."/Perlbug.sql.gz.${date}");
	my $lach = File::Spec->canonpath($adir.'/'.$self->database('latest'));
	my $dage = $self->database('backup_age');
	#
	if ((-e $last) && (-M _ >= $dage)) {
		$self->debug(1, "Recent database dump($last) found: $dage days old");
	} else {
		if ($dump =~ s/^(.+)\s*latest$/$1 $last/) { # passauf!
			$dump =~ s/\s+/ /g;
			my $res = !system($dump); 	# doit
			$self->debug(0, "Database dump($dump) -> res($res)");
			$self->result("Database dump res($res)");
			if ($res == 1 && -f $last) {
				$ok = $self->copy($last, $arch);
				$self->debug(0, "database backup copy: $ok");
				$ok = $self->link($arch, $lach, '-f');
				$self->debug(0, "database backup link: $ok");
			} else {
				$self->debug(0, "Looks like database backup failed: $? $!");
			}
		} else {
			$self->debug(0, "Duff looking database dump command: '$dump'");
		}
	}
	$self->debug('OUT', $ok);
	return $ok;
}


=item dom

Return the given message(id), places the L<Perlbug/format>ed result in to the
results array.

    my $res = $do->dom([@messageids]);

=cut

sub dom { # retrieve message by id
	my $self = shift;
	$self->debug('IN', @_);
	my ($input) = @_;
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	$self->start("-m @args");
	my $i_ok = 0;
	foreach my $i (@args) {
	    next unless $i =~ /^\d+$/;
	    $self->debug(3, "message id=$i");
	    my $sql = "SELECT * FROM tm_messages WHERE messageid = '$i'";
	    my ($data) = $self->get_data($sql);
	    if (ref($data) eq 'HASH') {
			$i_ok += my $res = $self->format_data($data);
       	 	$self->debug(2, "message($i) $i_ok");
		} else {
			$self->result("No message found with messageid($i)");
		}
	} 
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item dop

Return the given patch(id), places the L<Perlbug/format>ed result in to the
results array.

    my $res = $do->dop([@patchids]);

=cut

sub dop { # get patch by id
	my $self = shift;
	$self->debug('IN', @_);
	my ($input) = @_;
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	$self->start("-p @args");
	my $i_ok = 0;
	foreach my $i (@args) {
	    next unless $i =~ /^\d+$/;
	    $self->debug(3, "patchid=$i");
	    my $sql = "SELECT * FROM tm_patches WHERE patchid = '$i'";
	    my ($data) = $self->get_data($sql);
		if (ref($data) eq 'HASH') {
			my @bids = $self->get_list("SELECT DISTINCT ticketid FROM tm_patch_ticket WHERE patchid = '$i'");
			$$data{'bugids'} = \@bids;
	    	$i_ok += my $res = $self->format_data($data);
       		$self->debug(2, "patch($i) $i_ok");
		} else {
			$self->result("No patch found with patchid($i)");
		}
	} 
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doP

Assign to given bugid, given patch, return i_ok

	$i_ok = $o_obj->doP('tid_chid_versid', 'patch...here', 'hdr', 'sbj', 'frm', 'to);

=cut

sub doP {
	my $self  = shift;
    $self->debug('IN', @_);
	my $str  = shift;
	my $patch= shift;
	my $hdr  = shift || '';
	my $subj = shift || '';
	my $frm  = shift || '';
	my $to   = shift || '';
	$str = (ref($str) eq 'ARRAY') ? @{$str} : ($str);
	my $patchid = '';
	my $i_ok    = 1;
	my %cmds = $self->parse_str($str);
	if ($patch !~ /\w+/) {
		$i_ok = 0;
		$self->debug(0, "requires a valid patch($patch) to insert");
	} else {
		my $qpatch = $self->quote($patch);
		my ($version) = @{$cmds{'versions'}};
		my ($changeid)= @{$cmds{'changeids'}};
		my @unknown = @{$cmds{'unknown'}};
		my $qsubject = $self->quote($subj);
		my $qfrom = $self->quote($frm);
		my $qto = $self->quote($to);
		my $qheader = $self->quote($hdr);
		my $insert = qq|INSERT INTO tm_patches VALUES 
			(NULL, now(), NULL, $qsubject, $qfrom, $qto, '$changeid', '$version', $qheader, $qpatch)
		|;
		my $tsth = $self->exec($insert);
		if (!defined($tsth)) {
			$i_ok = 0;
			$self->debug(0, "failed to insert patch($insert)");		
		} else {
			my $getpatch = qq|SELECT MAX(patchid) FROM tm_patches WHERE msgbody = $qpatch|; # blech
			($patchid) = $self->get_list($getpatch); # = $tsth->last_inserted_id;
			if ($patchid !~ /\w+/) {
				$i_ok = 0;
				$self->debug(0, "failed to retrieve patchid($patch)");
			} else {
				$self->result("patch($patchid) inserted");
				$self->track('p', $patchid, $insert);
				if (ref($cmds{'bugids'}) eq 'ARRAY') {
					my @bids = ();
					BID:
					foreach my $bid (@{$cmds{'bugids'}}) { 
						next BID unless $bid =~ /\w+/;
						if (!$self->exists($bid)) {
							$self->result("bugid($bid) doesn't exist for patch($patchid)");
						} else {
							push(@bids, $bid);
							my $insert = qq|INSERT INTO tm_patch_ticket VALUES (NULL, now(), '$patchid', '$bid')|;
							my $ptsth = $self->exec($insert);
							if (!defined($ptsth)) {
								$i_ok = 0;
								$self->debug(0, "failed to insert tm_patch_ticket($insert)");
							} 
						}
					}
					$self->debug(1, "assigned patch($patchid) to bugids(@bids)");
				}
			}
		}
	}
	$self->debug('OUT', $patchid);
	return $patchid;
}


=item dot

Return the given test(id), places the L<Perlbug/format>ed result in to the
results array.

    my $res = $do->dot([@testids]);

=cut

sub dot { # get test by id
	my $self = shift;
	$self->debug('IN', @_);
	my ($input) = @_;
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	$self->start("-t @args");
	my $i_ok = 0;
	foreach my $i (@args) {
	    next unless $i =~ /^\d+$/;
	    $self->debug(3, "testid=$i");
	    my $sql = "SELECT * FROM tm_tests WHERE testid = '$i'";
	    my ($data) = $self->get_data($sql);
		if (ref($data) eq 'HASH') {
			my @bids = $self->get_list("SELECT DISTINCT ticketid FROM tm_test_ticket WHERE testid = '$i'");
			$$data{'bugids'} = \@bids;
	    	$i_ok += my $res = $self->format_data($data);
			# print "Patch:".Dumper($data);
	    	$self->debug(3, "test formatted($res)");
		} else {
			$self->result("No test found with testid($i)");
		}
	} 
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doT

Assign to given bugid, given test, return i_ok

	$i_ok = $o_obj->doT('tid_chid_versid', 'test...here', 'hdr', 'sbj', 'frm', 'to);

=cut

sub doT {
	my $self  = shift;
    $self->debug('IN', @_);
	my $str  = shift;
	my $test = shift;
	my $hdr  = shift || '';
	my $subj = shift || '';
	my $frm  = shift || '';
	my $to   = shift || '';
	($str) = (ref($str) eq 'ARRAY') ? @{$str} : ($str);
	my $testid = '';
	my $i_ok   = 1;
	my %cmds = $self->parse_str($str);
	if ($test !~ /\w+/) {
		$i_ok = 0;
		$self->debug(0, "requires a valid test($test) to insert");
	} else {
		my $qtest = $self->quote($test);
		my ($version) = @{$cmds{'versions'}};
		my ($changeid)= @{$cmds{'changeids'}};
		my @unknown = @{$cmds{'unknown'}};
		my $qsubject = $self->quote($subj);
		my $qfrom = $self->quote($frm);
		my $qto = $self->quote($to);
		my $qheader = $self->quote($hdr);
		my $insert = qq|INSERT INTO tm_tests VALUES 
			(NULL, now(), NULL, $qsubject, $qfrom, $qto, '$changeid', '$version', $qheader, $qtest)
		|;
		my $tsth = $self->exec($insert);
		if (!defined($tsth)) {
			$i_ok = 0;
			$self->debug(0, "failed to insert test($insert)");		
		} else {
			my $gettest = qq|SELECT MAX(testid) FROM tm_tests WHERE msgbody = $qtest|; # blech
			($testid) = $self->get_list($gettest); # = $tsth->last_inserted_id;
			if ($testid !~ /\w+/) {
				$i_ok = 0;
				$self->debug(0, "failed to retrieve testid($test)");
			} else {
				$self->result("test($testid) inserted");
				$self->track('t', $testid, $insert);
				if (ref($cmds{'bugids'}) eq 'ARRAY') {
					my @bids = ();
					BID:
					foreach my $bid (@{$cmds{'bugids'}}) { 
						next BID unless $bid =~ /\w+/;
						if (!$self->exists($bid)) {
							$self->result("bugid($bid) doesn't exist for test($testid)");
						} else {
							push(@bids, $bid);
							my $insert = qq|INSERT INTO tm_test_ticket VALUES (NULL, now(), '$testid', '$bid')|;
							my $ptsth = $self->exec($insert);
							if (!defined($ptsth)) {
								$i_ok = 0;
								$self->debug(0, "failed to insert tm_test_ticket($insert)");
							} 
						}
					}
					$self->debug(1, "assigned test($testid) to bugids(@bids)");
				}
			}
		}
	}
	$self->debug('OUT', $testid);
	return $testid;
}



=item dob

Return the given bug(id), places the L<Perlbug/format>ed result in to the 
result array.

    my $i_bugs = $do->dob([@bugids]);
    
    # $i_bugs = num of bugs succesfully processed

=cut

sub dob { # get bug by id 
	my $self = shift;
	$self->debug('IN', @_);
	my ($t) = @_;
	my @tkts = (ref($t) eq 'ARRAY') ? @{$t} : ($t);
	# $#tkts = 9; # reduce number of bugs at any one time...
	my $fnd = 0;
	foreach my $i (@tkts) {
	    $self->start("-t $i");
		next unless $self->ok($i);
		# Bug
		my $get_tkt = "SELECT * FROM tm_tickets WHERE ticketid = '$i'";
		my ($h_tkt) = $self->get_data($get_tkt);
		if (ref($h_tkt) ne 'HASH') {
			$self->result("No bug found with bugid($i)");
		} else {
			# Messages
			my @mids = $self->get_list("SELECT messageid FROM tm_messages WHERE ticketid = '$i'");
			$$h_tkt{'messageids'} = \@mids;
			$$h_tkt{'i_mids'} = @mids;
			# Admins
			my @admins = $self->get_list("SELECT DISTINCT userid FROM tm_claimants WHERE ticketid = '$i'");
			$$h_tkt{'admins'} = \@admins;
			# Message
    		my ($mid) = sort {$a <=> $b} @mids; # lowest -> first    
			($$h_tkt{'msgbody'}) = $self->get_list("SELECT msgbody FROM tm_messages WHERE messageid = '$mid' ");
			# Ccs
			my @ccs = $self->get_list("SELECT DISTINCT address FROM tm_cc WHERE ticketid = '$i'");
			$$h_tkt{'ccs'} = \@ccs;
			# Parents
			my @parents = $self->get_list("SELECT parentid FROM tm_parent_child WHERE childid = '$i'");
			$$h_tkt{'parents'} = \@parents;
			# Children
			my @children = $self->get_list("SELECT childid FROM tm_parent_child WHERE parentid = '$i'");
			$$h_tkt{'children'} = \@children;
			# Patches
			my @pids = $self->get_list("SELECT patchid FROM tm_patch_ticket WHERE ticketid = '$i'");
			$$h_tkt{'patches'} = \@pids; 
			$$h_tkt{'i_pids'} = @pids;
			# Notes
			my @nids = $self->get_list("SELECT noteid FROM tm_notes WHERE ticketid = '$i'");
			$$h_tkt{'notes'} = \@nids;
			$$h_tkt{'i_nids'} = @nids;
			my @tids = $self->get_list("SELECT testid FROM tm_test_ticket WHERE ticketid = '$i'");
			$$h_tkt{'tests'} = \@tids; 
			$$h_tkt{'i_tids'} = @tids;
			if (scalar(@nids == 1))  {
				($$h_tkt{'note'}) = $self->get_list("SELECT msgbody FROM tm_notes WHERE ticketid = '$i'");
			}
			$self->debug(3, "dob($i) admins(@admins), msgids(@mids), parent(@parents), children(@children), ccs(@ccs), patches(@pids), notes(@nids)");
			if (ref($h_tkt) eq 'HASH') { 
	    		my $res = $self->format_data($h_tkt);
		    	$self->debug(3, "bug($i) $fnd");
		    	$fnd++;
			} 
		}
	}
	# print "found($fnd)\n";
	$self->result('No bugs found') unless $fnd >= 1;
	$self->finish;
	$self->debug('OUT', $fnd);
	return $fnd;
}


=item doB

Return the given bug(id), with all the messages assigned to it, calls dob()

    my $i_bugs = $do->doB([@bugids]);
    
    # $i_bugs = num of bugs succesfully processed

=cut

sub doB { # get bug by id (large format)
    my $self 	= shift;
	$self->debug('IN', @_);
    my $input 	= shift;
    my $sep 	= shift;
    my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
    $self->start("-B @args");
    my $fnd = 0;
    foreach my $bid (@args) {
        # one normally
        $fnd = $self->dob($bid);
    	$self->result($sep) if defined($sep); # kludge!
		
        my $msql = "SELECT messageid FROM tm_messages WHERE ticketid = '$bid'";
        my @mids = $self->get_list($msql);
        my $i_m = $self->dom(\@mids);
		
		my $nsql = "SELECT noteid FROM tm_notes WHERE ticketid = '$bid'";
        my @nids = $self->get_list($nsql);
        my $i_n = $self->don(\@nids);
		
		my $psql = "SELECT patchid FROM tm_patch_ticket WHERE ticketid = '$bid'";
        my @pids = $self->get_list($psql);
        my $i_p = $self->dop(\@pids);
		
		my $tsql = "SELECT testid FROM tm_test_ticket WHERE ticketid = '$bid'";
        my @tids = $self->get_list($tsql);
        my $i_t = $self->dot(\@tids);
    }

    $self->finish;
	$fnd = ($fnd >= 1) ? 1 : 0;
	$self->debug('OUT', $fnd);
    return $fnd;
}


=item dou

Get the given user, checks if active
    
    print $o_do->dou($userid);

=cut

sub dou { # get user by id
    my $self = shift;
	$self->debug('IN', @_);
    my $args = shift;
    my @uids = (ref($args) eq 'ARRAY') ? @{$args} : $args;
    $self->start("-u @uids");
    my $fnd = 0;
    foreach my $uid (@uids) {
        next unless $uid =~ /^\w+$/;
        my $sql = "SELECT * FROM tm_users WHERE userid = '$uid' AND active = '1' OR active = '0'";
		if ($self->isadmin eq $self->system('bugmaster')) {
			$sql .= " OR active IS NULL";
		}
        #my ($h_user) = $self->get_data($sql);
		my ($h_user) = $self->user_data($uid);
        if ((ref($h_user) eq 'HASH') && ($$h_user{'userid'} eq $uid)) {
            if (grep(/^$$h_user{'userid'}$/, $self->active_admins)) {
                $$h_user{'active'} = 1;
            }
            my $res = $self->format_data($h_user);
            $fnd++;
        } else {
			$self->result("No user found with userid($uid)");
		}
        $self->debug(2, "user($uid) $fnd");
    }
    $self->finish;
	$self->debug('OUT', $fnd);
    return $fnd;
}


=item doc

Retrieve bug based on the existing category, severity or status flags.

    my $res = $do->doc('open build');

=cut

sub doc { # category retrieval -b
	my $self = shift;
	$self->debug('IN', @_);
	my ($input, $borB) = @_;
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	# ($args[0] == 1) && ($args[0] = undef);
	my $str = join(' ', @args);
	$self->start("-r @args"); 
	my $sql = "SELECT ticketid FROM tm_tickets WHERE ticketid IS NOT NULL";
	$sql .= $self->parse_flags($str, 'AND');
    $self->debug(2, "parsed sql($sql)");
	my @data = $self->get_list($sql);
	my $i_ok = 0;
	if (defined($borB) && $borB eq 'B') {
	    $i_ok = $self->doB(\@data);
	} else {
    	$i_ok = $self->dob(\@data);
	}
	$self->finish;
	
	$self->debug('OUT', $i_ok);
	return ($i_ok);
}


=item doC

Retrieve messages, as per doB() where category, severity or status fulfills the following optional flags:
o (open), c (closed), b (build), p (patch), u (utilities) ...

Wrapper for l<doc>.

=cut

sub doC { # Retrieve -B
    my $self = shift;
	$self->debug('IN', @_);
    my ($input) = @_;
    my @ref = (ref($input) eq 'ARRAY') ? @{$input} : $input;
    $self->start("-R @ref");
	my $i_ok = $self->doc($input, 'B');
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item dos

Retrieve data based on the subject line of a bug

    my $res = $do->dos('open build');

=cut

sub dos { # subject -b
	my $self   = shift;
	$self->debug('IN', @_);
	my $input  = shift;
	my $borB   = shift || '';
	my $i_ok   = 0;
	my ($crit) = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	$self->start("-s $crit $borB"); 
	my $sql = "SELECT DISTINCT ticketid FROM tm_tickets WHERE ticketid IS NOT NULL AND subject LIKE '%$crit%'";
	my @bids = $self->get_list($sql);
	# should return tids associated with query, next step should dob|B ...
	if (defined($borB) && $borB eq 'B') {
	    $i_ok = $self->doB(\@bids);
	} else {
    	$i_ok = $self->dob(\@bids);
	}
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

sub doS {
	my $self  = shift;
	$self->debug('IN', @_);
	my $args = shift;
	my $i_ok = $self->dos($args, 'B');
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

=item dor

Retrieve data based on contents of the Body of a message

    my $res = $do->dor('open build');

=cut

sub dor { # retrieve in body 
	my $self   = shift;
	$self->debug('IN', @_);
	my $input  = shift;
	my $borB   = shift  || '';
	my ($crit) = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	$self->start("-b $crit $borB"); 
	my $sql = "SELECT DISTINCT ticketid FROM tm_messages WHERE ticketid IS NOT NULL AND msgbody LIKE '%$crit%'";
	my @bids = $self->get_list($sql);
	# should return bugids associated with query, next step should dob|B ...
	my $i_ok = 0;
	if (defined($borB) && $borB eq 'B') {
	    $i_ok = $self->dob(\@bids);
	} else {
    	$i_ok = $self->dob(\@bids);
	}
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


sub doR {
	my $self  = shift;
	$self->debug('IN', @_);
	my $i_ok = $self->doR($_[0], 'B');
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item don

Get the note for this noteid

=cut

sub don {
	my $self = shift;
	$self->debug('IN', @_);
	my $input = shift;
	my @nids = (ref($input) eq 'ARRAY') ? @{$input} : ($input);
	$self->start("-n @nids"); 
	my $fnd = 0;
	foreach my $nid (@nids) {
        next unless $nid =~ /^\d+$/;
        my $sql = "SELECT * FROM tm_notes WHERE noteid = '$nid'";
	    my ($h_note) = $self->get_data($sql);
		if ((ref($h_note) eq 'HASH') && ($$h_note{'noteid'} eq $nid)) {
            my $res = $self->format_data($h_note);
            $fnd++;
        } else {
			$self->result("No note found with noteid($nid)");
		}
        $self->debug(2, "note($nid) $fnd");
    }
    $self->finish;
	$self->debug('OUT', $fnd);
	return $fnd;
}


=item doN

Assign to given bugid, given notes, return $i_ok

=cut

sub doN {
	my $self  = shift;
    $self->debug('IN', @_);
	my $input = shift;
	my $xnote = shift || '';
	my $xhdr  = shift || '';
	my ($tid, $note, $hdr) = (ref($input) eq 'ARRAY') ? @{$input} : ($input, $xnote, $xhdr);
	my $nid   = '';
	my $i_ok  = 1;
	if (!($self->ok($tid))) {
		$i_ok = 0;
		$self->debug(0, "tm_notes requires a valid bugid($tid)");
	} else {
		my $qnote = $self->quote($note);
		my $qhdr  = $self->quote($hdr);
		if (!$self->exists($tid)) {
			$i_ok = 0;
			$self->result("bug($tid) doesn't exist for insert of note($note) and hdr($hdr");
		} else {
			if ($note =~ /\w+/) {
				my $insert = "INSERT INTO tm_notes values (NULL, NULL, '$tid', NULL, 'x', '".$self->isadmin."', $qnote, $qhdr)";
				my $sth = $self->exec($insert);
				my $ok = $self->track('n', $tid, "assigned note($note)");
				$self->debug(1, "Assigned($tid) <- note($note))");
				($nid) = $self->get_list("SELECT MAX(noteid) FROM tm_notes WHERE msgbody = $qnote");	
				$self->result("Note($nid) assigned($i_ok) to tid($tid)");
			}	
		}
	}
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doq

Gets the sql _q_ query statement given in the body of the message, executes it, and
returns the result in the result array.

=cut

sub doq { # sql
    my $self = shift;
	$self->debug('IN', @_);
    my ($input) = @_;
	my $i_ok = 0;
    my ($sql) = (ref($input) eq 'ARRAY') ? @{$input} : $input;
    $sql =~ tr/\n\t\r/ /; 
    $sql =~ s/^(.+)?[\;\s]*$/$1/;
	$self->start("-q $sql");
    my ($errs, $res) = (0, undef);
    if (($self->isadmin eq $self->system('bugmaster'))){# && ($sql !~ /delete|drop/i)){
        # let it through for testing purposes
    } else {
        # could be a little paranoid, but...
	 	if ($sql =~ /\b(alter|create|delete|drop|file|grant|insert|rename|shutdown|update)\b/mi) {
	 		$self->result("You may not execute this sql ($1) from this interface");
			$errs++;
		} elsif ($sql !~ /^\s*select\s+/i)  { 
			$self->result("You may only execute SELECT statements ($sql) from this interface");
			$errs++;
		} else { 
			# OK
		}
    }
	if ($errs == 0) {   
		my $sth = $self->query($sql);
		if (defined($sth)) {
			$i_ok++;
			# my $maxlen  = $self->database('maxlen') || 1500;
			# my $lsep	= "\n";
			# my $fsep	= ",\t";
			# my $fh 		= $self->fh('res');
			# my $rows = $sth->dump_results($maxlen, $lsep, $fsep, $fh);
			my $str = $sth->as_string; # better? => Oracle?
			$self->result($str);
		} else {
			$self->debug(1, "No results($DBI::errstr) from '$sql'");
		}
	} else {
	    $self->debug(0, "DISALLOWED QUERY! = '$sql'");
	}
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doQ

Returns the database schema, for use with SQL statements.

=cut

sub doQ { # Schema
    my $self = shift;
	$self->debug('IN', @_);
	$self->start('-Q');
	my @tables = $self->get_list("SHOW tables FROM ".$self->database('database'));
	my %table;
	foreach my $t (@tables) {
	    next unless $t =~ /^\w+/;
	    $self->debug(3, "Schema table ($t)");
	    my $sql = "SHOW fields FROM $t";
    	my @fields = $self->get_data($sql);
    	foreach my $f (@fields) {
    	    my %f = %{$f} if ref($f) eq 'HASH';
			foreach my $key (qw(Field Type Null Key Default)) {
				$f{$key} = '' unless defined($f{$key});
			}
        	my @list = ($f{'Field'}, $f{'Type'}, $f{'Null'}, $f{'Key'}, $f{'Default'});
        	$self->debug(3, "Fields: @list");
        	$table{$t}{$f{'Field'}} = $f;
        }
	}
	my $i_ok = $self->format_schema(\%table); 
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doL

Returns the current (or given later) logfile.
	
=cut

sub doL { # Log (all)
	my $self = shift;
	$self->debug('IN', @_);
	my ($input) = @_;
    my ($given) = (ref($input) eq 'ARRAY') ? @{$input} : $input;
    ($given == 1) && ($given = 'today');
    $self->start("L $given");
	my $fh = $self->fh('log'); # , pb_log_\d{8}
	my $LOG = '';
	if (defined $fh) {
	    $fh->seek(0,0);
	    while (<$fh>) {
	        $LOG .= $_;
	    }
	    $fh->seek(0, 2);   
	    my $length = length($LOG);
	    $self->debug(2, "log ($fh) length ($length) read");
	} else {
        $self->debug(0, "Can't read LOG from undefined fh ($fh)");
    } 
	$self->result($LOG, 3);
	$self->finish;
	my $i_ok = (length($LOG) >= 1) ? 1 : 0;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item dol

Just the stored log results from this process.

=cut

sub dol { # log (this process)
    my $self = shift;
	$self->debug('IN', @_);
    $self->start('-l');
	my $fh = $self->fh('log');
	my ($line, $switch, $log, $cnt) = ('', 0, '', 0);
	if (defined $fh) {
        $fh->flush;
        $fh->seek(0, 0);
		while (<$fh>) {
    	    $line = $_;
			chomp($line);
    		if ($line =~ /^\[0\]\s*(.+)\s*(INIT)\s*\($$\)/i) {
				$switch++;
				# print "MATCHED -> '$line'\n\n";
    	    } 
    	    if ($switch >= 1) {         # record from here to end
    	        $log .= "$line\n";
    	        $cnt++;
    	    }
    	}
    	$fh->seek(0, 2);
    	$self->debug(2, "Retrieved $cnt lines from log");
    } else {
        $self->debug(0, "Can't read log from undefined fh ($fh)");
    }
	$self->result($log, 3);
    $self->finish;
	my $i_ok = (length($log) >= 1) ? 1 : 0;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item dof

Sets the appropriate format for use by L<Format> methods, overrides default 'a' set earlier.

	$o_obj->dof('h'); 

=cut

sub dof { # format setting
	my $self = shift;
	$self->debug('IN', @_);
	my ($fmt) = @_;
	my $format = (ref ($fmt) eq 'ARRAY') ? @{$fmt}[0] : $fmt;
	$format = ($format =~ /^[aAlhH]$/) ? $format : 'a'; 
	$format = $self->context($format);
	my $i_ok = ($self->current('format') eq $format) ? 1 : 0;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item stats

Get stats from db for overview usage.

	my $h_data = $self->stats;

=cut

sub stats {
    my $self = shift;
	$self->debug('IN', @_);
    my %over = (); 
    my $bugs                = "SELECT COUNT(ticketid) FROM tm_tickets";
    my $datediff            = "WHERE TO_DAYS(NOW()) - TO_DAYS(created)";
# BUGS
($over{'messages'})     = $self->get_list('SELECT COUNT(messageid) FROM tm_messages');
($over{'bugs'})      = $self->get_list("$bugs");
($over{'patches'})      = $self->get_list('SELECT COUNT(patchid) FROM tm_patches');
($over{'notes'})        = $self->get_list('SELECT COUNT(noteid) FROM tm_notes');
my @claimed             = $self->get_list("SELECT DISTINCT ticketid FROM tm_claimants");
$over{'claimed'}        = scalar @claimed; 
my $claimed             = join("', '", @claimed);
($over{'unclaimed'})    = $self->get_list("$bugs WHERE ticketid NOT IN ('$claimed')");
my @admins = $self->get_list('SELECT DISTINCT userid FROM tm_users');
$over{'administrators'}	= @admins;
foreach my $admin (@admins) {
	my ($cnt) = $self->get_list("SELECT COUNT(ticketid) FROM tm_claimants WHERE userid = '$admin'");
	$over{'admins'}{$admin} = $cnt;
}

# DATES
($over{'days1'})        = $self->get_list("$bugs $datediff <= 1");
($over{'days7'})        = $self->get_list("$bugs $datediff <= 7");
($over{'days30'})       = $self->get_list("$bugs $datediff <= 30");
($over{'days90'})       = $self->get_list("$bugs $datediff <= 90");
($over{'90plus'})       = $self->get_list("$bugs $datediff >= 90");

# FLAGS
my %flags = $self->all_flags;
foreach my $flag (keys %flags) { 
    $self->debug(4, "Overview flag: '$flag'");
    my @types = @{$flags{$flag}};
    foreach my $type (@types) {
		$self->debug(3, "Overview flag type: '$type'");
		my ($res) = $self->get_list("$bugs WHERE $flag = '$type'");
		$over{$flag}{$type} = $res || '';
		next if $flag eq 'status';
		my ($opres) = $self->get_list("$bugs WHERE $flag = '$type' AND status = 'open'");
		$over{$flag}{'Open'}{$type} = $opres || '';
    }
    # 
}

# RATIOS
# $fmt{'ratio_o2c'}, $fmt{'ratio_c2o'}, $fmt{'ratio_m2t'}, $fmt{'ratio_t2a'}
($over{'ratio_t2a'})    = sprintf("%0.2f", ($over{'bugs'}        / scalar(keys %{$over{'admins'}}))) if scalar(keys %{$over{'admins'}}) >= 1;
($over{'ratio_o2a'})    = sprintf("%0.2f", ($over{'status'}{'open'} / scalar(keys %{$over{'admins'}}))) if scalar(keys %{$over{'admins'}}) >= 1;
($over{'ratio_m2t'})    = sprintf("%0.2f", ($over{'messages'}       / $over{'bugs'})) if $over{'bugs'} >= 1;
($over{'ratio_o2c'})    = sprintf("%0.2f", ($over{'status'}{'open'} / $over{'status'}{'closed'})) if $over{'status'}{'closed'} >= 1;
($over{'ratio_c2o'})    = sprintf("%0.2f", ($over{'status'}{'closed'}/ $over{'status'}{'open'})) if $over{'status'}{'open'} >= 1;

	$self->debug('OUT', Dumper(\%over));
	return \%over;
}


=item doo

Returns a summary overview of the bugs, bugs, messages etc. in the database.

	$i_ok = $o_do->doo(); # data in result via formatting...

=cut

sub doo { # overview
    my $self = shift;	
	$self->debug('IN', @_);
    $self->start('-o');
    my $h_over = $self->stats;
    my $i_ok = $self->format_overview($h_over);
    $self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doO

Returns a similar overview of the bugs, in GUI format using GIFgraph and/or AA-lib?

	Still to do

=cut

sub doO { # Overview
    my $self = shift;
    $self->start('-O');
    $self->result('Overview with even more detail not implemented yet.');
    $self->finish;
    return undef;
    $self->doo('ids'); #flag to set ids 'on'.
}


=item doa

ONLY do this if registered as admin of bug.
in which case dok could still dok(\@bids) these bugids...
or should it automatically add id as admin?

=cut

sub doa { # admin
    my $self = shift;
	$self->debug('IN', @_);
    my ($args) = @_; 
    my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	$self->start("-a @args");
	my $done = 0;
	my %cmds = $self->parse_str(join(' ', @args));
    my $cmds = join(' ', @{$cmds{'flags'}});
    my ($commands) = $self->parse_flags($cmds, 'SET');
	$commands .= ", version = '@{$cmds{'versions'}}'" if scalar(@{$cmds{'versions'}}) >= 1;
	$self->debug(2, "str(@args) -> cmds(".Dumper(\%cmds)."commands($commands)");
	if ($commands !~ /\w+/) {
		$self->debug(0, "parse_flags failed($cmds -> $commands)");
		$self->result("No commands ($commands) returned for execution from parse_flags($cmds)");
	} else {
	    foreach my $t (@{$cmds{'bugids'}}) {
	        next unless $self->ok($t);
	        if (!$self->admin_of_bug($t, $self->isadmin)) {
				my $notify = $self->administration_failure($t, $commands, $self->isadmin, 'not admin');
			} else {
				my $sql = "UPDATE tm_tickets SET $commands WHERE ticketid = '$t'";
                my $sth = $self->exec($sql);
                if (defined($sth)) {
                    $done++;
					my $rows = $sth->rows | $sth->affected_rows | $sth->num_rows; 
                    $self->debug(2, "Bug ($t) updated ($rows, $done).");
                    my $i_t= $self->track('b', $t, $commands);
					if ($rows >= 1) {
						my $i_x = $self->notify_cc($t, $cmds);
					}
					# $self->doK([$tid]) unless $self->admin_of_bug($tid, $self->isadmin);
	    		} else {
                    $self->result("Bug ($t) update failure($sth): ($@, $Mysql::db_errstr)");
                }
			}
            $self->debug(2, "Bug ($t)  administration done($done).");
	    }
	    $self->debug(2, "All administration commands done($done)");
	} 
    $self->finish;
    my $i_ok = ($done >= 1) ? 1 : 0;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item admin_of_bug

Checks given bugid and administrator against tm_claimants.

Returns 1 if administrator listed against bug, 0 otherwise.

=cut

sub admin_of_bug {
    my $self  = shift;
	$self->debug('IN', @_);
    my $bid   = shift;
    my $admin = shift || '';
	my $i_ok  = 0;
    my $sql   = "SELECT DISTINCT ticketid FROM tm_claimants WHERE userid = '$admin' AND ticketid = '$bid'";
    my ($res) = $self->get_list($sql);
	if (defined($res) and $bid =~ /^$res$/) {
		$i_ok = 1;
		$self->debug(3, "FOUND: bugid($bid), admin($admin) -> ok($i_ok)");
	} else {
		$self->debug(3, "NOT found: bugid($bid), admin($admin) -> ok($i_ok)");
	}
	if ($self->isadmin) {
		# $i_ok = $self->doK([($bid)]); # whoops
	}
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doA

=cut

sub doA { # Admin 
    my $self = shift;
	$self->debug('IN', @_);
    #setting -t taken care of in Perlbug::Email::parse_commands.
    my ($args) = @_;
    $self->start("-A @{$args}");
    my $i_ok = $self->doa($args);
    $self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item dok

Klaim the bug(id) given

=cut

sub dok { # claim bug
    my $self = shift;
	$self->debug('IN', @_);
    my ($args) = @_;
    my @bids = (ref($args) eq 'ARRAY') ? @{$args} : $args;
    my $i_ok = 1;
	#$self->start("-c @bids");
    my $admin = $self->isadmin;
    my @admins = $self->get_list("SELECT DISTINCT userid FROM tm_users");
	if (grep(/^$admin$/, @admins)) {
		foreach my $i (@bids) {
        	next unless $self->ok($i);
        	$i_ok = $self->bug_claim($i, $admin);
        	$self->debug(2, "Claimed ($i) by $admin ");
		}
	}
    # $self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item doK

UnKlaim the bug(id) given

=cut

sub doK { # unclaim bug 
    my $self = shift;
	$self->debug('IN', @_);
	my ($args) = @_;
    my $i_ok = 0;
    my @bids = (ref($args) eq 'ARRAY') ? @{$args} : $args;
    $self->start("-C @bids");
    foreach my $i (@bids) {
        next unless $self->ok($i);
        $i_ok += my @res = $self->bug_unclaim($i, $self->isadmin);
        $self->debug(2, "unclaimed ($i)");
    }
    $self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item dox

Delete bug from tm_tickets table.

Use C<doX> for messages associated with bugs.

=cut

sub dox { # xterminate bugs
    my $self = shift;
	$self->debug('IN', @_);
    my ($args) = @_;
    my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
    $self->start("-x @args");
    return undef unless $self->isadmin;
    my $deleted = 0;
    foreach my $arg (@args) {
        next unless $self->ok($arg);
        if (1) {
            my $delete = "DELETE FROM tm_tickets WHERE ticketid = '$arg'";
            $self->debug(2, "Going for it ($delete).");
            my ($del) = $self->exec($delete);
            if ($del->numrows >= 1) {
                $self->debug(0, "Bug ($arg) deleted from tm_tickets <br>\n");
                $deleted += $del->numrows;
            } else {
                $self->result("Bug ($arg) not deleted ($del) from tm_tickets: $Mysql::db_errstr\n");
            }
        } 
    }
    $self->finish;
	$self->debug('OUT', $deleted);
	return $deleted;
}


=item doX

Delete given bugid messages from tm_messages.

=cut

sub doX { # Xterminate messages
    my $self = shift;
	$self->debug('IN', @_);
    my ($args) = @_;
    my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
    my $i_ok = 1;
	$self->start("-X @args");
    return undef unless $self->isadmin;
    my ($deleted, $m_deleted) = (0, 0);
	foreach my $arg (@args) {
        next unless $self->ok($arg);
		my @children = $self->get_list("SELECT childid FROM tm_parent_child WHERE parentid = '$arg'");
		if (scalar(@children) >= 1) {
			$i_ok = 0;
			$self->debug(0, "Can't delete bug which has child records(@children)");
		} else {
        	$self->debug(2, "Going for the delete ($arg)");
        	foreach my $table (qw(tm_cc tm_claimants tm_messages)) {
            	my $delete = "DELETE FROM $table WHERE ticketid = '$arg'";
            	my ($del) = $self->exec($delete);
            	if ($del->numrows >= 1) {
                	$self->debug(0, "Bug ($arg) deleted from $table(".$del->numrows.") <br>\n");
				} else {
                	# $self->result("Bug ($arg) not deleted ($del) from $table: $Mysql::db_errstr<br>\n");
            	}
        	} 
			my $tmpc = "DELETE FROM tm_parent_child WHERE childid = '$arg'";
			$self->exec($tmpc);
			$deleted += $self->dox($arg); # tm_tickets if $sofarsogood
		}
    }
	$self->finish;
	$self->debug('OUT', $deleted);
    return $deleted;
}


=item doi

Initiate new admin entry, including htpasswd entry, (currently rf only)

	userid=test_user:
	password=p*ss33*t:
	address=perlbugtest@rfi.net:
	match_address=.*\@rfi\.net:
	name=Richard Foley:

or

	userid=test_user:password=p*ss33*t:address=perlbugtest@rfi.net:match_address=.*\@rfi\.net:name=Richard Foley

=cut

sub doi { # initiate new admin
    my $self = shift;
	$self->debug('IN', @_);
    my ($data) = @_;
    my ($entry) = (ref($data) eq 'ARRAY') ? @{$data} : ($data);
    $self->start("-i $entry");
    my $ok = 1;
	my $tick = 0;
    my ($userid, $password, $address, $name, $match_address, $encrypted) = ('', '', '', '', '', '');
	$entry =~ s/[\n\t\r]+//g; 
    if ($entry !~ /userid/) {
    	$ok = 0;
		$self->debug(0, "No userid offered in entry($entry)!");
	} else { # GET EACH ITEM
		ITEM:
	    foreach my $item (split(':', $entry)) {
			$self->debug(0, "inspecting item($item)");
            next ITEM unless $item =~ /\w+/;
			last ITEM if $tick == 5;
			if ($item =~ /^\s*userid=(\w+)\s*$/) {
                $userid = $1; 
                $tick++;
                $self->debug(0, "userid($userid)");
            } elsif ($item =~ /^\s*password=([\w\*]+)\s*$/) { # encrypt it here
                $password = $1; 
                $tick++;
                $self->debug(0, "password($password)");
                $encrypted = crypt($password, 'pb');
            } elsif ($item =~ /^\s*address=(.+)\s*$/) {
                $address = $1; 
                $tick++;
                $self->debug(0, "address($address)");
            } elsif ($item =~ /^\s*name=(.+)\s*$/) {
                $name = $1; 
                $tick++;
                $self->debug(0, "name($name)");
            } elsif ($item =~ /^\s*match_address=(.+)\s*$/) {
                $match_address = $1; 
                $tick++;
                $self->debug(0, "match_address($match_address)");
            }
        }  
        if ($tick != 5) {
            $ok = 0;
            $self->debug(0, "Not enough appropriate values ($tick) found in data($entry)");
        } else {
            $self->debug(0, "Sufficient($ok) values ($tick) found: ".
			"userid($userid)
			name($name)
			password($password)
			address($address)
			match($match_address)
			"
			);
		}
  	}
	if ($ok == 1) { # CHECK UNIQUE IN DB
	    my @exists = $self->get_list("SELECT userid FROM tm_users WHERE userid = '$userid'");
        if (scalar(@exists) >= 1) {
            $ok = 0;
            $self->debug(0, "user already defined in db(@exists)");
            $self->result("User already defined in database (@exists)"); 
        } else {
            $self->debug(0, "user unique in db(@exists)");
			$self->result("User unique in database (@exists)"); 
		}
    } 
    if ($ok == 1) { # INSERT: non-active is default - don't want to upset everybody :-)
        my $insert = qq|INSERT INTO tm_users values (
            '$userid', '$encrypted', '$address', '$name', '$match_address', 0
        )|;
        my ($sth) = $self->exec($insert);
        $ok = $sth->affected_rows;
        if ($ok == 1) {
            $self->debug(0, "Admin inserted into db.");
            $self->result("Admin inserted into db.");
        } else {
            $self->debug(0, "Admin db insertion failure");
            $self->result("Admin db insertion failure: $Mysql::db_errstr");
        }
    } 
    if ($ok == 1) { # HTPASSWD
    	$self->debug(0, "Admin creation: '$ok', going for htpasswd update.");
		$ok = $self->htpasswd($userid, $encrypted);
    }
	if ($ok == 1) { # feedback
	    $self->debug(0, "Returning notification");
        my $title = $self->system('title');
		my $admin_accepted = qq|
Welcome: new administrator ($name) with the $title database:

    userid=$userid
    passwd=$password

    Email1 usage:     -> help\@bugs.perl.org
	
	Email2 usage:     -> To: bugdb\@perl.org 
                         Subject: -h

    Normal WWW usage: -> http://bugs.perl.org/perlbug.cgi

    Admin. WWW usage: -> http://bugs.perl.org/admin/perlbug.cgi
    	|;
    	$self->result("$admin_accepted");
    } 
    $self->finish;
	$self->debug('OUT', @_);
    return $ok;
}  


=item doI

Disable a user entry

=cut

sub doI {
	my $self = shift;
	$self->debug('IN', @_);
	my $uids = shift;
	my $i_ok = 0;
	my @uids = (ref($uids) eq 'ARRAY') ? @{$uids} : ($uids);
    $self->start("-I @uids");
    my ($deleted, $m_deleted) = (0, 0);
	if ($self->isadmin) {
		UID:
		foreach my $tgt (@uids) {
        	next UID unless $tgt =~ /^\s*(\w+)\s*$/;
			my $uid = $1;
        	$self->debug(2, "Disabling userid($uid)");
        	my $update = "UPDATE tm_users SET active = NULL WHERE userid = '$uid'";
            my ($sth) = $self->exec($update);
            if (defined($sth)) {
				$i_ok++;
                $self->debug(0, "Userid($uid) disabled <br>\n");
			} else {
				$i_ok = 0;
				$self->debug(0, "Userid($uid) not disabled!");
                $self->result("Userid($uid) not disabled ($sth): $Mysql::db_errstr");
            }
		}
    }
	$self->finish;
	$self->debug('OUT', $i_ok);
	return $i_ok;
}
 # select userid, active from tm_users where active is null;     

=item doz

Update: only to be used by perlbug@rfi.net (disabled)

    $ok = $o_obj->doz($filename, $data);

=cut

sub doz { # update
    my $self = shift;
	$self->debug('IN', @_);
    my ($update) = @_;
    my ($data) = (ref($update) eq 'ARRAY') ? @{$update} : ($update);
    $self->start("-z $data");
    return unless $self->isadmin eq $self->system('bugmaster');       
    return 1; # anyway for now
    my $ok = 1;
    
    # ARGS
    if ($data =~ /\w+/) {
        $data =~ s/\x0D\x0A?/\n/g; # network transfer fix
    } else {    
        $ok = 0;
        $self->debug(0, "Duff data for update($data)");
    }
    
    # TRIM + SCRIPTNAME
    my $file = '';
    if ($ok == 1) {
        if ($data =~ /^\#\s\$SITE\/Perlbug\/(\w+)\.pm\s(C)\s/) {   # xxx
            $file = "$1.pm"; # modules only
            $self->debug(0, "Filename ($file) found");
        } else {
            $ok = 0;
            $self->debug(0, "No filename found in data");
        }
    }

    # UPDATE
    if ($ok == 1) {
        # my $dir = '~richard/Perlbug/temp';                	#  xxx
        my $dir = $self->directory('temp');                
        my ($original, $backup, $temp) = ("$dir/$file", "$dir/$file.bak", "$dir/$file.tmp");
        $ok = $self->copy($original, $backup);
        if ($ok == 1) {
            $ok = $self->create($temp, $data);
            if ($ok == 1) {
                $self->syntax_check($temp);
                if ($ok == 1) {
                    $ok = $self->copy($temp, $original);
                }
            }
        }
    }
    
	$self->debug('OUT', $ok);
	return $ok;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999

=cut

1;
