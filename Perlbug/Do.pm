# Perlbug functions
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Do.pm,v 1.68 2002/01/11 13:51:05 richardf Exp $
#
# TODO 
# see doh
# 

=head1 NAME

Perlbug::Do - Commands (switches) for generic interface to perlbug database.

=cut

package Perlbug::Do; 
use Data::Dumper;
use strict;
use vars qw($VERSION);
$VERSION = do { my @r = (q$Revision: 1.68 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1; 


=head1 DESCRIPTION

Methods for various functions against the perlbug database.  

Those that have the form /do(?i:a-z)/ all return something relevant.

To be printed, returned by email, etc.

=cut


=head1 SYNOPSIS

Note that all B<do...()> methods expect to recieve one of the following arguments:

Either a string, an arrayref, or a hashref (helpful - huh?)

	my $h_cmds = $o_do->parse_input($line); # parse string

	print $o_do->process_commands($h_cmds); # calls do($cmd, $args) foreach 


=head1 METHODS

=over 2


=item new

Create new Perlbug::Do object:

	my $o_do = Perlbug::Do->new();

=cut

sub new {
    my $proto = shift;
	my $class = ref($proto) || $proto; 

   	bless({}, $class);
}


=item parse_input

Parses the given line into a reference to a command hash, this is also where
the input should be massaged into the correct format for each method call.

Wraps B<input2args()>, override on a per interface basis, where appropriate.

Input line is expected to look like: -h -b (bugid)+ -r (keywords)+ ...

    my $h_cmds = $o_do->parse_input($line); 

=cut

sub parse_input {
    my $self = shift;
    my $line = shift;
	my %cmds = ();
    $self->{'attr'}{'commands'} = {};

    if ($line !~ /\-\w+/) {
		$cmds{'h'} = "invalid command($line)";
		$self->debug(0, "requires a valid command($line)!");
    } else {
		%cmds = %{$self->parse_line($line)};
		COMMANDS:
		foreach my $cmd (keys %cmds) {
			$cmds{$cmd} = $self->input2args($cmd, $cmds{$cmd});
		}
	}

	$self->{'commands'} = \%cmds;

	$self->debug(0, "Do input($line): ".Dumper(\%cmds)) if $Perlbug::DEBUG;

    return \%cmds;
}


=item parse_line

parse_input without the input2args

    my $h_cmds = $o_do->parse_input($line); 

=cut

sub parse_line {
    my $self = shift;
    my $line = shift;
	my %cmds = ();
    $self->{'attr'}{'commands'} = {};

    if ($line !~ /\-\w+/) {
		$cmds{'h'} = "invalid command($line)";
		$self->debug(0, "requires a valid command($line)!");
    } else {
		CHUNK: {
			$cmds{$1} = '',	redo CHUNK if $line =~ /\G\s*-([a-zA-Z])\s*$/ciog;			# -h
			$cmds{$1} = $2,	redo CHUNK if $line =~ /\G\s*-([a-zA-Z])\s*([^-]+)/cigo;		# -d 2
	    };      
		$self->debug(1, "Commands($line): ".Dumper(\%cmds)) if $Perlbug::DEBUG;
	}

	$self->{'commands'} = \%cmds;
    return \%cmds;
}


=item return_type

Return appropriate type of argument wanted given command

	my $wanted = $self->return_type($cmd);

	eg:
		b -> ARRAY 
		P -> HASH
		s -> SCALAR 

=cut

sub return_type {
	my $self = shift;
	my $cmd  = shift || '';

	my $wanted = 
		$cmd =~ /^[aBCGMNPTUVv]$/o ? 'HASH' : 
		$cmd =~ /^[dfhHloqrsz]$/o ? 'SCALAR' : 
		'ARRAY'; # default
	;

	return $wanted;
}


=item input2args

Handles email input, calls B<SUPER::input2args()>

	my $cmd_args = $o_do->input2args($cmd, $args);

=cut

sub input2args {
	my $self = shift;
	my $cmd  = shift;
	my $arg  = shift || '';
	my $ret  = '';

	$cmd =~ s/^\s+//o;
	$cmd =~ s/\s+$//o;
	$arg =~ s/^\s+//o;
	$arg =~ s/\s+$//o;

	my $wanted = $self->return_type($cmd);

	if ($wanted eq 'ARRAY') {
		my @ret = (ref($arg) eq 'ARRAY') ? @{$arg} : split(/\s+/, $arg);
		$ret = \@ret;
	} elsif ($wanted eq 'HASH') {	
		my ($opts, $body) = ($arg =~ m/^\s*(?:opts\s*\(\s*([^)]+)\s*\))\s*(.+)/mso)
			? ($1, $2) : ('', $arg);
		$ret = {
			'body'	=> $body,
			'opts'	=> $opts,
		};
	} else {
		$ret = $arg;
	}

	$self->debug(2, "cmd($cmd) arg($arg) => ret: ".Dumper($ret)) if $Perlbug::DEBUG;
	
	return $ret;
}


=item process_commands

Interface to all B<do()> methods, calls B<SUPER::process_commands()>.

	my @res = $o_do->process_commands(\%args);

Where B<%args> looks something like this:

	my %args = (	
		'a'	=> \@categories_status_etc,
		'B' => \%new_data,	
		'b' => \@bug_ids,
		'h' => \%extra_info,
		'l'	=> $date || '',
		'q' => $sql_query,
		'z' => $config_type,
		'Z' => [($type, $string)],
	); 

=cut

sub process_commands {
	my $self   = shift;
    my $h_cmds = shift;	# 
    my @res    = ();

	if (!ref($h_cmds)) {
		$self->error("requires commands($h_cmds)!");
	} else {
		my %cmds = %{$h_cmds}; 
		$self->debug(2, "processing(\%cmds): ".Dumper(\%cmds)) if $Perlbug::DEBUG;
		# my %adminable = ();
		# %adminable = map { $_ => ++$adminable{$_} } $self->switches('admin');
		SWITCH:
		foreach my $switch (keys %cmds) {
			next SWITCH unless $switch =~ /^\w+$/o;
			next SWITCH unless grep(/^$switch$/, $self->switches);
			# if (!$self->isadmin) {
			#	next SWITCH if $adminable{$switch};
			#}
			if (!($self->can("do$switch"))) {
				$self->error("Unrecognised switch($switch) next..."); 
			} else {
				$cmds{$switch} = '' unless $cmds{$switch};
				$self->debug(1, "processing($switch, $cmds{$switch})...") if $Perlbug::DEBUG;
				my @result = $self->do($switch, $cmds{$switch}); 
				push(@res, "$switch: => ".join("\n", @result));
				$self->debug(1, "processed(@res)") if $Perlbug::DEBUG;
			}
		}
	}

    return @res;
}


=item do

Wrap a Perlbug::dox command where 'x' may be any alphabetic character.

Each B<do()> command returns the product of it's call for output.

    print "Bugs(@bugids): ".join('', $pb->do('b', \@bugids));

    print "New bug: ".join('', $pb->do('B', '', $newbug));

    print "New msg: ".join('', $pb->do('M', $bugidstring, $message)); # Base 

    print "New msg: ".join('', $pb->do('M', $bugidstring, \%mail));   # Email

=cut

sub do {
    my $self = shift;
    my $arg  = shift; # char
	my $cmd  = shift; # string or array_ref, or hashref
    my @res  = ();

	SWITCH:
	if ($arg !~ /^\w+$/) {
		$self->error("Can't do $arg($cmd)!");
	} else {
		my $this = "do$arg";
		$DB::single=2;
    	@res = $self->$this($cmd);
	    $self->debug(3, "called $this($cmd) -> res(@res)") if $Perlbug::DEBUG;
	}

	return @res;
}

# -----------------------------------------------------------------------------
# From here are all the do\w commands
# -----------------------------------------------------------------------------

=item doa

ONLY do this if registered as admin

	my @res = $o_do->doa($command_string);

=cut

sub doa {
    my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my @res    = ();

	my %cmds = $self->parse_str($$h_args{'opts'} || $$h_args{'_opts'});
	my @bids = ref($cmds{'bug'}{'ids'}) eq 'ARRAY' ? @{$cmds{'bug'}{'ids'}} : ();

	if (!(@bids >= 1)) {
		$self->error("requires bugids(@bids) to administrate!");
	} else {
		my $o_bug = $self->object('bug');
		my $o_note = $self->object('note');

	    foreach my $b (@bids) {
	        next unless $o_bug->ok_ids([$b]);
			my $orig = $o_bug->read($b)->format('a');
			if (!$o_bug->READ) {		
				push(@res, "Bugid($b) read failure");
			} else {
				my $i_rel = $o_bug->relate(\%cmds);
				my $o_int = $self->setup_int($o_bug->data('header'), $o_bug->data('body'));
				my ($o_hdr, $header, $body) = $self->splice($o_int);
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
					'email_msgid'	=> 'no-B-msgid',
				});
				if ($o_note->CREATED) {
					my $nid = $o_note->oid;
					$o_bug->rel('note')->assign([$nid]);
				}
				if ($self->current('mailing') == 1) {
					my $i_x = $self->notify_cc($b, $orig) unless grep(/nocc/, $cmds{'unknown'});
				}
			}
            $self->debug(2, "Bug ($b)  administration done") if $Perlbug::DEBUG;
			my $current = $o_bug->read($b)->format('a');
			push(@res, "Current status (post admin)\n$current\n");
			my $diff = $o_bug->diff($orig, $current);
			push(@res, "Difference from previous status (by line): \n$diff\n");
	    }
	    $self->debug(2, "All administration commands done") if $Perlbug::DEBUG;
	} 

	return @res;
}


=item doA

Wrapper for L<doa()>, calls L<dob()> also.

	my @res = $o_do->doa($command_string);

=cut

sub doA {
    my $self = shift;
	my $cmds = shift;
	my @res  = ();

	my %cmds = $self->parse_str($cmds);

	my @bids = ref($cmds{'bug'}{'ids'}) eq 'ARRAY' ? @{$cmds{'bug'}{'ids'}} : ();

	if (!(@bids >= 1)) {
		$self->error("requires bugids(@bids) to Administrate!");
	} else {
		push(@res, $self->doa($cmds));

		push(@res, $self->dob($cmds{'bug'}{'ids'}));
	}

	return @res;
}


=item dob

Return the formatted bug by id/s

    my @res = $o_do->dob(@bugids);

=cut

sub dob {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	my $fmt   = $self->current('format');
	my $o_obj = $self->object('bug');

	foreach my $i ($o_obj->ok_ids(\@ids)) {
		my $str = $o_obj->read($i)->format($fmt);
		push(@res, $str);
	} 
	$self->debug(1, "bug ids(@ids)") if $Perlbug::DEBUG;

	return @res;
}


=item doB

Create new bug, returning id.

    my $bugid = $o_do->doB(\%bug);

=cut

sub doB {
    my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $bug    = $args{'body'};
	my $target = 'bug';
	my $id     = '';

	if ($bug !~ /\w+/) {
		$self->error("requires a valid $target($args{'body'}) to insert");
	} else {
		my $o_obj = $self->object($target);
		my $newid = $o_obj->new_id;
		$o_obj->create({
			$target.'id'	=> $newid,
			'subject'		=> 'no-subject-given', 
			'sourceaddr'	=> 'no-sourceaddr-given', 
			'toaddr'		=> 'no-toaddr-given', 
			'header'		=> 'no-header-given', 
			'body'			=> 'no-body-given',
			'email_msgid'	=> 'no-msgid-given',
			%args,
		});	

		if (!($o_obj->CREATED)) {
			$self->error("failed to create new($newid) $target: ".Dumper($h_args));	
		} else {
			$id = $o_obj->oid;
			my %cmds = $self->parse_str($args{'opts'} || $args{'_opts'});
			my $i_rel = $o_obj->relate(\%cmds);
			my $i_ok = $self->notify($target, $id); 
		}
	}

    return $id;
}


=item doc

Get the patches, or bugs for this changeid 

	my @res = $o_do->doc(\@cids);	

=cut

sub doc {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	foreach my $id (@ids) {
        next unless $id =~ /^\d+$/o;
		my $o_chg = $self->object('change')->read($id);
		my @pids = $o_chg->relation('patch')->ids($o_chg);
		$self->debug(2, "found pids(@pids) related to changeid($id)") if $Perlbug::DEBUG;
		if (scalar(@pids) >= 1) {
			push(@res, $self->dop(\@pids));
        } else { # 
			print "No patches found with changeid($id), trying with bugs...<br>\n" if $0 =~ /cgi$/; 
			my @bids = $o_chg->relation('bug')->ids($o_chg);
			$self->debug(2, "found bids(@bids) related to changeid($id)") if $Perlbug::DEBUG;
			if (scalar(@bids) >= 1) {
				push(@res, $self->dob(\@bids));
			}	
		}
    }
	$self->debug(2, "found ".@res." related items to ids(@ids)") if $Perlbug::DEBUG;

	return @res;
}


=item doC

Create a new changeid

	my $cid = $o_do->doC($h_args);

=cut

sub doC {
	my $self = shift;
	return "Change-Id creation unsupported at this time";
}


=item dod

Switches debugging on (1).

	my $level_set = $o_do->dod($level);

=cut

sub dod {
	my $self  = shift;
	my $level = shift;

	my $res   = $self->current('debug');

    if ($level =~ /^\w+$/o) {
		$res = $self->set_debug($level);
    }

	return $res;
}


=item doD

Dumps database for backup and recovery.

	my $feedback = $o_do->doD($date);

=cut

sub doD { # Dump Database (for recovery)
    my $self  = shift;
	my $since = shift;
    my $i_ok  = 1;
	my $res   = '';

    $self->debug(2, "DB dump($since) requested by '".$self->isadmin."'") if $Perlbug::DEBUG;

	my $adir = $self->directory('arch');
	my $date = $self->current('date');
	my $tdir = $self->directory('spool').'/temp';
	my $pdir = $self->directory('perlbug');
	my $target = File::Spec->canonpath($tdir.'/'.$self->database('latest'));
	my $tgt  = ($since =~ /\d+/o) ? "from_$since" : $date;
	$target =~ s/^(.+?\.)gz/${1}$tgt\.gz/;
	my $dage = $self->database('backup_interval');

	if (($since !~ /\d+/) && (-e $target) && (-M _ >= $dage)) {
		$res ="Recent($date) non-incremental database dump($target) found less than $dage days old";
	} else {
		my $dump = $self->database_dump_command($target, $since);
		if (!(defined($dump))) {
			$res = "Failed to get database dump command($dump)";
		} else {	
			$dump =~ s/\s+/ /go;
			$i_ok = !system($dump); 		# doit
			my ($ts) = $self->get_list("SELECT SYSDATE() + 0");
			if ($since !~ /\d+/) { 			# full blown backup
				if (!($i_ok == 1 && -f $target)) {
					$res = "Looks like database backup failed: $? $!";
				} else {
					my $arch = File::Spec->canonpath($adir."/Perlbug.sql.${date}.gz");
					my $lach = File::Spec->canonpath($adir.'/'.$self->database('latest'));
					$i_ok = $self->copy($target, $arch);
					$res = "Database backup copy($i_ok)";
					if ($i_ok == 1) {
						$i_ok = $self->link($arch, $lach, '-f');
						$res .= ", database backup link($i_ok)";
					}	
				}
			}
		}
	}
	return $res;
}


=item database_dump_command 

Returns database dump command (mysql/oracle) for given date (or full) and target file.

else undef 

    my $cmd = $o_do->database_dump_command($date, $file);

=cut

sub database_dump_command { # get database dump command
	my $self   = shift;
	my $target = shift;
	my $date   = shift;
	my $i_ok   = 1;
	my $cmd    = '';

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
			$self->error("Null or invalid numerical date($date) given, dumping entire db.");
		} else {
			if (!($date =~ /^(\d{8,14})$/o)) {
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
					$self->debug(2, "Accepting date($filter, $check) min($min) and max($max)") if $Perlbug::DEBUG;
					$args .= " -w'ts>=$filter'";
				}
			}
		}
		$cmd = "$bakup $args -u$user -p$pass $db | $comp > $target" if $i_ok == 1; # ek
	} 
	return $cmd;
}


=item doe

Add email address to any cc's 'Cc:' to "-e me.too@some.where.org"

	my $i_set = $o_do->doe($cc_addrs);

=cut

sub doe {
    my $self  = shift;
	my $a_args= shift;
	my $addrs = @{$a_args};

	my @ccs = $self->parse_addrs($addrs);
	my $ccs = join(', ', @ccs);

	$self->current({'cc' => $ccs});

	my $res = "Cc($addrs) set to ($ccs)";

    $self->debug(2, $res) if $Perlbug::DEBUG;

	return $res;
}


=item doE

Send an email notify() about th(is|ese) bugid/s, as if the email was newly recieved.

	my $i_ok = $o_obj->doE(\@bugids); 

=cut

sub doE {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my $i_res = 0;

	foreach my $bugid (@ids) {
		$i_res += $self->notify('bug', $bugid);
	}

	return $i_res;
}


=item dof

Sets the appropriate format for use by L<Formatter> methods, overrides default 'a' set earlier.

	my $feedback = $o_obj->dof('h'); 

=cut

sub dof {
	my $self = shift;
	my $fmt  = shift;

	my $cur  = $self->current('format');
	my $res  = '';

	if ($fmt =~ /^[ahilx]$/io) {
		my $new = $self->current({'format' => $fmt});
		$res .= "current format($cur), new format($new) set";
	}

	return $res;
}


=item dog

Return the formatted group by id/s

    my @res = $o_do->dog(\@groupids);

=cut

sub dog {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	my $fmt   = $self->current('format');
	my $o_obj = $self->object('group');

	foreach my $i (@ids) {
	    next unless $i =~ /^\d+$/o;
		my $str = $o_obj->read($i)->format($fmt);
		push(@res, $str);
	} 

	$self->debug(2, "group ids(@ids)") if $Perlbug::DEBUG;

	return @res;
}


=item doG

Create new group 

    my $new_gid = $o_do->doG($h_args);

=cut

sub doG {
	my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $target = 'group';
	my $id     = 0;

	if (!($args{'name'} =~ /^\w+$/o && $args{'description'} =~ /\w+/o)) {
		$self->error("requires a valid alphanumeric name($args{'name'}) and a $target($args{'description'}) to insert");
	} else {
		my $o_obj = $self->object($target);
		$o_obj->create({
			$target.'id'	=> $o_obj->new_id,
			'name'			=> 'no-name-given', 
			'description' 	=> 'no-description-given',
			%args
		});
		if (!($o_obj->CREATED)) {
			$self->error("failed to create $target: ".Dumper($h_args)); 
		} else {
			$id = $o_obj->oid;
			my %cmds  = $self->parse_str($args{'opts'} || $args{'_opts'});
			my $i_rel = $o_obj->relate(\%cmds);
			# $self->notify($target, $id); - no header :-)
		}
	}		

	return $id;
}


=item doh

Returns help message built from a hash_ref

Syntax for the hash is 'key => description (sample args)': 

	print $o_obj->doh({ 
		'e' => 'email me a copy too (email@address.com)', 	
		# add 'H' => 'Help - more detailed info ()',			
		# replace 'z' => '', 						
	}); 
	
=cut 

sub doh { 
	my $self = shift; 
	my $args = shift; 
	my @args = (ref($args) eq 'HASH') ? %{$args} : (); 

	my $data = qq| 
Switches are sent on the subject line, dash may be omitted if only option: 
-------------------------------------------------------------------------------- 
|; 
	# A = Admin 
	# B = Bugmaster 
	# C = Cc list (or master list or admin) 
	# 
	# should migrate: 
	# a = admin retrieval (CREATE_table pb_admin, admin_id, admin_name, ...) 
	# A = create admin entry 
	# 
	# i = index retrieval by group, status, severity, osname 
	# 
	# u = update status of bugs 
	# U = update and return bugs 
	#
	# appending an 'r' to any search criteria will return relations 
	# appending an 'R' to any search criteria will return fully expanded relations 
	# -br 19870502.007
	# 
	#   cmd    explanation                                args                              # ?		
	my %data = ( 
		'a' => 'administration command - cmds bugids      (close b 19990606.002 [...])',	# A 
		'A' => 'Administration command and return bugs    (c build 19990606.002 [...])', 	# A 
		'b' => 'bug retrieval by bugid                    (19990606.002 [...])', 
		'B' => 'INSERT a new bug                          (opts(build) new bug entry here)',# A 
		'c' => 'change id retrieval, patches, bugs.       (12 777 c8123 c55)', 					
		'C' => 'INSERT a Change against a bugid           (opts(19990606.002) changeid)',	# A 
		'd' => 'debug flag data goes in logfile           ()', 								# A 
		'D' => 'Dump database for backup                  ()',    							# A 
		'e' => 'email me too, if any emails sent          (email.me@as.well.com)',
		#cmd?email 'E' => 'Email a notification as if never recieved (19990606.002)',					# A 
		'f' => 'format of data ascii|html|lean            ([aA|hH|l])', 
		'g' => 'group info retrieval                      (patch|install|docs|...])', 
		'G' => 'new group                                 (another_group_name)', 			# A 
		'h' => 'help - this message                       ()', 
		'H' => 'more detailed help                        ()', 
		'i' => 'index retrieval criteria                  (open high aix)', 
		'I' => 'Index retrieval criteria more detail      (open high aix)', 
		'j' => 'just test for a response                  ()', 
		'k' => 'claim a bug with optional email addr      (19990606.002 me@here.net [...])',# C 
		'K' => 'unClaim this bug - remove from cc         (19990606.002 me@here.net [...])',# C 
		'l' => 'log of current process                    ()', 								# A 
		'L' => 'Logfile - todays complete retrieval       ()', 								# A 
		'm' => 'retrieval by messageid                    (13 47 23 [...])', 
		'M' => 'INSERT a Message against a bugid          (opts(19990606.002) some_message)',# A 
		'n' => 'note retrieval                            (76 33 1  [...])', 
		'N' => 'INSERT a Note against a bugid             (opts(19990606.002) some_note)',	# A 
		'o' => 'overview of bugs in db                    ()', 
		'O' => 'Overview of bugs in db - more detail      ()', 
		'p' => 'patch retrieval                           (patchid)', # change 
		'P' => 'INSERT a Patch against a bugid            (opts(19990606.002) some_patch)',	# A 
		'q' => 'query the db directly                     (select * from db_type where 1 = 0)', 
		'Q' => 'Query the schema for the db               ()', 
		'r' => 'retrieve bug body search                  (d_sigaction=define)', 
		'R' => 'Retrieve bug body search more detail      (d_sigaction=define)', 
		's' => 'subject search by literal                 (bug in docs)', 
		'S' => 'Subject search more detail                (bug in docs)', 
		't' => 'test retrieval by testid                  (77 [...])', 
		'T' => 'INSERT a Test against a bugid|patch       (opts(19990606.002) test data)',	# A 
		'u' => 'user retrieval by userid                  (richardf [...])', 				# A 
		'U' => 'INSERT a User as administrator            (userid passwd name address match)', # B 
		'v' => 'volunteer info, forward to admins etc.    (19990606.002 close)', 
		'V' => 'Volunteer as admin',  # 
		'w'	=> 'where group ...', 
		'x' => 'xterminate bug - remove bug               (19990606.002 [...])', 			# A 
		'X' => 'Xterminate bug - and messages             (19990606.002 [...])', 			# A 
		# y -> U 'y' => 'yet another password                      ()', 								# 
		'z' => 'get current configuration data            (debug)',							# A 
		'Z' => 'Zet current configuration data            (debug 1)',						# B 
		@args
	); 
	SWITCH: 
	foreach my $key (sort { lc($a) cmp lc($b) } keys %data) { 
		next SWITCH unless grep(/^$key$/, $self->switches); 
		# next SWITCH unless $key =~ /^\w$/; 
		if ($data{$key} =~ /^\s*([^(]+)\((.*)\)\s*$/o) { 
			my ($desc, $args) = ($1, $2); 
			$desc =~ s/\s+/ /go;
			$args =~ s/\s+/ /go;
			my $combo = length($desc) + length($args); 
			my $x = ($combo >= 1 && $combo <= 70) ? 71 - $combo : 1; 
		
			# allow 9 for wrapping (may run over) 
			my $spaces = ' ' x $x; 
		
			$data .= "$key = $desc".$spaces."(-$key $args)"."\n"; 	 # 80?  
		} 
	} # 
	
	$self->debug(3, 'help retrieved '.length($data)) if $Perlbug::DEBUG;    

	return $data; 
}


=item doi

Retrieve by index (group, status, etc.)

	my @res = $o_do->doi($str); 

=cut 
	
sub doi {
	my $self = shift;
	my $cmds = shift;

	my %cmds = $self->parse_str($cmds);
	my @res  = ();

	# @res = "Currently unsupported"; # rjsf - urgent!

	INDEX:
	foreach my $in (keys %cmds) {
		next INDEX unless $in =~ /\w+/o;
		my $a_tgt = $cmds{$in};
		next INDEX unless ref($a_tgt) eq 'ARRAY' && scalar(@{$a_tgt}) >= 1;
		if ($in !~ /^([a-z]+)(id|name)s/) {
			$self->debug(2, "didn't recognise in($in)!") if $Perlbug::DEBUG;
		} else {
			my ($rel, $type) = ($1, $2);
			my $o_rel = $self->object($rel);
			my @ids = ($type eq 'name') ? $o_rel->name2ids($a_tgt) : @{$a_tgt};
			my @bugids = map { $o_rel->read($_)->rel('bug')->ids } @ids;
			push(@res, @bugids); 
		}			
	}

	return @res;
}


=item doI

Wrapper for L<doi()>, in large format

	my @res = $o_do->doI('open');

=cut

sub doI {
	my $self = shift;
	my $srch = shift;

	my $orig = $self->current('format');
	$self->current('format', uc($orig));

	my @res  = $self->doi($srch);

	$self->current('format', $orig);

	return @res;
}


=item doj 

Just test for a response - produces "$title $version => ok"

	my @res = $o_do->doj(@args); 

=cut 
	
sub doj {
	my $self = shift;

	my $res  = join(' ', $self->system('title'), $self->version, '=>', 'ok');

	return $res;
}


=item dok

Klaim the bug(id) given

	my $feedback = $o_do->dok(\@bids);

=cut

sub dok {
    my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my $res   = '';

    my $admin = $self->isadmin;
	if (scalar(@ids) >= 1 && $admin =~ /\w+/o && $admin ne 'generic') {
		$self->object('user')->read($admin)->relation('bug')->assign(\@ids);
		$res = "Claimed(@ids)";
	}

	return $res;
}


=item doK

UnKlaim the bug(id) given

	my $feedback = $o_do->doK(\@bids);

=cut

sub doK {
    my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

    foreach my $i (@ids) {
        next unless $self->ok_ids([$i]);
        my @res = $self->bug_unclaim($i, $self->isadmin);
		push(@res, "Claimed($i)");
        $self->debug(2, "unclaimed ($i)") if $Perlbug::DEBUG;
    }

	return @res;
}



=item dol

Just the stored log results from this process.

	my $process_log = $o_do->dol($max_lines_from_end);

=cut

sub dol {
    my $self = shift;
	my $max  = shift;
	my $log  = '';

	my @data = $self->log->read;

	my ($switch, $cnt) = (0, 0);

	foreach my $line (@data) {
		chomp($line);
		if ($line =~ /^\[0\]\s+INIT\s+\($$\)\s/i) {
			$switch++;
		} 
		if ($switch >= 1) {         # record from here to end
			$log .= "$line\n";
			$cnt++;
		}
	}
	$self->debug(2, "Retrieved $cnt lines from log") if $Perlbug::DEBUG;

	return $log;
}


=item doL

Returns the current (or given later) logfile.

	my $LOG = $o_do->doL($date);

=cut

sub doL {
	my $self = shift;
	my $date = shift;
	my $LOG  = '';

	$date = 'today' if $date == 1;
	my $fh = $self->fh('log'); # , db_log_\d{8}

	if (!(defined $fh)) {
        $self->error("Can't read LOG from undefined fh ($fh)");
	} else {
	    $fh->seek(0,0);
	    while (<$fh>) {
	        $LOG .= $_;
	    }
	    $fh->seek(0, 2);   
	    my $length = length($LOG);
	    $self->debug(2, "log ($fh) length ($length) read") if $Perlbug::DEBUG;
    } 

	return $LOG;
}


=item dom

Return the formatted message by id/s

    my @data = $o_do->dom(\@messageids);

=cut

sub dom {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	my $fmt   = $self->current('format');
	my $o_obj = $self->object('message');

	ID:
	foreach my $i (@ids) {
	    next ID unless $i =~ /^\d+$/o;
		my $str = $o_obj->read($i)->format($fmt);
		push(@res, $str);
	} 

	$self->debug(2, "message ids(@ids)") if $Perlbug::DEBUG;

	return @res;
}


=item doM

Create new message

    my $new_mid = $o_do->doM($h_args);

=cut

sub doM {
	my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $target = 'message';
	my $id     = '';

	if ($args{'body'} !~ /\w+/) {
		$self->error("requires a $target($args{'body'})!");
	} else {
		my $o_obj = $self->object($target);
		$o_obj->create({
			$target.'id'	=> $o_obj->new_id,
			'subject'		=> 'no-subject-given', 
			'sourceaddr'	=> 'no-sourceaddr-given', 
			'toaddr'		=> 'no-toaddr-given', 
			'header'		=> 'no-header-given', 
			'body'			=> 'no-body-given',
			'email_msgid'	=> 'no-msgid-given',
			%args,
		});	
		if (!($o_obj->CREATED)) {
			$self->error("Failed to create $target: ".Dumper($h_args));
		} else {
			$id = $o_obj->oid; 
			my %cmds = $self->parse_str($args{'opts'} || $args{'_opts'});
			my $i_rel = $o_obj->relate(\%cmds);
			my $i_don = $o_obj->appropriate(\%cmds);
			# $self->notify($target, $id); - track only
		}
	}

	return $id;
}


=item don

Return the formatted user by id/s

	my @res = $o_do->don(\@nids);

=cut

sub don {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	my $fmt   = $self->current('format');
	my $o_obj = $self->object('note');

	foreach my $i (@ids) {
	    next unless $i =~ /^\d+$/o;
		my $str = $o_obj->read($i)->format($fmt);
		push(@res, $str);
	} 

	$self->debug(2, "note ids(@ids)") if $Perlbug::DEBUG;

	return @res;
}


=item doN

Creates new note (assigns to given bugid).

	my $nid = $self->doN($h_args);

=cut

sub doN {
	my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $target = 'note';
	my $id     = '';

	if ($args{'body'} !~ /\w+/) {
		$self->error("requires a valid $target($args{'body'}) to insert");
	} else {
		my $o_obj = $self->object($target);
		$o_obj->create({
			$target.'id'	=> $o_obj->new_id,
			'subject'		=> 'no-subject-given', 
			'sourceaddr'	=> 'no-sourceaddr-given', 
			'toaddr'		=> 'no-toaddr-given', 
			'header'		=> 'no-header-given', 
			'body'			=> 'no-body-given',
			'email_msgid'	=> 'no-msgid-given',
			%args,
		});	
		if (!($o_obj->CREATED)) {
			$self->error("failed to create $target: ".Dumper($h_args));
		} else {
			$id = $o_obj->oid;
			my %cmds = $self->parse_str($args{'opts'} || $args{'_opts'});
			my $i_rel = $o_obj->relate(\%cmds);
			my $i_don = $o_obj->appropriate(\%cmds);
			# $self->notify($target, $id);
		}
	}

	return $id;
}


=item doo

Returns a summary overview of the bugs, bugs, messages etc. in the database.

	my @over = $o_do->doo();

=cut

sub doo {
    my $self = shift;	
	my $over = shift;
 	my $fmt  = $self->current('format');

    my $h_over = $self->stats();
	$self->debug(1, "overview stat'd, formatting...") if $Perlbug::DEBUG;

    my $res = $self->format_overview($h_over, $fmt);
	$self->debug(1, "overview formatted...") if $Perlbug::DEBUG;

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
		$self->debug(1, "Overview flag: '$flag'") if $Perlbug::DEBUG;
		my @types = @{$flags{$flag}};
		my $o_flag = $self->object($flag); # 
		TYPE:
		foreach my $type (@types) {  # inst core docs | open clos busy | etc:
			$self->debug(2, "Overview flag type: '$type'") if $Perlbug::DEBUG;
			my ($fid) = $o_flag->name2id([$type]);
			my $i_cnt = my @bids = $o_flag->read($fid)->rel_ids('bug');
			$over{$flag}{$type} = $i_cnt || ''; 			#	

			next TYPE if $flag eq 'status';

			my $bids = join("', '", @bids);
			my $ocnt = my @obids = $o_status->rel_ids('bug', "bugid IN ('$bids')");
			$over{$flag}{'Open'}{$type} = $ocnt || ''; 	# 

			if ($flag eq 'version' && $type =~ /^(\d)\.0*([1-9])([\d\.])+\s*$/o) {
				my $trim = "$1.$2.\%"; 
				$self->debug(3, "found version type($type) -> 1($1) 2($2) 3($3) assigning to trim($trim)") if $Perlbug::DEBUG;
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


=item dop

Return the formatted patch by id/s

    my @res = $o_do->dop(\@patchids);

=cut

sub dop {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	my $fmt   = $self->current('format');
	my $o_obj = $self->object('patch');

	foreach my $i (@ids) {
	    next unless $i =~ /^\d+$/o;
		my $str = $o_obj->read($i)->format($fmt);
		push(@res, $str);
	} 

	$self->debug(2, "patch ids(@ids)") if $Perlbug::DEBUG;

	return @res;
}


=item doP

Assign to given bugid, given patch, return new patch_id

	$pid = $o_obj->doP($h_args);

=cut

sub doP {
	my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $target = 'patch';
	my $id     = '';


	if ($args{'body'} !~ /\w+/) {
		$self->error("requires a valid $target($args{'body'}) to insert");
	} else {
		my $o_obj = $self->object($target);
		$o_obj->create({
			$target.'id'	=> $o_obj->new_id,
			'subject'		=> 'no-subject-given', 
			'sourceaddr'	=> 'no-sourceaddr-given', 
			'toaddr'		=> 'no-toaddr-given', 
			'header'		=> 'no-header-given', 
			'body'			=> 'no-body-given',
			'email_msgid'	=> 'no-msgid-given',
			%args,
		});	
		$self->debug(0, "patch created(".$o_obj->CREATED.")?");
		if ($o_obj->CREATED) {
			$id = $o_obj->oid;
			my %cmds = $self->parse_str($args{'opts'} || $args{'_opts'});
			my $i_rel = $o_obj->relate(\%cmds);
			my $i_don = $o_obj->appropriate(\%cmds);
			$self->notify($target, $id);
		}	
	}

	return $id;
}


=item doq

Gets the sql _q_ query statement given in the body of the message, executes it, and
returns the result in the result array.

	my @results = $o_do->doq($sql);

=cut

sub doq {
    my $self = shift;
	my $sql  = shift;
    my $errs = 0;
	my @res  = ();

    $sql =~ tr/\n\t\r/ /; 
    $sql =~ s/^(.+)?[\;\s]*$/$1/;

    if (($self->isadmin eq $self->system('bugmaster'))){# && ($sql !~ /delete|drop/i)){
        # let it through for testing purposes
    } else {
        # could be a little paranoid, but...
	 	if ($sql =~ /\b(alter|create|delete|drop|file|grant|insert|rename|shutdown|update)\b/sio) {
	 		$self->error("You may not execute this sql($1) from this interface!");
			$errs++;
		}
		if ($sql !~ /^\b(desc(ribe)*|select|show)\b/si)  { 
			$self->error("You may only execute DESC|SELECT|SHOW statements from this interface - invalid sql($sql)!");
			$errs++;
		}
    }
	
	if ($errs == 0) {   
		# my $sth = $self->db->query($sql);
		# if (defined($sth)) {
		my @data = $self->get_data($sql);
		if (!(@data >= 1)) {
			$self->debug(0, "No results from sql($sql)") if $Perlbug::DEBUG;
		} else {
			my $maxlen  = $self->database('maxlen') || 1500;
			my $lsep	= "\n";
			my $fsep	= ",\t";
			# push(@res, $sth->dump_results($maxlen, $lsep, $fsep, $x));
			# push(@res, map { $_."\n" } DBI::neat_list(\@data, $maxlen, $fsep));
			foreach my $d (@data) {
				my $data = '';
				foreach my $key (keys %{$d}) {
					my $val = $$d{$key};
					$data .= DBI::neat_list([($key, $val)], $maxlen, $fsep)."\n";
				}
				push(@res, $data);
			}
			# $res = $sth->as_string; # better? Mysql => Oracle?
			# $res = $sth->neat; # better? Mysql => Oracle?
		}
	}

	return @res;
}


=item doQ

Returns the database schema, for use with SQL statements.

	my @tables_data = $o_do->doQ;

=cut

sub doQ {
    my $self = shift;
	my $sql  = shift;
	my @res  = ();

	my @tables = $self->get_list("SHOW tables FROM ".$self->database('database'));
	foreach my $t (@tables) {
	    next unless $t =~ /^\w+/o;
	    my $sql = "DESCRIBE $t";
		my $res = join("\n", $self->get_list($sql));
    	push(@res, "$t: \n$res\n");
	}

	return @res;
}


=item dor

Retrieve data based on contents of the body of a bug 

    my @res = $o_do->dor('object initialisation problem');

=cut

sub dor {
	my $self = shift;
	my $srch = shift;
	my @res  = ();

	my $o_bug = $self->object('bug');
	my @bids  = $o_bug->ids("body LIKE '%$srch%'");

	if (scalar(@bids) >= 1) {
		push(@res, $self->dob(\@bids));
	}

	return @res;
}


=item doR

Wrapper for L<dor()>, in large format

    my @res = $o_do->doR('object initialisation problem');

=cut

sub doR {
	my $self = shift;
	my $srch = shift;

	my $orig = $self->current('format');
	$self->current('format', uc($orig));

	my @res  = $self->dor($srch);

	$self->current('format', $orig);

	return @res;
}


=item dos

Retrieve bugs based on the subject line of a bug

    my @res = $o_do->dos('build failure');

=cut

sub dos {
	my $self = shift;
	my $subj = shift;
	my @res  = ();

	my @bids = $self->object('bug')->ids("subject LIKE '%$subj%'");

	@res = $self->dob(\@bids);

	return @res;
}


=item doS

Wrapper for L<dos()> in 'large format'

	my @RES = $o_do->doS('some subject');	

=cut

sub doS {
	my $self = shift;
	my $subj = shift;

	my $orig = $self->current('format');
	$self->current('format', uc($orig));

	my @res = $self->dos($subj);

	$self->current('format', $orig);

=rjsf

	and R

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

=cut

	return @res;
}


=item dot

Return the formatted test by id/s

    my @res = $o_do->dot(\@testids);

=cut

sub dot {
	my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	my $fmt   = $self->current('format');
	my $o_obj = $self->object('test');
	my $o_tmp = $self->object('template');

	# push(@res, $o_tmp->start('test', $fmt);
	foreach my $i (@ids) {
	    next unless $i =~ /^\d+$/o;
		my $str = $o_obj->read($i)->format($fmt);
		push(@res, $str);
	} 
	# push(@res, $o_tmp->finish('test', $fmt);

	$self->debug(2, "test ids(@ids)") if $Perlbug::DEBUG;

	return @res;
}


=item doT

Assign to given bugid, given test, return i_ok

	$new_tid = $o_obj->doT($h_args);

=cut

sub doT {
	my $self  = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $target = 'test';
	my $id     = '';

	if ($args{'body'} !~ /\w+/) {
		$self->error("requires a valid $target($args{'body'}) to insert");
	} else {
		my $o_obj = $self->object($target);
		$o_obj->create({
			$target.'id'	=> $o_obj->new_id,
			'subject'		=> 'no-subject-given', 
			'sourceaddr'	=> 'no-sourceaddr-given', 
			'toaddr'		=> 'no-toaddr-given', 
			'header'		=> 'no-header-given', 
			'body'			=> 'no-body-given',
			'email_msgid'	=> 'no-msgid-given',
			%args,
		});	
		if ($o_obj->CREATED) {
			$id = $o_obj->oid;
			my %cmds = $self->parse_str($args{'opts'} || $args{'_opts'});
			my $i_rel = $o_obj->relate(\%cmds);
			my $i_don = $o_obj->appropriate(\%cmds);
			$self->notify($target, $id);
		}
	}

	return $id;
}


=item dou

Return the formatted user by id/s

    my @res = $o_do->dou(\@userids);

=cut

sub dou {
    my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	my $fmt   = $self->current('format');
	my $o_obj = $self->object('user');

	foreach my $i (@ids) {
	    next unless $i =~ /^\w+$/o;
		my $str = $o_obj->read($i)->format($fmt);
		push(@res, $str);
	} 

	$self->debug(2, "user ids(@ids)") if $Perlbug::DEBUG;

    return @res;
}


=item doU

Create new user entry

	my $uid = $self->doU($h_args);

Initiate new admin entry, including htpasswd entry, (currently rf only)

	userid		= test_user:
	password	= p*ss33*t:
	address		= perlbugtest@rfi.net:
	match_address =.*\@rfi\.net:
	name		= Richard Foley:

=cut

sub doU { # rjsf
    my $self   = shift;
	my $h_args = shift;
	my $uid    = '';

	my $o_usr = $self->object('user');
	# $o_usr->create($h_args); # careful - rjsf <- !!!
	# return $o_usr->oid if $o_usr->CREATED;

    if (ref($h_args) ne 'HASH') {
		$self->error("No userid offered!");
	} else { 
		$self->debug(2, 'given: '.Dumper($h_args)) if $Perlbug::DEBUG;
		my %user = %{$h_args};
		my $orig_password = $user{'password'};
		$user{'password'} = crypt($user{'password'}, 'pb'); # encrypted
		my @exists = $o_usr->ids("UPPER(userid) LIKE UPPER('$user{'userid'}')");
		push(@exists, $o_usr->ids("UPPER(name) LIKE UPPER('$user{'name'}')"));
        if (scalar(@exists) >= 1) {
            $self->error("User already defined in db(@exists)");
		} else {
            $self->debug(0, "User not defined in db(@exists)");
			$o_usr->create(\%user);
			if (!($o_usr->CREATED)) {
				$self->error("Admin db insertion failure");
			} else {
				$uid = $o_usr->oid;
				$self->debug(1, "Admin($user{'name'}) inserted($uid) into db.") if $Perlbug::DEBUG;
				$DB::single=2;
				# my $i_ok = $self->htpasswd($user{'userid'}, $user{'password'});
				my $i_ok = 1;
				if ($i_ok == 1) {
					my $title = $self->system('title');
					my $url   = 'http://'.$self->web('domain');
					my $new_admin = qq|
Welcome $user{'name'} as a new $title administrator:

	Address: "$user{'name'}" <$user{'address'}>

    userid=$user{'userid'}
    passwd=$orig_password  
	
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
					# use Perlbug::Interface::Email; # yek
					my $o_email = Perlbug::Interface::Email->new;
					my $o_notify = $o_email->get_header;
					$o_notify->add('To', $user{'address'});
					$o_notify->add('Bcc', $self->system('maintainer'));
					$o_notify->add('From', $self->email('bugdb'));
					$o_notify->add('Subject', "$title administrator");
					$i_ok = $o_email->send_mail($o_notify, $new_admin);
				}
			}
		}
    }
	$self->debug(1, "user creation($uid)");

    return $uid;
}  


=item dov

Volunteer proposed bug modifications where msg is something like: 'propose_close_<bugid>@bugs.perl.org'

	my $i_ok = $o_obj->dov($h_args);

=cut

sub dov { # rjsf
	my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $res    = '';

	my %cmds   = $self->parse_str($args{'opts'} || $args{'_opts'});

	my $i_ok = 0;
	if (1 != 1) {
		$self->error("forwarding requires something ...!");
	} else {
		my $body    = $args{'body'} || '';
		my $from    = $args{'from'} || '';
		my $replyto = $args{'replyto'} || '';
		my $subject = $args{'subject'} || '';
		my $admin   = $self->system('maintainer');
		my @admins  = $self->object('user')->col('address', "active = '1'");
		my $o_prop  = $self->get_header(); # $o_hdr);
		$o_prop->replace('To', $admin);
		# $o_prop->replace('Cc', join(', ', @admins));
		$o_prop->replace('From', $self->from($replyto, $from));
		$o_prop->replace('Subject', $self->system('title')." forward - $subject");
		$i_ok = $self->send_mail($o_prop, $body);
	}

	$res = "Proposal request forwarded($i_ok)";

	return $res;
}


=item doV

Volunteer a new administrator

	my $feedback = $o_do->doV($h_args);

=cut

sub doV { # rjsf
	my $self = shift;
	my $h_args = shift;

	my $args = shift;
	my $o_int = shift;

	my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	my $request = "New admin request -i[nitiate] (\n@args\n)\n";
	my $i_ok = 0;
	if (!ref($o_int)) {
		$self->error("admin volunteer requires a mail object($o_int)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_int);
		my $o_prop = $self->get_header($o_hdr);
		my $subject = $o_hdr->get('Subject');
		chomp($subject);
		my $admin = $self->system('maintainer');
		$o_prop->replace('To', $admin);
		$o_prop->delete('Cc');
		$o_prop->replace('Subject', $self->system('title')." admin volunteer");
		$o_prop->replace('Reply-To', $admin);
		$i_ok = $self->send_mail($o_prop, $request);
	}
	my $res = "Admin volunteer request($i_ok)";

	return $res;
}


=item dox

Delete bug from db_bug table.

Use C<doX> for messages associated with bugs.

	my @feedback = $o_do->dox(\@bids);

=cut

sub dox {
    my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	if (!(scalar(@ids) >= 1)) {
		$self->error("requires bugids(@ids)");
	} else {
		my $user = $self->isadmin;
		if (!($user)) {
			$self->error("user($user) not an admin!");
		} else {
			my $o_bug = $self->object('bug');
			$o_bug->delete(\@ids);
			push(@res, $o_bug->DELETED." bugs deleted!");
		}
	}

	return @res;
}


=item doX

Delete given bugs along with messages from db_message.

Also does parent/child, bug_user, etc. tables, also calls L<dox()>

	my @feedback = $o_do->doX(\@bids);

=cut

sub doX {
    my $self  = shift;
	my $a_ids = shift;
	my @ids   = @{$a_ids};
	my @res   = ();

	if (!(scalar(@ids) >= 1)) {
		$self->error("requires bugids(@ids)");
	} else {
		if (!($self->isadmin)) {
			$self->error("not admin: ".$self->isadmin);
		} else {
			my $o_bug = $self->object('bug');
			my @rels  = $o_bug->relations;
			BUG:
			foreach my $id (@ids) {
				next BUG unless $o_bug->ok_ids([$id]);
				REL:
				foreach my $rel (@rels) {
					next REL unless $rel;
					my $o_rel = $o_bug->relation($rel)->set_source($o_bug);
					$o_rel->delete([$o_bug->rel_ids($rel)]);
				}
				push(@res, $self->dox($id)." bug($id) rellies deleted!\n");
			}
		}
	}
    return @res;
}



=item doy

Password renewal

    my $i_ok = $o_do->doy("$user $pass");

=cut

sub doy {
    my $self = shift;
	my $uspa = shift;

	my ($user, $pass) = split(/\s+/, $uspa);

	$pass = 'default_password' unless $pass =~ /\w+/o;
    my $i_ok = 1;
	my $o_usr = $self->object('user');
    
	if (!($user =~ /\w+/o && $pass =~ /\w+/o)) {
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
			$self->debug(2, "htp: user($user) inserted new password($pass)") if $Perlbug::DEBUG;
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
			$self->debug(2, "db: user($user) set new password($pass)") if $Perlbug::DEBUG; 
		} else {
			$i_ok = 0;
			$self->error("db: user($user) failed to set new password($pass)"); 
		}
	}
	
	return $i_ok;
}


=item doz

Retrieve configuration data

    $data = $o_obj->doz([qw(current email target)]);

=cut

sub doz {
    my $self = shift;
	my $conf = shift;

	my @res  = $self->get_config($conf);
    
	return @res;
}


=item doZ

Attempt to set B<current> configuration data, for this session only

    my $debuglevel = $o_obj->doZ('debug', 2);

    my $switches   = $o_obj->doZ('switches', 'abcdef');

=cut

sub doZ {
    my $self = shift;
	my $cmds = shift;
	my ($key, $val) = split(/\s+/, $cmds);
	my @res  = ();

	my $user = $self->isadmin;
	if ($user eq $self->system('bugmaster')) {
		$self->error("User($user) can't set current key($key) val($val)!");
	} else {
		@res  = $self->current({$key, $val});
		# print "$self->current({$key, $val}) => res(@res)\n";
	}
    
	return @res;
}



# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------


=item overview

Formatting for overview.

	my $overview = $o_do->overview($h_overview, [$fmt]);

=cut

sub overview {
    my $self = shift; # expected to be Base/Cmd/Email/Web object!
    my $ref  = shift;
    my $fmt  = shift || $self->current('format') || 'a';

	my $url = $self->current('url');
	my $cgi = $self->cgi();
    my $res = '';

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
					$type = "$1.$2.%" if $type =~ /^(\d)\.0*([1-9])([\d\.\%]).*$/o; # Do::stats 
					my $v = $fmt{'version'}{$type};
					next TYPE unless $v =~ /\%/o;
					my $o = $fmt{'version'}{'Open'}{$type};
				}
	            $self->debug(3, "Overview format($fmt) flag($flag), type($type)") if $Perlbug::DEBUG;
                if ($fmt =~ /^[IhHL]$/o) { # HTML
					$fmt{$type} = $self->href("query&$flag=$type", [], "$fmt{$flag}{$type}", '');
	                if (($fmt{$flag}{'Open'}{$type} =~ /^(\d+)$/o) && ($flag ne 'status')) {
						($fmt{$type}) .= '&nbsp;('.$self->href("query&$flag=$type&status=open", [], "$fmt{$flag}{'Open'}{$type}", '').')';
	                }
	            } else {                	 # ASCII
	                $fmt{$type} = "$fmt{$flag}{$type}";
	                if (($flag ne 'status') && defined($fmt{$flag}{'Open'}{$type}) && ($fmt{$flag}{'Open'}{$type} =~ /^(\d+)$/o)) {
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
		if ($fmt =~ /[aAl]/o) {
			formline($_format, @args);			# 1
		} else {
			$^A = $_format;
		}
		$res = $self->mypre($fmt).
				$top.$^A .
			    $self->mypost($fmt);	
		$^A = ""; 								# reset
	}

    return $res;    
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
		$fmt{'bug'}, $fmt{'message'}, $fmt{'patch'}, $fmt{'test'}, $fmt{'note'}, $fmt{'administrators'}, $fmt{'days1'}, $fmt{'days7'}, $fmt{'days30'}, $fmt{'days90'},
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
	my @keys = ($self->objects('mail'), $self->objects('item'), $self->objects('flag'));
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
	my $url = $self->myurl;
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
	$fmt{'aix'}
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
	my @keys = ($self->objects('mail'), $self->objects('item'), $self->objects('flag'));
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
	$format =~ s/\s+/ /o;


	return ($top, $format, @args);
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net Oct 1999 2000 2001

=cut

1;
