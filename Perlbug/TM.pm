# Perlbug Ticket support functions
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: TM.pm,v 1.10 2000/08/10 10:49:10 perlbug Exp perlbug $
#
# Was TicketMonger.pm: Copyright 1997 Christopher Masto, NetMonger Communications
# Perlbug integration: RFI
#
# TODO add modified date to tm_tickets
#

=head1 NAME

Perlbug::TM - Bug support functions for Perlbug

=cut

package Perlbug::TM;
use IO::File;
use Mysql;
use Carp;
# use Perlbug::Log;
# @ISA = qw(Perlbug::Log); 
use strict;
use vars qw($VERSION);
$VERSION = 1.20; 
my ($dbh, $lasterror) = (undef, '');
my $CNT = 0;

=head1 DESCRIPTION

Access to the database, bug get, set, id methods for Perlbug.

=head1 SYNOPSIS

	my $o_tm = Perlbug::TM->new;
	
	my $id = $o_tm->get_id('some long string with a tid [20010732.003] in it somewhere');
	
	print "ID: $id\n"; # 20010732.003


=head1 METHODS

=over 4

=item new

Create new Perlbug::TM object:

	my $do = Perlbug::TM->new();

=cut

sub new { 
    my $proto = shift;
   	my $class = ref($proto) || $proto; 
   	bless({}, $class);
}

sub qm { 
	# return $dbh->quote($_[0]);
	#
	# *** 
	# not entirely satisfactory
	# ***
	#
	return Mysql->quote($_[0]); 
	# return "'$_[0]'"; # unless 'stuff'
}

###
# DBConnect() checks to see if there is an open connection to the
# Savant database, opens one if there is not, and returns a global
# database handle.  This eliminates opening and closing database
# handles during a session.  undef is returned 
sub DBConnect {
    my $self = shift;
    unless (defined $dbh) {
        # Connection data
        my $sqlusername =$self->database('user');        # Name to log into MySQL server as
        my $sqldatabase =$self->database('database');    # Database name
        my $sqlhost     =$self->database('sqlhost');     # Name of machine
        my $sqlpassword =$self->database('password');    # Password  
        my $secretspath =$self->directory('config').'/.mysql'; # Path to passwd 
        unless (defined $sqlpassword) {  # Get password if not assigned above
            my $sqlpasswordfh=new IO::File("<$secretspath");
            unless (defined $sqlpasswordfh) {
                $self->fatal($lasterror="Can't open secrets file: '$secretspath'");
                return undef;
            }
            chomp($sqlpassword=$sqlpasswordfh->getline);
            $sqlpasswordfh->close;
        }
        # A bit Mysql|Oracle specific just here ($o_conf->database('connect'))
        $self->debug(3, "Connect($sqlhost, $sqldatabase, $sqlusername, sqlpassword)");
        $dbh=Mysql->Connect($sqlhost, $sqldatabase, $sqlusername, $sqlpassword);
        if (defined $dbh) {
			# $dbh->selectdb($sqldatabase);
            my @tables = $dbh->list_tables;
            $self->debug(1, "Connected to $sqldatabase: ".@tables." tables");
			$self->debug(1, "Tables: @tables");
        } else {
            my $msg = "Can't connect to db: '$Mysql::db_errstr'";
            carp($msg);
            $self->fatal($msg);
        }
    }
    return $dbh;
}

###
# DBClose() closes the current database handle if one is open
sub DBClose {
  my $self = shift;
  undef $dbh;
}

sub query {
    my $self = shift;
	$self->debug('IN', @_);
    my $sql = shift; 
    $CNT++;    
    # carp("TM::query [$CNT] -> ($sql)");
    $self->debug(3, "SQL query: '$sql'");
    my $sth = undef;
    my $dbh=DBConnect($self); # or return undef;
    if (defined($dbh)) {
        # *** better place to do this?
	# $sth=$dbh->Query(qm($sql));
        $sth=$dbh->Query($sql);
        if (defined $sth) {
			my $rows = 0;
			$rows = $sth->rows if $sth->can('rows');
            my ($selected, $affected) = ($sth->num_rows, $sth->affected_rows);
            $self->debug(3, "Rows($rows): selected($selected), affected($affected)");
        } else {
            if ($Mysql::db_errstr eq "mysql server has gone away") {
                DBClose;
            }
            $lasterror="Query ($sql) failed: '$Mysql::db_errstr'";
            $self->debug(0, $lasterror);
            $self->result($lasterror);
        }
    } else {
        $self->debug(0, "Undefined dbh($dbh)");
    }
    $self->debug('OUT', $sth);
    return $sth;
}

sub ch {
    my $self = shift;
    my $ch = shift;
    chomp($ch);
    return $ch;
}


=item new_id

Generate new_id for perlbug - YUK

=cut

sub new_id { # rf -> xxxx0827.007 ->19990827.007
    my $self = shift;
    my ($id, $ok) = ('', 1);
    my ($today) = $self->get_date();
    $self->debug(2, "new_id requested on '$today'");
    my $sth = $self->query("SELECT max(ticketid) FROM tm_id");
    my $found = '';
    if (defined $sth) {
        ($found) = $sth->fetchcol(0);
        $self->debug(3, "Found bugid: '$found'.");
    } else {
        $self->debug(0, "Couldn't get max(bugid) FROM tm_id: $Mysql::db_errstr");
    }
    my ($date, $num) = ("", "");
    if ($found  =~ /^(\d{6,8})\.(\d{3})$/) { #dot or not
        ($date, $num) = ($1, $2);
        if (length($num) == 1) { $num = '00'.$num; }
        if (length($num) == 2) { $num = '0'.$num; } 
    } else {
        $ok = 0;
        $self->debug(0, "Can't find the latest ($found) id!");
        #or start a new one.
        $date = $today;
        $num = '001';
    }
    if (($date == $today) && ($ok == 1)) {
        if ($num >= 999) { # > just in case.
            $self->debug(0, "Ran out of bug ids today ($today) at: '$found'");
            $ok = 0;
        } else {
            $num++;
            #$num = sprintf("%03d", $num);
            if (length($num) == 1) { $num = '00'.$num; }
            if (length($num) == 2) { $num = '0'.$num; } 
        }
    } else {
        $num = '001';
    }
    if ($ok == 1) {
	    my $newid   = $today.'.'.$num;
	    my $update = "UPDATE tm_id set ticketid = '$newid' WHERE ticketid = '$found'";
	    my $sth = $self->query($update);
	    if (defined($sth)) {
	        my $res = $sth->affected_rows;
	        if ($res) {
	            $id = $newid;
	            $self->debug(2, "New ID ($newid) generated.");
	        } else {
	            $self->debug(0, "Don't know what happened at tm_id update ($res).");
	        }
	    } else {
	        $self->debug(0, "Can't generate new ID ($newid), sth($sth), update($update): $Mysql::db_errstr");
	    }
	} else {
	    my $newid   = $today.'.'.$num;
	    my $insert = "INSERT INTO tm_id values ('$newid')";
	    my $sth = $self->query($insert);	
	    if (defined($sth)) {
	        my $res = $sth->affected_rows;
	        if ($res) {
	            $id = $newid;
	            $self->debug(2, "New ID ($newid) generated.");
	        } else {
	            $self->debug(0, "Don't know what happened at tm_id insert($res).");
	        }
	    } else {
	        $self->debug(0, "Can't insert new ID ($newid), sth($sth), insert($insert): $Mysql::db_errstr");
	    }
	}	
	$self->debug(2, "Returning new_id($id)");
    return $id;
}


=item get_id

Determine if the string contains a valid bug ID.

    my ($ok, $tid) = $obj->get_id($str);

=cut

sub get_id {
    my $self = shift;
    my $str = shift;
    my ($ok, $id) = (0, '');
    # /^\[[ID]*\s*(\d{8}\.\d{3})\s*\]$/ -> brackets ...?
    if ($str =~ /(\d{8}\.\d{3})/) { # no \b while _ is a letter?
        $id = $1;
        $ok = 1;
    }
    $self->debug(3, "TM::get_id($str) -> $ok ($id)");
    return ($ok, $id);
}

sub gen_insert {
  my $self = shift;
  my ($table, $quote, $literal) = @_;
  my @litkeys = keys %$literal;
  my @qkeys   = keys %$quote;
  my @values  = map { $literal->{$_} }   @litkeys;
  push @values, map { qm($quote->{$_})} @qkeys;
  my @keys = (@litkeys, @qkeys);
  my $query = "INSERT INTO $table (" . join(", ", @keys) . ") VALUES (" . join(", ", @values) . ")";
  $self->debug(4, "TM::gen_insert($query)");
  return $query;
}

sub gen_update {
  my $self = shift;
  my ($table, $quote, $literal) = @_;
  my @litkeys = keys %$literal;
  my @qkeys   = keys %$quote;
  my $query = "UPDATE $table SET "
    . join(", ", (map { "$_ = $$literal{$_}" } @litkeys),
          (map { "$_ = " . qm($$quote{$_}) } @qkeys));
  $self->debug(3, "TM::gen_update($query)");
  return $query;
}

sub cc_get {
  my $self = shift;
  my $tid = shift;
  my $sth = $self->query("SELECT address FROM tm_cc WHERE ticketid = " . qm($tid))
    or $self->debug(0, "Couldn't get Ccs for [$tid]: $Mysql::db_errstr");
  return $sth->fetchcol(0);
}

sub claimants_get {
  my $self = shift;
  my $tid = shift;
  my $sth = $self->query("SELECT userid FROM tm_claimants WHERE ticketid = " . qm($tid))
    or $self->debug(0, "Couldn't get claimants for [$tid]: $Mysql::db_errstr");
  return $sth->fetchcol(0);
}

sub user_get {
  my $self = shift;
  my $userid = shift;
  my $sth = $self->query("SELECT * FROM tm_users WHERE userid = " . qm($userid))
    or $self->debug(0, "Couldn't get user information for ]: $Mysql::db_errstr");
  return { $sth->fetchhash };
}

## Functions for working with bugs
sub bug_new {
  my $self = shift;
  my $data = shift;
  $self->debug(2, "New bug data($data)");
  my @keys = keys %$data;
  my @values = map { qm($_) } @$data{@keys};
  my ($ok, $sth, $tries) = (1, undef, 0);
  my $id = $self->new_id;
  my $query = $self->gen_insert("tm_tickets", $data, { ticketid => qm($id), created  => "now()" });
  $self->debug(3, "New Tkt query($query)");
  foreach my $tries (1..3) { # 3 is probably enough
    $sth = $self->query($query);
    if (defined $sth) {
        last;
    }
  }
  if (defined($sth)) {
    $self->debug(2, "Insertion succesful $sth");
  } else {
    $ok = 0;
    my $err = "Couldn't generate insert the bug after 3 tries: $Mysql::db_errstr";
    $self->debug(0, $err);
    print STDERR $err;
  }
  return ($ok, $id);
}

# If a ticket's status is closed, set it to reopen
sub bug_reopen {
  my $self = shift;
  my $tid = shift;
  my $query = "UPDATE tm_tickets SET status = 'reopen' WHERE ticketid = "
    . qm($tid) . " AND status = 'closed'";
  my $sth = $self->query($query) or $self->debug(0, "Couldn't UPDATE: $Mysql::db_errstr");
  return $sth->affected_rows;
}

sub bug_set {
  my $self = shift;
  my ($tid, $h_data) = @_;
  my $query = $self->gen_update("tm_tickets", $h_data);
  $query .= " WHERE ticketid = " . qm($tid);
  my $sth = $self->query($query) or $self->debug(0, "Couldn't UPDATE: $Mysql::db_errstr");
  if ($sth->affected_rows >= 1) {
  	$self->track('t', $tid, join(':', values %{$h_data}));
  }
  return $sth->affected_rows;
}

sub bug_get {
  my $self = shift;
  my ($tid, @fields) = @_;
  my $query = "SELECT " . join(", ", @fields) . " FROM tm_tickets WHERE ticketid = " . qm($tid);
  my $sth = $self->query($query) or $self->debug(0, "Couldn't SELECT: $Mysql::db_errstr");
  return $sth->fetchhash;
}

sub bug_check {  
  my $self = shift; 
  my $tid = shift;  
  my $sth = $self->query("SELECT ticketid FROM tm_tickets WHERE "
    . "ticketid = " . qm($tid)) or $self->debug(0, "Couldn't SELECT: $Mysql::db_errstr");
  my $ok = ($sth->numrows >= 1) ? 1 : 0;
  return $ok;
}

sub bug_claim {
  my $self = shift;
  my ($tid, $name) = @_;
  my $query = $self->gen_insert("tm_claimants", { ticketid => $tid, userid => $name });
  my $sth = $self->query($query) or $self->debug(0, "Couldn't insert claimant: $Mysql::db_errstr");
  return defined($sth) ? 1 : 0;
}

sub bug_unclaim {
  my $self = shift;
  my ($tid, $name) = @_;
  my $query = "DELETE FROM tm_claimants WHERE ticketid = " . qm($tid) .
              "AND userid = " . qm($name);
  $self->query($query) or $self->debug(0, "Couldn't delete claimant: $Mysql::db_errstr");
  return 1;
}

## Functions for working with messages

sub message_add {
  my $self = shift;
  my ($tid, $data) = @_;
  my $ok = 1;
  my $insert = $self->gen_insert("tm_messages", $data, { ticketid => qm($tid), created => "now()"});
  my $sth = $self->query($insert);
  if (defined($sth)) {
    #sth->num_rows;
    $self->debug(1, "Message added ($tid)");
  } else {
    $ok = 0;
    $self->debug(0, "Message not added ($tid, $data) $Mysql::db_errstr");
  }
  return ($ok, $sth." ".$insert); # ->insert_id;
}

=back

=head1 AUTHOR

Chris Masto chrism@netmonger.net and Richard Foley perlbug@rfi.net Oct 1999

=cut

1;
