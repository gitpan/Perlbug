# Perlbug functions
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Do.pm,v 1.54 2001/04/26 13:19:48 perlbug Exp $
#

=head1 NAME

Perlbug::Do - Commands (switches) for generic interface to perlbug database.

=cut

package Perlbug::Do; 
use strict;
use vars qw($VERSION);
$VERSION = do { my @r = (q$Revision: 1.54 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1; 

use Data::Dumper;
my $DEBUG = $ENV{'Perlbug_Do_DEBUG'} || $Perlbug::Database::DEBUG || '';


=head1 DESCRIPTION

Methods for various functions against the perlbug database.  

Those that have the form /do(?i:a-z)/ all return something relevant.

To be printed, returned by email, etc.

=cut


=head1 SYNOPSIS

Use like this:

	print $o_obj->dod(2); 			# "debug level set to '2'"

	print $o_obj->dob(\@list_of_bugids); 	# formatted

	print $o_obj->doh(); 			# help menu...

	
=head1 METHODS

=over 2


=item new

Create new Perlbug::Do object:

	my $do = Perlbug::Do->new();

=cut

sub new { # 
    my $proto = shift;
	my $class = ref($proto) || $proto; 

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

   	bless({}, $class);
}


=item get_switches

Returns array of current switches, rather than string

	my @switches = $o_pb->get_switches('user');

=cut

sub get_switches { # current or admin|user
    my $self = shift;
	my $arg  = shift || '';
	my @switches = ();
	if ($arg eq 'admin') {
		@switches = split(//, $self->system('admin_switches'));
	} elsif ($arg eq 'user') {
		@switches = split(//, $self->system('user_switches'));
	} else {
		@switches = split(//, $self->current('switches'));
	}
	@switches = ($self->isadmin =~ /^richardf$/) ? grep(/^(\w|\!)$/, @switches) : grep(/^\w$/, @switches);
    return @switches;
}


=item doh

Returns help message built from a hash_ref, commands may be overwritten by sending in a hash.

Syntax for the hash is 'key => description (sample args)':

	print $o_obj->doh({
		'e' => 'email me a copy too (email@address.com)', 	# add
		'H' => 'Help - more detailed info ()',			# replace
		'z' => '', 						# unrequired 
	});

=cut

sub doh { # command line help
    my $self = shift;
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
      #        'INSERT a Bug' not supported here
		'c' => 'change id retrieval, patches, bugs.       (12 777 c8123 c55)', 					
	  # 'C' => 'INSERT a Change against a bugid           (19990606.002 changeid)',			# A
		'd' => 'debug flag data goes in logfile           ()', 								# A
		'D' => 'Dump database for backup                  ()',    							# A
	  # 'e' => 'email a copy to this email address', 
		'f' => 'format of data ascii|html|lean            ([aA|hH|l])', 
		'g' => 'group info retrieval                      (patch|install|docs|...])', 
		'G' => 'new group                                 (another_group_name)', 			# A
		'h' => 'help - this message                       ()', 
		'H' => 'more detailed help                        ()',
      # 'i' => 'initiate new admin - inc. htpasswd        (-i)',							# B
	  # 'j' => 'just treat as a reply - track             ()', 
	    'k' => 'claim a bug with optional email addr      (19990606.002 me@here.net [...])',# C
		'K' => 'unClaim this bug - remove from cc         (19990606.002 me@here.net [...])',# C
		'l' => 'log of current process                    ()', 								# A
		'L' => 'Logfile - todays complete retrieval       ()', 								# A
		'm' => 'retrieval by messageid                    (13 47 23 [...])', 
	  # 'M' => 'INSERT a Message against a bugid          (19990606.002 some_message)',		# A
		'n' => 'note retrieval                            (76 33 1  [...])',
	  # 'N' => 'INSERT a Note against a bugid             (19990606.002 some_note)',		# A
		'o' => 'overview of bugs in db                    ()', 
		'O' => 'Overview of bugs in db - more detail      ()', 
	    'p' => 'patch retrieval                           (patchid)', # change
	  # 'P' => 'INSERT a Patch against a bugid            (19990606.002 some_patch)',		# A
	  	'q' => 'query the db directly                     (select * from db_type where 1 = 0)', 
		'Q' => 'Query the schema for the db               ()', 
		'r' => 'retrieve body search criteria             (d_sigaction=define)', 
		'R' => 'Retrieve body search criteria as per -B   (d_sigaction=define)', 
		's' => 'subject search by literal                 (bug in docs)', 
		'S' => 'Subject search as per -B                  (bug in docs)', 
	    't' => 'test retrieval by testid                  (77 [...])', 
	  # 'T' => 'INSERT a Test against a bugid|patch       (19990606.002 test|patch)', 		# A
		'u' => 'user retrieval by userid                  (richardf [...])', 				# A
	  	'v' => 'volunteer bug group etc.                  (19990606.002 close)',
	  # 'V' => 'Volunteer as admin',  
	  # 'w'	=> 'where group ...',
		'x' => 'xterminate bug - remove bug               (19990606.002 [...])', 			# A
		'X' => 'Xterminate bug - and messages             (19990606.002 [...])', 			# A
	    'y' => 'yet another password                      ()', 								# 
	    'z' => 'Configuration data                        (current)',						# A
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
	$self->debug(3, 'help retrieved') if $DEBUG;    
	return $data;
}


=item dod

Switches debugging on (1).

=cut

sub dod { # debug
	my $self = shift;
	my ($d) = @_;
	my $ret = '';
	my $level = (@{$d}[0] =~ /^\d$/) ? @{$d}[0] : 1;
    if ($level =~ /\d/) {
		$Perlbug::DEBUG = $level;
		$self->current({'debug', $level});
		$ret = "Debug level($level) set";
    }
	return $ret;
}


=item doD

Dumps database for backup and recovery.

=cut

sub doD { # Dump Database (for recovery)
    my $self = shift;
	my ($input) = @_;
	my ($since) = (ref($input) eq 'ARRAY') ? @{$input}[0] : ($input);
    $self->debug(0, "DB dump($since) requested by '".$self->isadmin."'") if $DEBUG;
    my $i_ok = 1;
	my $ret = '';
	my $adir = $self->directory('arch');
	my $date = $self->current('date');
	my $tdir = $self->directory('spool').'/temp';
	my $pdir = $self->directory('perlbug');
	my $target = File::Spec->canonpath($tdir.'/'.$self->database('latest'));
	my $tgt  = ($since =~ /\d+/) ? "from_$since" : $date;
	$target =~ s/^(.+?\.)gz/${1}$tgt\.gz/;
	my $dage = $self->database('backup_interval');
	if (($since !~ /\d+/) && (-e $target) && (-M _ >= $dage)) {
		$ret ="Recent($date) non-incremental database dump($target) found less than $dage days old";
	} else {
		my $dump = $self->database_dump_command($target, $since);
		if (!(defined($dump))) {
			$ret = "Failed to get database dump command($dump)";
		} else {	
			$dump =~ s/\s+/ /g;
			$i_ok = !system($dump); 		# doit
			my ($ts) = $self->get_list("SELECT SYSDATE() + 0");
			if ($since !~ /\d+/) { 			# full blown backup
				if (!($i_ok == 1 && -f $target)) {
					$ret = "Looks like database backup failed: $? $!";
				} else {
					my $arch = File::Spec->canonpath($adir."/Perlbug.sql.${date}.gz");
					my $lach = File::Spec->canonpath($adir.'/'.$self->database('latest'));
					$i_ok = $self->copy($target, $arch);
					$ret = "Database backup copy($i_ok)";
					if ($i_ok == 1) {
						$i_ok = $self->link($arch, $lach, '-f');
						$ret .= ", database backup link($i_ok)";
					}	
				}
			}
		}
	}
	return $ret;
}


=item database_dump_command 

Returns database dump command (mysql/oracle) for given date (or full) and target file.

else undef 

    my $cmd = $do->database_dump_command($date, $file);

=cut

sub database_dump_command { # get database dump command
	my $self = shift;
	my ($target, $date) = @_;
	($target, $date) = (ref($target) eq 'ARRAY') ? @{$target} : ($target, $date);
	my $cmd = '';
	my $i_ok = 1;
	if ($target !~ /^(.+)$/) {
		$i_ok = 0;
		$self->error("Invalid target($target) given for database backup");
	} else {
		my $bakup= $self->database('backup_command');
		my $args = $self->database('backup_args');
		my $user = $self->database('user');
		my $pass = $self->database('password');
		my $db   = $self->database('database');
		my $comp = $self->system('compress');
		if ($date !~ /^(\d+)$/) {
			$self->debug(0, "Null or invalid numerical date($date) given, dumping entire db.");
		} else {
			if (!($date =~ /^(\d{8,14})$/)) {
				$i_ok = 0;
				$self->error("Invalid date($date) offered, should be of the form(19990127)");
			} else {	
				my $filter = $1. ('0' x (14 - length($1)));
				my $min = '19870502';
				my ($max) = $self->get_list("SELECT SYSDATE() + 0");
				($max, my $check) = (substr($max, 0, 8), substr($filter, 0, 8));
				if (!($check > $min && $check <= $max)) {
					$i_ok = 0;
					$self->error("Out of range date($check) offered, should between min($min) and max($max)'");
				} else {
					$self->debug(2, "Accepting date($filter, $check) min($min) and max($max)") if $DEBUG;
					$args .= " -w'ts>=$filter'";
				}
			}
		}
		$cmd = "$bakup $args -u$user -p$pass $db | $comp > $target" if $i_ok == 1;
	} 
	return $cmd;
}


=item dom

Return the given message(id), places the L<Perlbug/format>ed result in to the
results array.

    my $res = $do->dom([@messageids]);

=cut

sub dom { # retrieve message by id
	my $self = shift;
	my $input = shift;
	my $fmt  = shift || $self->current('format');
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	my @res = ();
	my $o_msg = $self->object('message');
	my $i_ok = 0;
	foreach my $i (@args) {
	    next unless $i =~ /^\d+$/;
	    $self->debug(3, "message id=$i") if $DEBUG;
		my $str = $o_msg->read($i)->format($fmt);
		push(@res, $str);
	} 
	return @res;
}


=item doM

Create new message

    my $new_mid = $do->doM($bugid, 'message', 'etc');

=cut

sub doM { # create new message
	my $self = shift;
	my $xstr  	= shift;
	my $xmsg 	= shift || '';
	my $xhdr 	= shift || '';
	my $xsubj 	= shift || '';
	my $xfrom 	= shift || '';
	my $xto 	= shift || '';
	my ($str, $msg, $hdr, $subj, $frm, $to) = (ref($xstr) eq 'ARRAY') ? (@{$xstr}, $xmsg, $xhdr, $xsubj, $xfrom, $xto) : ($xstr, $xmsg, $xhdr, $xsubj, $xfrom, $xto);
	my $mid  = 0;
	my @res = ();
	my %cmds = $self->parse_str($str);

	if ($msg !~ /\w+/) {
		$self->error("requires a valid message($msg) to insert");
	} else {
		my $o_msg = $self->object('message');
		$o_msg->create({
			'messageid'	=> $o_msg->new_id,
			'subject'	=> $subj, 
			'sourceaddr'=> $frm, 
			'toaddr'	=> $to, 
			'header'	=> $hdr, 
			'body'		=> $msg,
			'email_msgid'	=> '',
		});
		if ($o_msg->CREATED) {
			$mid = $o_msg->insertid;
			if ($mid !~ /\w+/) {
				$self->debug(0, "failed to retrieve messageid($msg)") if $DEBUG;
			} else {
				if (ref($cmds{'bugids'}) eq 'ARRAY') {
					$o_msg->relation('bug')->assign($cmds{'bugids'});
				}
			}
		}
	}		

	return $mid;
}


=item dog

Return the given group(id), places the L<Perlbug/format>ed result in to the
results array.

    my @res = $do->dog([@groupids]);

=cut

sub dog { # get group by name 
	my $self = shift;
	my $input = shift;
	my $fmt  = shift || $self->current('format');
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	my $o_grp = $self->object('group');
	my @res = ();
	foreach my $i (@args) {
	    next unless $i =~ /^\w+$/;
		my $str = $o_grp->read($i)->format($fmt);
		push(@res, $str);
	} 
	return @res;
}


=item doG

Create new group 

    my $new_gid = $do->doG($bugid, 'message', 'etc');

=cut

sub doG { # create new group 
	my $self = shift;
	my $xstr  	= shift;
	my $xgrp 	= shift || '';
	my $xdes 	= shift || '';
	my ($str, $grp, $des) = (ref($xstr) eq 'ARRAY') ? (@{$xstr}, $xgrp, $xdes) : ($xstr, $xgrp, $xdes);
	my $gid  = 0;
	my %cmds = $self->parse_str($str);

	if ($grp !~ /^\w+$/) {
		$self->error("requires a valid alphanumeric group($grp) to insert");
	} else {
		my $o_grp = $self->object('bug');
		$o_grp->create({
			'groupid'	=> $o_grp->new_id,
			'name'			=> $xgrp, 
			'description' 	=> $xdes, 
		});
		if ($o_grp->CREATED) {
			$gid = $o_grp->insertid;
			if ($gid !~ /\w+/) {
				$self->debug(0, "failed to retrieve groupid($xgrp)") if $DEBUG;
				if (ref($cmds{'bugids'}) eq 'ARRAY') {
					$o_grp->relation('bug')->assign($cmds{'bugids'});
				}
			}
		}
	}		

	return $gid;
}


=item dop

Return the given patch(id), places the L<Perlbug/format>ed result in to the
results array.

    my @res = $do->dop([@patchids]);

=cut

sub dop { # get patch by id
	my $self = shift;
	my ($input) = shift;
	my $fmt  = shift || $self->current('format');
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	my $o_pat = $self->object('patch');
	my @res = ();
	foreach my $i (@args) {
	    next unless $i =~ /^\d+$/;
		my $str = $o_pat->read($i)->format($fmt);
		push(@res, $str);
	} 
	return @res;
}


=item doP

Assign to given bugid, given patch, return i_ok

	$res = $o_obj->doP('tid_chid_versid', 'patch...here', 'hdr', 'sbj', 'frm', 'to);

=cut

sub doP {
	my $self  = shift;
	my $xstr  	= shift;
	my $xpatch 	= shift || '';
	my $xhdr 	= shift || 'no header supplied';
	my $xsubj 	= shift || 'no subject supplied';
	my $xfrom 	= shift || 'no_from_line';
	my $xto 	= shift || 'no_to_line';
	my ($str, $patch, $hdr, $subj, $frm, $to) = (ref($xstr) eq 'ARRAY') ? (@{$xstr}, $xpatch, $xhdr, $xsubj, $xfrom, $xto) : ($xstr, $xpatch, $xhdr, $xsubj, $xfrom, $xto);
	my $res = '';
	my %cmds = $self->parse_str($str);

	if ($patch !~ /\w+/) {
		$self->error("requires a valid patch($patch) to insert");
	} else {
		my $o_pat = $self->object('patch');
		$o_pat->create({
			'patchid'	=> $o_pat->new_id,
			'subject'	=> $subj, 
			'sourceaddr'=> $frm, 
			'toaddr'	=> $to, 
			'header'	=> $hdr, 
			'body'		=> $patch,
			'email_msgid'	=> '',
		});	
		if ($o_pat->CREATED) {
			my $patchid = $o_pat->insertid;
			if (ref($cmds{'bugids'}) eq 'ARRAY') {
				$o_pat->relation('bug')->assign($cmds{'bugids'});
			}
			if (ref($cmds{'change'}) eq 'ARRAY') {
				$o_pat->relation('change')->assign($cmds{'change'});
			}
			if (ref($cmds{'version'}) eq 'ARRAY') {
				$o_pat->relation('version')->assign($cmds{'version'});
			}
		}
	}

	return $res;
}


=item dot

Return the given test(id), places the L<Perlbug/format>ed result in to the
results array.

    my @res = $do->dot([@testids]);

=cut

sub dot { # get test by id
	my $self = shift;
	my ($input) = shift;
	my $fmt  = shift || $self->current('format');
	my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	my $o_test = $self->object('test');
	my @res = ();
	foreach my $i (@args) {
	    next unless $i =~ /^\d+$/;
		my $str = $o_test->read($i)->format($fmt);
		push(@res, $str);
	} 
	return @res;
}


=item doT

Assign to given bugid, given test, return i_ok

	$new_tid = $o_obj->doT('tid_chid_versid', 'test...here', 'hdr', 'sbj', 'frm', 'to);

=cut

sub doT {
	my $self  = shift;
	my $xstr  = shift;
	my $xtest = shift;
	my $xhdr 	= shift || 'no header supplied';
	my $xsubj 	= shift || 'no subject supplied';
	my $xfrom 	= shift || 'no_from_line';
	my $xto 	= shift || 'no_to_line';
	my ($str, $test, $hdr, $subj, $frm, $to) = (ref($xstr) eq 'ARRAY') ? (@{$xstr}, $xtest, $xhdr, $xsubj, $xfrom, $xto) : ($xstr, $xtest, $xhdr, $xsubj, $xfrom, $xto);
	my %cmds = $self->parse_str($str);
	my $res = '';

	if ($test !~ /\w+/) {
		$res = "requires a valid test($test) to insert";
	} else {
		my $o_tst= $self->object('test');
		$o_tst->create({
			'testid'	=> $o_tst->new_id,
			'subject'	=> $subj, 
			'sourceaddr'=> $frm, 
			'toaddr'	=> $to, 
			'header'	=> $hdr, 
			'body'		=> $test,
			'email_msgid'	=> '',
		});	
		if ($o_tst->CREATED) {
			$res = $o_tst->insertid;
			if (ref($cmds{'bugids'}) eq 'ARRAY') {
				$o_tst->relation('bug')->assign($cmds{'bugids'});
			}
		}
	}

	return $res;
}


=item dob

Return the given bug(id), places the L<Perlbug/format>ed result in to the 
result array.

    my @res = $do->dob([@bugids]);
    
=cut

sub dob { # get bug by id 
	my $self = shift;
	my $t    = shift; 
	my $fmt  = shift || $self->current('format');
	my @bids = (ref($t) eq 'ARRAY') ? @{$t} : ($t);
	my $o_bug = $self->object('bug');
	my $fnd = 0;
	my @res = ();
	foreach my $i (@bids) {
		my $str = $o_bug->read($i)->format($fmt);
		push(@res, $str);
	}
	return @res;
}


=item doB

Return the given bug(id), with all the messages assigned to it, calls dob()

    my @res = $do->doB(\@bugids);

=cut

sub doB { # get bug by id (large format)
    my $self 	= shift;
    my $input 	= shift;
    my $sep 	= shift;
    my @args = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	my $o_bug = $self->object('bug');
	my @res = ();
    foreach my $bid (@args) {
		push(@res, $o_bug->read($bid)->format());
		
		my @mids = $o_bug->rel_ids('message');
		my ($mid) = sort { $a <=> $b } @mids;
        push(@res, $self->dom(\@mids));
		
        my @pids = $o_bug->rel_ids('patch');
        push(@res, $self->dop(\@pids));
		
        my @tids = $o_bug->rel_ids('test');
        push(@res, $self->dot(\@tids));
		
        my @nids = $o_bug->rel_ids('note');
        push(@res, $self->don(\@nids));
    }

    return @res;
}


=item dou

Get the given user, checks if active
    
    my @res = $o_do->dou($userid);

=cut

sub dou { # get user by id
    my $self = shift;
    my $args = shift;
	my $fmt  = shift || $self->current('format');
    my @uids = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	my $o_user = $self->object('user');
    my $fnd = 0;
	my @res = ();
    foreach my $uid (@uids) {
        next unless $uid =~ /^\w+$/;
		my $str = $o_user->read($uid)->format($fmt);
		push(@res, $str);
    }
    return @res;
}



=item dos

Retrieve bugs based on the subject line of a bug

    my @res = $do->dos('build failure');

=cut

sub dos { # subject -b
	my $self   = shift;
	my $input  = shift;
	my $borB   = shift || '';
	my ($crit) = (ref($input) eq 'ARRAY') ? @{$input} : $input;
	my @bids = $self->object('bug')->ids("subject LIKE '%$crit%'");
	my @res = ();
	if (defined($borB) && $borB eq 'B') {
	    @res = $self->doB(\@bids);
	} else {
    	@res = $self->dob(\@bids);
	}
	return @res;
}


=item doS

Wrapper for L<dos()> in 'large format'

	my @RES = $do->doS('some subject');	

=cut

sub doS {
	my $self  = shift;
	my $args = shift;
	my @res = $self->dos($args, 'B');
	return @res;
}


=item dor

Retrieve data based on contents of the Body of a message

    my @res = $do->dor('open build');

=cut

sub dor { # retrieve in body 
	my $self   = shift;
	my $input  = shift;
	my $borB   = shift  || '';
	my ($crit) = (ref($input) eq 'ARRAY') ? join(' ', @{$input}) : $input;
	my $o_msg = $self->object('message');
	my @mids = $o_msg->ids("body LIKE '%$crit%'");
	my @res = ();
	if (scalar(@mids) >= 1) {
		my $mids = join("', '", @mids);
		my @bids = $o_msg->relation('bug')->ids("messageid IN ('$mids')"); 
		push(@res, $self->dob(\@bids, $borB));
	}
	return @res;
}

=item doR

Wrapper for L<dor()>, in large format

	my @res = $do->doR('open');

=cut

sub doR {
	my $self  = shift;
	my @res = $self->dor($_[0], 'B');
	return @res;
}


=item don

Get the note for this noteid

	my @res = $do->don(\@nids);

=cut

sub don {
	my $self = shift;
	my $input = shift;
	my $fmt  = shift || $self->current('format');
	my @nids = (ref($input) eq 'ARRAY') ? @{$input} : ($input);
	my $o_note = $self->object('note');
	my $fnd = 0;
	my @res = ();
	foreach my $nid (@nids) {
        next unless $nid =~ /^\d+$/;
		my $str = $o_note->read($nid)->format($fmt);
		push(@res, $str);
    }
	return @res;
}


=item doN

Creates new note (assigns to given bugid).

	my $nid = $self->doN($str, $body, $header, $subject, $from, $to);

=cut

sub doN {
	my $self  = shift;
	my $xstr  = shift;
	my $xnote = shift;
	my $xhdr 	= shift || 'no header supplied';
	my $xsubj 	= shift || 'no subject supplied';
	my $xfrom 	= shift || 'no_from_line';
	my $xto 	= shift || 'no_to_line';
	my ($str, $note, $hdr, $subj, $frm, $to) = (ref($xstr) eq 'ARRAY') ? (@{$xstr}, $xnote, $xhdr, $xsubj, $xfrom, $xto) : ($xstr, $xnote, $xhdr, $xsubj, $xfrom, $xto);
	my %cmds  = $self->parse_str($str);
	my $res   = '';

		if ($note!~ /\w+/) {
			$res = "requires a valid note($note) to insert";
		} else {
			my $o_note = $self->object('note');
			$o_note->create({
				'noteid'	=> $o_note->new_id,
				'subject'	=> $subj, 
				'sourceaddr'=> $frm, 
				'toaddr'	=> $to, 
				'header'	=> $hdr, 
				'body'		=> $note,
				'email_msgid'	=> '',
			});	
			if ($o_note->CREATED) {
				$res = $o_note->insertid;
				if (ref($cmds{'bugids'}) eq 'ARRAY') {
					$o_note->relation('bug')->assign($cmds{'bugids'});
				}
			}
		}

	return $res;
}


=item doc

Get the patches, or bugs for this changeid 

	my @res = $do->doc(\@cids);	

=cut

sub doc {
	my $self = shift;
	my $input = shift;
	my @cids = (ref($input) eq 'ARRAY') ? @{$input} : ($input);
	my @res = ();
	foreach my $cid (@cids) {
        next unless $cid =~ /^\d+$/;
		my $o_chg = $self->object('change')->read($cid);
		my @pids = $o_chg->relation('patch')->ids($o_chg);
		$self->debug(2, "found pids(@pids) related to changeid($cid)") if $DEBUG;
		if (scalar(@pids) >= 1) {
			@res = $self->dop(\@pids);
        } else {
			print "No patches found with changeid($cid), trying with bugs...<br>\n"; 
			my @bids = $o_chg->relation('bug')->ids($o_chg);
			$self->debug(2, "found bids(@bids) related to changeid($cid)") if $DEBUG;
			if (scalar(@bids) >= 1) {
				@res = $self->dob(\@bids);
			}	
		}
    }
	$self->debug(2, "found ".@res." related items to cids(@cids)") if $DEBUG;
	return @res;
}


=item doq

Gets the sql _q_ query statement given in the body of the message, executes it, and
returns the result in the result array.

=cut

sub doq { # sql
    my $self = shift;
    my ($input) = @_;
	my $i_ok = 0;
    my ($sql) = (ref($input) eq 'ARRAY') ? @{$input} : $input;
    $sql =~ tr/\n\t\r/ /; 
    $sql =~ s/^(.+)?[\;\s]*$/$1/;
    my ($errs, $res) = (0, '');
    if (($self->isadmin eq $self->system('bugmaster'))){# && ($sql !~ /delete|drop/i)){
        # let it through for testing purposes
    } else {
        # could be a little paranoid, but...
	 	if ($sql =~ /\b(alter|create|delete|drop|file|grant|insert|rename|shutdown|update)\b/si) {
	 		$res = "You may not execute this sql($1) from this interface<br>\n";
			$errs++;
		}
		if ($sql !~ /^\b(desc|select|show)\b/si)  { 
			$res = "You may only execute DESC|SELECT|SHOW statements from this interface - invalid sql($sql)<br>\n";
			$errs++;
		}
    }
	if ($errs == 0) {   
		my $sth = $self->db->query($sql);
		if (defined($sth)) {
			$i_ok++;
			# my $maxlen  = $self->database('maxlen') || 1500;
			# my $lsep	= "\n";
			# my $fsep	= ",\t";
			# my $fh 		= $self->fh('res');
			# my $rows = $sth->dump_results($maxlen, $lsep, $fsep, $fh);
			$res = $sth->as_string; # better? => Oracle?
		} else {
			$res = "No results($DBI::errstr) from '$sql'";
		}
	}
	return $res;
}


=item doQ

Returns the database schema, for use with SQL statements.

	my @tables_data = $do->doQ;

=cut

sub doQ { # Schema
    my $self = shift;
	my @tables = $self->get_list("SHOW tables FROM ".$self->database('database'));
	my $res = ();
	foreach my $t (@tables) {
	    next unless $t =~ /^\w+/;
	    my $sql = "SHOW fields FROM $t";
    	$res .= "$t: \n".$self->doq($sql);
	}
	return $res;
}


=item doL

Returns the current (or given later) logfile.

	my $LOG = $do->doL;
	
=cut

sub doL { # Log (all)
	my $self = shift;
	my ($input) = @_;
    my ($given) = (ref($input) eq 'ARRAY') ? @{$input} : $input;
    ($given == 1) && ($given = 'today');
	my $fh = $self->fh('log'); # , db_log_\d{8}
	my $LOG = '';
	if (!(defined $fh)) {
        $self->error("Can't read LOG from undefined fh ($fh)");
	} else {
	    $fh->seek(0,0);
	    while (<$fh>) {
	        $LOG .= $_;
	    }
	    $fh->seek(0, 2);   
	    my $length = length($LOG);
	    $self->debug(2, "log ($fh) length ($length) read") if $DEBUG;
    } 
	return $LOG;
}


=item dol

Just the stored log results from this process.

	my $process_log = $do->dol;

=cut

sub dol { # log (this process)
    my $self  = shift;
	my $o_log = $self->log;
	my ($line, $switch, $log, $cnt) = ('', 0, '', 0);
	my @data = $o_log->read;

		foreach my $line (@data) {
			chomp($line);
    		if ($line =~ /^\[0\]\s+INIT\s+\($$\)\s/i) {
				# $self->debug(0, "INIT ($$) debug($Perlbug::DEBUG) scr($0)"); # if $DEBUG
				$switch++;
				# print "MATCHED -> '$line'\n\n";
    	    } 
    	    if ($switch >= 1) {         # record from here to end
    	        $log .= "$line\n";
    	        $cnt++;
    	    }
    	}
    	$self->debug(2, "Retrieved $cnt lines from log") if $DEBUG;

	return $log;
}


=item dof

Sets the appropriate format for use by L<Formatter> methods, overrides default 'a' set earlier.

	my @res = $o_obj->dof('h'); 

=cut

sub dof { # format setting
	my $self = shift;
	my ($fmt) = @_;
	my $format = (ref ($fmt) eq 'ARRAY') ? @{$fmt}[0] : $fmt;
	my $ok = ($format =~ /^[aAhHiIlLxX]$/) ? $format : 'a'; # supported formats
	my $ret = $self->current({'format' => $ok});
	my $res = "Format($format) -> ok($ok) -> ($ret) set";
	return $res;
}


=item stats

Get stats from db for overview usage.

	my $h_data = $self->stats;

=cut

sub stats {
    my $self = shift;
    my %over = (); 
	my $o_bug = $self->object('bug');
	my $o_usr = $self->object('user');

	# BUGS
	$over{'bug'}     = $o_bug->count;
	$over{'message'} = $self->object('message')->count;
	$over{'patch'}   = $self->object('patch')->count;
	$over{'note'}    = $self->object('note')->count;
	$over{'test'}    = $self->object('test')->count;
	my @claimed      = $o_usr->rel_ids('bug');
	$over{'claimed'} = scalar @claimed; 
	my $claimed      = join("', '", @claimed);
	($over{'unclaimed'})= $o_bug->count("bugid NOT IN ('$claimed')");

	my $o_status = $self->object('status');
	my ($openid) = $o_status->read($o_status->ids("name='open'"));

	my @uids = $o_usr->ids;
	$over{'administrators'}	= @uids;
	foreach my $uid (@uids) {
		my $cnt = my @bids = $o_usr->read($uid)->rel_ids('bug');
		$over{'user'}{$uid} = $cnt;
		my $bids = join("', '", @bids);
		my $ocnt = my @obids = $o_status->rel_ids('bug', "bugid IN ('$bids')");
		$over{'user'}{'Open'}{$uid} = $ocnt;
	}

	# rjsf: dates take a long time
	#
	# DATES
	my $datediff       = "TO_DAYS(NOW()) - TO_DAYS(created)";
	($over{'days1'})   = '1'; #$o_bug->ids("$datediff <= 1");
	($over{'days7'})   = '2'; #$o_bug->ids("$datediff <= 7");
	($over{'days30'})  = '3'; #$o_bug->ids("$datediff <= 30");
	($over{'days90'})  = '4'; #$o_bug->ids("$datediff <= 90");
	($over{'90plus'})  = '5'; #$o_bug->ids("$datediff >= 90");

	# FLAGS
	my %flags = $self->all_flags;
	FLAG:
	foreach my $flag (keys %flags) { # group os sev stat user version
		$self->debug(1, "Overview flag: '$flag'") if $DEBUG;
		my @types = @{$flags{$flag}};
		my $o_flag = $self->object($flag); # 
		TYPE:
		foreach my $type (@types) {  # inst core docs | open clos busy | etc:
			$self->debug(2, "Overview flag type: '$type'") if $DEBUG;
			my ($fid) = $o_flag->name2id([$type]);
			my $i_cnt = my @bids = $o_flag->read($fid)->rel_ids('bug');
			$over{$flag}{$type} = $i_cnt || ''; 			#	

			next TYPE if $flag eq 'status';

			my $bids = join("', '", @bids);
			my $ocnt = my @obids = $o_status->rel_ids('bug', "bugid IN ('$bids')");
			$over{$flag}{'Open'}{$type} = $ocnt || ''; 	# 

			if ($flag eq 'version' && $type =~ /^(\d)\.0*([1-9])([\d\.])+\s*$/) {
				my $trim = "$1.$2.\%"; 
				$self->debug(3, "found version type($type) -> 1($1) 2($2) 3($3) assigning to trim($trim)") if $DEBUG;
				$over{$flag}{$trim} += $i_cnt;				#
				$over{$flag}{'Open'}{$trim} += $ocnt;		#
			}
		}
	}

	# RATIOS
	# $fmt{'ratio_o2c'}, $fmt{'ratio_c2o'}, $fmt{'ratio_m2t'}, $fmt{'ratio_t2a'}
	($over{'ratio_t2a'})    = sprintf("%0.2f", ($over{'bug'}        / scalar(keys %{$over{'user'}}))) if scalar(keys %{$over{'user'}}) >= 1;
	($over{'ratio_o2a'})    = sprintf("%0.2f", ($over{'status'}{'open'} / scalar(keys %{$over{'user'}}))) if scalar(keys %{$over{'user'}}) >= 1;
	($over{'ratio_m2t'})    = sprintf("%0.2f", ($over{'message'}       / $over{'bug'})) if $over{'bug'} >= 1;
	($over{'ratio_o2c'})    = sprintf("%0.2f", ($over{'status'}{'open'} / $over{'status'}{'closed'})) if $over{'status'}{'closed'} >= 1;
	($over{'ratio_c2o'})    = sprintf("%0.2f", ($over{'status'}{'closed'}/ $over{'status'}{'open'})) if $over{'status'}{'open'} >= 1;

	return \%over;
}


=item doo

Returns a summary overview of the bugs, bugs, messages etc. in the database.

	my @over = $o_do->doo(); # data in result via formatting...

=cut

sub doo { # overview
    my $self = shift;	
	my $args = shift;
	my ($fmt) = (ref($args) eq 'ARRAY') ? @{$args} : ($args);
 	$fmt = $fmt || $self->current('format');
    my $h_over = $self->stats;
	$self->debug(0, "overview stat'd, formatting...") if $DEBUG;
    my $res = $self->format_overview($h_over, $fmt);
	$self->debug(0, "overview formatted...") if $DEBUG;
	return $res;
}


=item doa

ONLY do this if registered as admin of bug.
in which case dok could still dok(\@bids) these bugids...
or should it automatically add id as admin?

	my ($res) = $do->doa($command_string, $body);

=cut

sub doa { # admin
    my $self = shift;
    my $args = shift; 
	my $fmt  = shift || $self->current('format');
    my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	my $o_mail = $self->_mail;
	my ($o_hdr, $header, $body) = $self->splice($o_mail);
	my $res = '';
	
	my $str = join(' ', @args);
	my %cmds = $self->parse_str($str);
	my @bids = @{$cmds{'bugids'}};
	if (!(@bids >= 1)) {
		$self->error("requires bugids(@bids) to administrate!");
	} else {
		my $o_bug = $self->object('bug');
		my $o_note = $self->object('note');

	    foreach my $b (@{$cmds{'bugids'}}) {
	        next unless $o_bug->ok_ids([$b]);
			my $orig = $o_bug->read($b)->format($fmt);
			foreach my $flag ($self->things('flag')) {
				my $store = ($flag =~ /^(status|severity)$/) ? '_store' : '_assign';
				$o_bug->relation($flag)->$store($cmds{$flag}) if $cmds{$flag};
			}
			if (!$o_bug->READ) {		
				$res .= "Bug ($b) update failure";
			} else {
				chomp(my $to = $o_hdr->get('To'));
				chomp(my $from = $o_hdr->get('From'));
				chomp(my $subject = $o_hdr->get('Subject'));
				$o_note->create({
					'noteid'		=> $o_note->new_id,
					'body'	 		=> $body, 
					'header' 		=> $header, 
					'subject'		=> $subject, 
					'sourceaddr'	=> $from, 
					'toaddr'		=> $to,
					'email_msgid'	=> '',
				});
				if ($o_note->CREATED) {
					my $nid = $o_note->insertid;
				}
				my $i_x = $self->notify_cc($b, $orig) unless grep(/nocc/, $cmds{'unknown'});
			}
            $self->debug(2, "Bug ($b)  administration done") if $DEBUG;
	    }
	    $self->debug(2, "All administration commands done") if $DEBUG;
	} 
	return $res;
}


=item doA

Wrapper for L<doa()>

=cut

sub doA { # Admin 
    my $self = shift;
    #setting -t taken care of in Perlbug::Email::parse_commands.
    my ($res) = $self->doa(@_);
	return $res;
}


=item dok

Klaim the bug(id) given

	my $i_claimed = $do->dok(\@bids);

=cut

sub dok { # claim bug
    my $self = shift;
    my $a_bids = shift;
    my $i_ok = 1;
    my $admin = $self->isadmin;
	if (ref($a_bids) eq 'ARRAY' && $admin =~ /\w+/ && $admin ne 'generic') {
		$self->object('user')->read($admin)->relation('bug')->assign($a_bids);
	}
	return $i_ok;
}


=item doK

UnKlaim the bug(id) given

	my $i_unclaimed = $do->doK(\@bids);

=cut

sub doK { # unclaim bug 
    my $self = shift;
	my ($args) = @_;
    my $i_ok = 0;
    my @bids = (ref($args) eq 'ARRAY') ? @{$args} : $args;
    foreach my $i (@bids) {
        next unless $self->ok_ids([$i]);
        $i_ok += my @res = $self->bug_unclaim($i, $self->isadmin);
        $self->debug(2, "unclaimed ($i)") if $DEBUG;
    }
	return $i_ok;
}


=item dox

Delete bug from db_bug table.

Use C<doX> for messages associated with bugs.

	my ($feedback) = $do->dox(\@bids);

=cut

sub dox { # xterminate bugs
    my $self   = shift;
    my $a_bids = shift;

	my $i_res  = 0;
	if (ref($a_bids) ne 'ARRAY') {
		$self->error("requires array_ref of x bugids($a_bids)");
	} else {
		if (!($self->isadmin)) {
			$self->error("not x admin: ".$self->isadmin);
		} else {
			my $o_bug = $self->object('bug');
			$o_bug->delete($a_bids);
			$i_res = $o_bug->DELETED;
		}
	}

	return $i_res;
}


=item doX

Delete given bugs along with messages from db_message.

Also does parent/child, bug_user, etc. tables, also calls L<dox()>

	my ($feedback) = $do->doX(\@bids);

=cut

sub doX { # Xterminate messages
    my $self   = shift;
    my $a_bids = shift;

	my $i_del  = 0;

	if (ref($a_bids) ne 'ARRAY') {
		$self->error("requires array_ref of bugids($a_bids)");
	} else {
		if (!($self->isadmin)) {
			$self->error("not admin: ".$self->isadmin);
		} else {
			my $o_bug = $self->object('bug');
			my @rels  = $o_bug->relations;
			BUG:
			foreach my $arg (@{$a_bids}) {
				next BUG unless $o_bug->ok_ids([$arg]);
				REL:
				foreach my $rel (@rels) {
					next REL unless $rel;
					my $o_rel = $o_bug->relation($rel)->set_source($o_bug);
					$o_rel->delete([$o_bug->rel_ids($rel)]);
				}
				$i_del += $self->dox($arg); # bug if $sofarsogood
			}
		}
	}
    return $i_del;
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

	my $i_ok = $do->doi($data);

=cut

sub doi { # initiate new admin
    my $self = shift;
    my ($data) = @_;
    my ($entry) = (ref($data) eq 'ARRAY') ? @{$data} : ($data);
    my $i_ok = 1;
	my $res = '';
	my $tick = 0;
    my ($userid, $password, $address, $name, $match_address, $encrypted) = ('', '', '', '', '', '');
	my $o_usr = $self->object('user');
	$entry =~ s/[\n\t\r]+//g; 
    if ($entry !~ /userid/) {
    	$i_ok = 0;
		$self->error("No userid offered in entry($entry)!");
	} else { # GET EACH ITEM
		ITEM:
	    foreach my $item (split(':', $entry)) {
			$self->debug(0, "inspecting item($item)") if $DEBUG;
            next ITEM unless $item =~ /\w+/;
			last ITEM if $tick == 5;
			if ($item =~ /^\s*userid=(\w+)\s*$/) {
                $userid = $1; 
                $tick++;
                $self->debug(0, "userid($userid)") if $DEBUG;
            } elsif ($item =~ /^\s*password=([\w\*]+)\s*$/) { # encrypt it here
                $password = $1; 
                $tick++;
                $self->debug(0, "password($password)") if $DEBUG;
                $encrypted = crypt($password, 'pb');
            } elsif ($item =~ /^\s*address=(.+)\s*$/) {
                $address = $1; 
                $tick++;
                $self->debug(0, "address($address)") if $DEBUG;
            } elsif ($item =~ /^\s*name=(.+)\s*$/) {
                $name = $1; 
                $tick++;
                $self->debug(0, "name($name)") if $DEBUG;
            } elsif ($item =~ /^\s*match_address=(.+)\s*$/) {
                $match_address = $1; 
                $tick++;
                $self->debug(0, "match_address($match_address)") if $DEBUG;
            }
        }  
        if ($tick != 5) {
            $i_ok = 0;
            $self->error("Not enough appropriate values ($tick) found in data($entry)");
        } else {
            $self->debug(0, "Sufficient($i_ok) values ($tick) found: ". # if $DEBUG
			"userid($userid)
			name($name)
			password($password)
			address($address)
			match($match_address)
			"
			) if $DEBUG;
		}
  	}
	if ($i_ok == 1) { # CHECK UNIQUE IN DB
		my @exists = $o_usr->ids("UPPER(userid) LIKE UPPER($userid)");
        if (scalar(@exists) >= 1) {
            $i_ok = 0;
            $self->error("User already defined in db(@exists)");
		}
    } 
    if ($i_ok == 1) { # INSERT: non-active is default - don't want to upset everybody :-)
		$o_usr->create({
			'userid'		=> $userid, 
			'password'		=> $encrypted, 
			'address'		=> $address, 
			'name'			=> $name, 
			'match_address'	=> $match_address, 
			'active'		=> 0,
		});
        if ($o_usr->CREATED) {
            $self->debug(0, "Admin inserted into db.") if $DEBUG;
        } else {
			$i_ok = 0;
            $self->error("Admin db insertion failure");
        }
    } 
    if ($i_ok == 1) { # HTPASSWD
    	$self->debug(0, "Admin creation: '$i_ok', going for htpasswd update.") if $DEBUG;
		$i_ok = $self->htpasswd($userid, $encrypted);
    }
	if ($i_ok == 1) { # feedback
	    $self->debug(0, "Returning notification") if $DEBUG;
        my $title = $self->system('title');
		my $url   = 'http://'.$self->web('domain');
		my $new_admin = qq|
Welcome $name as a new $title administrator:

	Address: "$name" <$address>

    userid=$userid
    passwd=$password  
	
	N.B. please change your password at your next WWW login (below)

    Normal WWW usage: -> $url/index.html

    Specification:    -> $url/perlbug.cgi?req=spec

    User   FAQ:       -> $url/perlbug.cgi?req=webhelp

    Admin Login: ***  -> $url/admin/index.html 

    Admin  FAQ:       -> $url/admin/perlbug.cgi?req=adminfaq


    Email_1 usage:    -> To: help\@bugs.perl.org
	
    Email_2 usage:    -> To: bugdb\@perl.org 
                         Subject: -h

	Email all admins  -> To: admins\@bugs.perl.org

	Mailing list      -> To: bugmongers-subscribe\@perl.org 

    	|;
		use Perlbug::Interface::Email; # yek
		my $o_email = Perlbug::Interface::Email->new;
		$o_email->_original_mail($o_email->_duff_mail); # dummy - blek
		my $o_notify = $o_email->get_header;
		$o_notify->add('To', $address);
		$o_notify->add('Bcc', $self->system('maintainer'));
		$o_notify->add('From', $self->email('bugdb'));
		$o_notify->add('Subject', "$title administrator");
		$i_ok = $o_email->send_mail($o_notify, $new_admin);
    } 
    return $i_ok;
}  


=item doI

Disable a user entry
	
	my $i_disabled = $do->doI(\@uids);

=cut

sub doI {
	my $self = shift;
	my $uids = shift;
	my $i_ok = 0;
	my @uids = (ref($uids) eq 'ARRAY') ? @{$uids} : ($uids);
    my ($deleted, $m_deleted) = (0, 0);
	if ($self->isadmin) {
		UID:
		foreach my $tgt (@uids) {
        	next UID unless $tgt =~ /^\s*(\w+)\s*$/;
			my $uid = $1;
        	$self->debug(2, "Disabling userid($uid)") if $DEBUG;
			my $o_usr = $self->object('user');
			$o_usr->update({
				'active'	=> '',
			});
			$i_ok = 1 if $o_usr->UPDATED;
		}
    }
	return $i_ok;
}


=item doz

Configuration data

    $data = $o_obj->doz('current');

=cut

sub doz { # update
    my $self = shift;
	my $args = shift;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : ($args);
	my $config = $self->get_config(@args);
    
	return $config;
}


=item doy

Password renewal

    my ($i_ok) = $do->doy($user, $pass);

=cut

sub doy { # password, user
    my $self = shift;
	my $input = shift;
	($input) = (ref($input) eq 'ARRAY') ? @{$input} : ($input);
	my ($user, $pass) = split(/\s+/, $input);
	$pass = 'default_password' unless $pass =~ /\w+/;
    my $i_ok = 1;
	my $o_usr = $self->object('user');
    
	if (!($user =~ /\w+/ && $pass =~ /\w+/)) {
		$i_ok = 0;
		$self->error("invalid user($user) or pass($pass)");
	} else {
		my @uids = $o_usr->read($user)->ids("active IN ('1', '0')");
		if (!(grep(/^$user$/, @uids))) {
			$i_ok = 0;
			$self->error("can't update password for non-valid user($user) - '@uids'");
		}
	}
	
	if ($i_ok == 1) { # HTPASSWD
		my $encrypted = crypt($pass, substr($pass, 0, 2));
		$i_ok = $self->htpasswd($user, $encrypted);
		if ($i_ok == 1) {
			$self->debug(0, "htp: user($user) inserted new password($pass)") if $DEBUG;
		} else {
			$i_ok = 0;
			$self->error("htp: user($user) failed to insert new password($pass)");
		}
    }
	
	if ($i_ok == 1) { # DATABASE
		$o_usr->update({
			'password'	=> "PASSWORD('$pass')",
		});
    	if ($o_usr->UPDATED) {
			$self->debug(0, "db: user($user) set new password($pass)") if $DEBUG; 
		} else {
			$i_ok = 0;
			$self->error("db: user($user) failed to set new password($pass)"); 
		}
	}
	
	return $i_ok;
}


=item overview

Formatting for overview.

        $fmt{'bugs'} = $data{'bugs'};

=cut

sub overview {
    my $self = shift; # expected to be Base/Cmd/Email/Web object!
    my $ref  = shift;
    my $fmt  = shift || $self->current('format') || 'a';

	my $url = $self->current('url');
	my $cgi = $self->cgi();
    my $ret = '';

    if (ref($ref) ne 'HASH') {       # duff old style.
		$self->error("Can't format unrecognised data($ref)");
    } else {  
        my %fmt = %{$ref}; # short cut...
        # no strict 'refs'; 
        my %flags = $self->all_flags;
		$fmt{'graph'}{'dates'} = 'Age: &nbsp;';
		($fmt{'graph'}{'admins'}) = $self->href('graph', [qw(admins)], 'Admins').$fmt{'administrators'};
		FLAG:
        foreach my $flag (keys %flags) {	# bug, status, version
	        my @types = @{$flags{$flag}};
			($fmt{'graph'}{$flag}) = $self->href('graph', [$flag], ucfirst($flag));
			TYPE:
	        foreach my $type (@types) {		# aix, closed, 5.7.%
				if ($flag eq 'version') {
					$type = "$1.$2.%" if $type =~ /^(\d)\.0*([1-9])([\d\.\%]).*$/; # Do::stats 
					my $v = $fmt{'version'}{$type};
					next TYPE unless $v =~ /\%/;
					my $o = $fmt{'version'}{'Open'}{$type};
				}
	            $self->debug(3, "Overview format($fmt) flag($flag), type($type)") if $DEBUG;
                if ($fmt =~ /^[IhHL]$/) { # HTML
					$fmt{$type} = $self->href("query&$flag=$type", [], "$fmt{$flag}{$type}", '');
	                if (($fmt{$flag}{'Open'}{$type} =~ /^(\d+)$/) && ($flag ne 'status')) {
						($fmt{$type}) .= '&nbsp;('.$self->href("query&$flag=$type&status=open", [], "$fmt{$flag}{'Open'}{$type}", '').')';
	                }
	            } else {                	 # ASCII
	                $fmt{$type} = "$fmt{$flag}{$type}";
	                if (($flag ne 'status') && defined($fmt{$flag}{'Open'}{$type}) && ($fmt{$flag}{'Open'}{$type} =~ /^(\d+)$/)) {
	                    $fmt{$type} .= "($fmt{$flag}{'Open'}{$type})";
	                } 
				}
	        }
	    }
		$fmt{'ratio_t2a'} .= " ($fmt{'ratio_o2a'})"; 
		my $xformat = "FORMAT_O_$fmt";
		my ($top, $_format, @args) = $self->$xformat(\%fmt); 
		# this bit's a melange ...
		$= = 1000;	# lines per page
		$^A = ""; 								# set
		if ($fmt =~ /[aAl]/) {
			formline($_format, @args);			# 1
		} else {
			$^A = $_format;
		}
		$ret = $self->pre($fmt).
				$top.$^A .
			    $self->post($fmt);	
		$^A = ""; 								# reset
	}

    return $ret;    
}


=item FORMAT_O_l

Formating for lean overview (currently wrapper for L<FORMAT_a>

	my ($top, $format, @args) = $o_fmt->FORMAT_l(\%overview);
    
=cut

sub FORMAT_O_l { my $self = shift; return $self->FORMAT_O_a(@_); }


=item FORMAT_O_L

Formating for Lean Html overview (currently wrapper for L<FORMAT_h>

	my ($top, $format, @args) = $o_fmt->FORMAT_L(\%overview);
    
=cut

sub FORMAT_O_L { my $self = shift; return $self->FORMAT_O_h(@_); }


=item FORMAT_O_a

Formating for overview (default).

	my ($top, $format, @args) = $o_fmt->FORMAT_a(\%overview);
    
=cut

sub FORMAT_O_a {
	my $self = shift;

	my $h_fmt= shift;
	my %fmt  = %{$h_fmt};
	my @args = (
		$fmt{'bug'}, $fmt{'message'}, $fmt{'patch'}, $fmt{'test'}, $fmt{'note'}, $fmt{'user'}, $fmt{'days1'}, $fmt{'days7'}, $fmt{'days30'}, $fmt{'days90'},
		$fmt{'ratio_o2c'}, $fmt{'ratio_c2o'}, $fmt{'ratio_m2t'}, $fmt{'ratio_t2a'},
		$fmt{'open'}, $fmt{'closed'}, $fmt{'busy'}, $fmt{'onhold'}, $fmt{'abandoned'}, $fmt{'duplicate'},
		$fmt{'install'}, $fmt{'library'}, $fmt{'patch'}, $fmt{'core'}, $fmt{'docs'}, $fmt{'utilities'},
		$fmt{'unknown'}, $fmt{'notabug'}, $fmt{'ok'},
		$fmt{'fatal'}, $fmt{'high'}, $fmt{'medium'}, $fmt{'low'}, $fmt{'wishlist'},
		$fmt{'linux'}, $fmt{'generic'}, $fmt{'solaris'}, $fmt{'freebsd'}, $fmt{'hpux'}, $fmt{'aix'}, $fmt{'mswin32'},
		$fmt{'version'}{'Open'}{'5.3.%'},
		$fmt{'version'}{'Open'}{'5.4.%'},
		$fmt{'version'}{'Open'}{'5.5.%'},
		$fmt{'version'}{'Open'}{'5.6.%'},
		$fmt{'version'}{'Open'}{'5.7.%'},
		$fmt{'version'}{'Open'}{'5.8.%'},
		$fmt{'version'}{'Open'}{'5.9.%'},
	);
	my $top = qq|PerlBug Database overview, figures in brackets() are still open:
-------------------------------------------------------------------------------|;
	my $format = qq|
Bugs     Messages Patches Tests  Notes  Admins  24hrs   7days   30days   90days   
@<<<<<<< @<<<<<<< @<<<<<< @<<<<< @<<<<< @<<<<<< @<<<<<< @<<<<<< @<<<<<<< @<<<<<
Ratios:     Open to Closed   Closed to Open   Msgs to Bugs     Bugs to Admins 
            @<<<<<<<<<<<<<   @<<<<<<<<<<<<<   @<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<
Status:     Open       Closed     Busy       Onhold     Abandoned  Duplicate                                          
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
Group:      Install    Library    Patch      Core       Docs       Utilities     
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
            Unknown    Notabug    OK
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
Severity:   Fatal      High       Medium     Low        Wishlist
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< 
OS:         Linux      Generic    Solaris    Freebsd    Hpux       Aix       MSwin32   
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<    @<<<<<<<<< @<<<<<<<< @<<<<<<<<
Versions:   5.3.*      5.4.*      5.5.*      5.6.*      5.7.*      5.8.*     5.9.*
            @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<<< @<<<<<<<< @<<<<<<<<
		|; # 17, 33, 12, 7, 11, 14, 22, 3, 15, 20 , 40 , 26, 43, 42, 9, 34
		   # linux solaris generic dec_osf freebsd hpux mswin32 aix irix machten

	return ($top, $format, @args);
}


=item FORMAT_O_A

Formatting for ASCII overview.

	my ($top, $format, @args) = $o_fmt->FORMAT_O_A(\%overview);

=cut

sub FORMAT_O_A {
	my $self = shift;
	my $x   = shift;

	my $top = qq|PerlBug Database overview, figures in brackets() are still open:
-------------------------------------------------------------------------------
|;
	my $format = '';
	my @args = ();
	my @keys = ($self->things('mail'), $self->things('item'), $self->things('flag'));
	my $cnt = 0;
	KEY:
	foreach my $key (keys %{$x}) { 					# bug, group, status, note...
		next KEY unless grep(/^$key$/, @keys); 
		# print "Found key($key)\n";
		$cnt++;
		my $h_item = $$x{$key};
		if (ref($h_item) eq 'HASH') {
			# print "found H_data($h_item)\n";
			push (@args, ucfirst($key));
			$format .= '@<<<<<<<<<<<<<<<<< '."\n";
			ITEM:
			foreach my $item (keys %{$h_item}) {	# open, closed, aix, etc.
				next ITEM if $item eq 'Open';
				push(@args,  $item, $$h_item{$item}, $$h_item{'Open'}{$item});
				# print "found item($item), total($$h_item{$item}), open($$h_item{'Open'}{$item})\n";
				$format .= '    @<<<<<<<<<<<  @<<<<<<<<<  @<<<<<<< '."\n";
			}
			$format .= "\n";
		}
	}
	$format .= qq|
-------------------------------------------------------------------------------
	|;


	return ($top, $format, @args);
}


=item FORMAT_O_h

Formatting for html overview.

	my ($top, $format, @args) = $o_fmt->FORMAT_O_h(\%overview);

=cut

sub FORMAT_O_h {
	my $self = shift;
	my $h_fmt= shift;

	my %fmt  = %{$h_fmt};
	my $top  = '<p>';
	my $url = $self->url;
	my ($full) = $self->href('overview&format=H', [], 'full overview', 'ALL bug <-> flags data (be a little patient, please :)');
	my $format = qq|
<table border=1><tr>
<td colspan=9><h3>Perlbug Database overview: all bugs</h3></td>
</tr>
<tr>
<td colspan=4><i>Figures in brackets() are still open</i></td>
<td colspan=5>For full details see: <b>$full</b> <i>(be patient)</i></td></tr>
<tr>
	<td><b>
	$fmt{'graph'}{'user'}
	</b></td>
	<td><b>Bugs:</b> &nbsp;
	$fmt{'bug'}
	</td>
	<td><b>Messages:</b> &nbsp;
	$fmt{'message'}
	</td>
	<td><b>Patches:</b> &nbsp;
	$fmt{'patche'}
	</td>
	<td><b>Notes:</b> &nbsp;
	$fmt{'note'}
	</td>
	<td><b>Tests:</b> &nbsp;
	$fmt{'tests'}
	</td>
	<td><b>Bugs to Messages:</b> &nbsp;
	$fmt{'ratio_m2t'}
	</td>
	<td colspan=2><b>Bugs to admins</b> &nbsp;
	$fmt{'ratio_t2a'}
	</td>
</TR>
<TR>
	<td><b>
	$fmt{'graph'}{'dates'}
	</b>&nbsp;</td>
	<td><b>24hrs:</b> &nbsp;
	$fmt{'days1'}
	</td><td><b>7 days:</b> &nbsp;
	$fmt{'days7'}
	</td><td><b>30 days:</b> &nbsp;
	$fmt{'days30'}
	</td><td><b>90 days:</b> &nbsp;
	$fmt{'days90'}
	</td><td colspan=2><b>Over 90 days:</b> &nbsp;
	$fmt{'90plus'}
	</td>
	<td>&nbsp;</td>
	</td><td>&nbsp;</td> 
</TR>
<TR>
	<td><b>
	$fmt{'graph'}{'status'}
	</b>&nbsp;
	</td>
	<td><b>Open:</b> &nbsp;
	$fmt{'open'}
	</td>
	<td><b>Closed:</b> &nbsp;
	$fmt{'closed'}
	</td><td><b>Busy:</b> &nbsp;
	$fmt{'busy'}
	</td>
	<td><b>Ok:</b> &nbsp;
	$fmt{'ok'}
	</td>
	<td><b>Onhold:</b> &nbsp;
	$fmt{'onhold'}
	</td>
	<td><b>Abandoned:</b> &nbsp;
	$fmt{'abandoned'}
	</td>
	<td><b>Duplicate:</b> &nbsp;
	$fmt{'duplicate'}
	</td>
	<td>&nbsp;</td>
</TR>
<TR>
	<td><b>
	$fmt{'graph'}{'group'}
	</b>&nbsp;</td>
	<td><b>Install:</b> &nbsp;
	$fmt{'install'}
	</td><td><b>Library:</b> &nbsp;
	$fmt{'library'}
	</td><td><b>Patch:</b> &nbsp;
	$fmt{'patch'}
	</td><td><b>Core:</b> &nbsp;
	$fmt{'core'}
	</td><td><b>Docs:</b> &nbsp;
	$fmt{'docs'}
	</td><td><b>Utilities:</b> &nbsp;
	$fmt{'utilities'}
	<td><b>Notabug:</b> &nbsp;
	$fmt{'notabug'}
	</td><td><b>Unknown:</b> &nbsp;
	$fmt{'unknown'}
	</td>
</TR>
<TR>
	<td><b>
	$fmt{'graph'}{'severity'}
	</b>&nbsp;
	</td><td><b>Fatal:</b> &nbsp;
	$fmt{'fatal'}
	</td><td><b>High:</b> &nbsp;
	$fmt{'high'}
	</td><td><b>Medium:</b> &nbsp;
	$fmt{'medium'}
	</td><td><b>Low:</b> &nbsp;
	$fmt{'low'}
	</td><td><b>Wishlist:</b> &nbsp;
	$fmt{'wishlist'}
	</td><td><b>None:</b> &nbsp;
	$fmt{'none'}
	</td><td>&nbsp;</td> 
	</td><td>&nbsp;</td> 
	</td>
</TR>
<TR>
	<td><b>
	$fmt{'graph'}{'osname'}
	</b>&nbsp;</td>
	<td><b>Generic:</b> &nbsp;
	$fmt{'generic'}
	</td><td><b>Linux:</b> &nbsp;
	$fmt{'linux'}
	</td><td><b>FreeBSD:</b> &nbsp;
	$fmt{'freebsd'}
	</td><td><b>Solaris:</b> &nbsp;
	$fmt{'solaris'}
	</td><td><b>HPux:</b> &nbsp;
	$fmt{'hpux'}
	</td><td><b>Aix:</b> &nbsp;
	$fmt{'aix'}}
	</td><td><b>Win32:</b> &nbsp;
	$fmt{'mswin32'}
	</td><td><b>MacOS:</b> &nbsp;
	$fmt{'macos'}
	</td>
</TR>>
<TR>
	<td><b>Versions:</b>  &nbsp;
	</td><td><b>5.002.*:</b> &nbsp;
	$fmt{'version'}{'5.2.%'} ($fmt{'version'}{'Open'}{'5.2.%'})
	</td><td><b>5.003.*:</b> &nbsp;
	$fmt{'version'}{'5.3.%'} ($fmt{'version'}{'Open'}{'5.3.%'})
	</td><td><b>5.004.*:</b> &nbsp;
	$fmt{'version'}{'5.4.%'} ($fmt{'version'}{'Open'}{'5.4.%'})
	</td><td><b>5.005*</b> &nbsp;
	$fmt{'version'}{'5.5.%'} ($fmt{'version'}{'Open'}{'5.5.%'})
	</td><td><b>5.6.*:</b> &nbsp;
	$fmt{'version'}{'5.6.%'} ($fmt{'version'}{'Open'}{'5.6.%'})
	</td><td><b>5.7.*:</b> &nbsp;
	$fmt{'version'}{'5.7.%'} ($fmt{'version'}{'Open'}{'5.7.%'})
	</td><td><b>5.8.*:</b> &nbsp;
	$fmt{'version'}{'5.8.%'} ($fmt{'version'}{'Open'}{'5.8.%'})
	</td><td><b>5.9.*:</b> &nbsp;
	$fmt{'version'}{'5.9.%'} ($fmt{'version'}{'Open'}{'5.9.%'})
	</td>
</TR>

</table>
|;

	return ($top, $format, ());
}


=item FORMAT_O_H

Formatting for HTML overview.

	my ($top, $format, @args) = $o_fmt->FORMAT_O_H(\%overview);

=cut

sub FORMAT_O_H {
	my $self = shift;
	# return $self->FORMAT_O_h(@_); # rjsf: for now
	my $x   = shift;

	my $top = qq|<h2>PerlBug Database overview, figures in brackets() are still open:</h2> <hr> |;
	my $format = '<table border=0><tr>';
	my @args = ();
	my @keys = ($self->things('mail'), $self->things('item'), $self->things('flag'));
	my $cnt = 0;
	KEY:
	foreach my $key (sort keys %{$x}) {					# bug, group, status, note...
		next KEY unless grep(/^$key$/, @keys); 
		# print "Found key($key)\n";
		$cnt++;
		my $h_item = $$x{$key};
		if (ref($h_item) eq 'HASH') {
			# print "found H_data($h_item)\n";
			$format .= qq|<td valign=top><table border=1><tr>
				<td>&nbsp;</td>
				<td><b>|.ucfirst($key).q|</b></td>
				<td><b>Total</b></td>
				<td><b>Open</b></td>
			</tr>|; 
			ITEM:
			foreach my $item (sort keys %{$h_item}) {	# open, closed, aix, etc.
				next ITEM if $item eq 'Open';
				$format .= qq|<tr>
					<td>&nbsp;</td>
					<td>$item &nbsp;</td>
					<td>$$h_item{$item} &nbsp;</td>
					<td>$$h_item{'Open'}{$item} &nbsp;</td>
				</tr>|; 
				# print "found item($item), total($$h_item{$item}), open($$h_item{'Open'}{$item})\n";
			}
			$format .= qq|<tr><td colspan=4>&nbsp;</td></tr>
				</table></td>|;
		}
	}
	$format .= qq|</tr></table><hr>|; 
	$format =~ s/\s+/ /;


	return ($top, $format, @args);
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999 2000 2001

=cut

1;
