# Perlbug Bug support functions
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: TM.pm,v 1.24 2001/03/16 15:22:37 perlbug Exp $
#
# Was TicketMonger.pm: Copyright 1997 Christopher Masto, NetMonger Communications
# Perlbug integration: RFI 1998 -> 2001
#

=head1 NAME

Perlbug::TM - Bug support functions for Perlbug

=cut

package Perlbug::TM;
use strict;
use vars qw($VERSION $SQL);
$VERSION = do { my @r = (q$Revision: 1.24 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 

use Data::Dumper;
use IO::File;
use Mysql;
use Carp;
my ($dbh, $lasterror) = (undef, '');
$SQL = 0;

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
	return $dbh->quote($_[0]);
	return Mysql->quote($_[0]); 
}


=item dbh

Returns database handle for queries

=cut

sub dbh {
	my $self = shift;	
	return ref($dbh) ? $dbh : $self->DBConnect;
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
        my $sqlusername =$self->database('user') || 'perlbug';        # Name to log into MySQL server as
        my $sqldatabase =$self->database('database');    # Database name
        my $sqlhost     =$self->database('sqlhost');     # Name of machine
        my $sqlpassword =$self->database('password');    # Password  
        my $secretspath =$self->directory('config').'/.mysql'; # Path to passwd 
        unless (defined $sqlpassword) {  # Get password if not assigned above
            my $sqlpasswordfh=new IO::File("<$secretspath");
            unless (defined $sqlpasswordfh) {
                $self->error($lasterror="Can't open secrets file: '$secretspath'");
                return undef;
            }
            chomp($sqlpassword=$sqlpasswordfh->getline);
            $sqlpasswordfh->close;
        }
        # A bit Mysql|Oracle specific just here ($o_conf->database('connect'))
        $self->debug(0, "Connect host($sqlhost), db($sqldatabase), user($sqlusername), pass(sqlpassword)");
        $dbh=Mysql->Connect($sqlhost, $sqldatabase, $sqlusername, $sqlpassword);
		# use CGI; print CGI->new->header, '<pre>'.Dumper($self).'</pre>';
        if (defined $dbh) {
			# $dbh->selectdb($sqldatabase);
            my @tables = $dbh->list_tables;
            $self->debug(1, "Connected to $sqldatabase: ".@tables." tables");
			$self->debug(3, "Tables: @tables");
        } else {
            my $msg = "Can't connect to db: '$Mysql::db_errstr'";
            $self->error($msg);
        }
    }
    return $dbh;
}


sub query {
    my $self = shift;
    # my ($sql) = $self->quote(shift); 
	# $sql =~ s/^\s*\'\s*(.+)\s*\'\s*$/$1/; 
	my $sql = shift;
    $SQL++;    
    # carp("TM::query [$SQL] -> ($sql)");
    $self->debug('s', "<$SQL> ".$sql);
    my $sth = undef;
    my $dbh=$self->DBConnect; # or return undef;
    if (defined($dbh)) {
        $sth=$dbh->Query($sql);
        if (defined $sth) {
			my $rows = 0;
			$rows = $sth->rows if $sth->can('rows');
            my ($selected, $affected) = ($sth->num_rows, $sth->affected_rows);
            $self->debug(3, "Rows($rows): selected($selected), affected($affected)");
        } else {
            if ($Mysql::db_errstr eq "mysql server has gone away") {
                undef $dbh;
            }
            $lasterror="Query <$SQL> ($sql) failed: '$Mysql::db_errstr'";
            $self->debug(0, $lasterror);
			print $lasterror;
			# carp($lasterror);
        }
    } else {
        $self->debug(0, "Undefined dbh($dbh)");
    }

    return $sth;
}


=item new_id

Generate new_id for perlbug - YUK

=cut

sub new_id { # rf -> xxxx0827.007 ->19990827.007
    my $self = shift;
    my ($id, $ok) = ('', 1);
    my ($today) = $self->get_date();
    $self->debug(2, "new_id requested on '$today'");
    my $sth = $self->query("SELECT max(bugid) FROM pb_bugid");
    my $found = '';
    if (defined $sth) {
        ($found) = $sth->fetchcol(0);
        $self->debug(3, "Found bugid: '$found'.");
    } else {
        $self->debug(0, "Couldn't get max(bugid) FROM pb_bugid: $Mysql::db_errstr");
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
	    my $update = "UPDATE pb_bugid SET bugid = '$newid' WHERE bugid = '$found'";
	    my $sth = $self->query($update);
	    if (defined($sth)) {
	        my $res = $sth->affected_rows;
	        if ($res) {
	            $id = $newid;
	            $self->debug(2, "New ID ($newid) generated.");
	        } else {
	            $self->debug(0, "Don't know what happened at pb_bugid update ($res).");
	        }
	    } else {
	        $self->debug(0, "Can't generate new ID ($newid), sth($sth), update($update): $Mysql::db_errstr");
	    }
	} else {
	    my $newid   = $today.'.'.$num;
	    my $insert = "INSERT INTO pb_bugid SET bugid = '$newid'";
	    my $sth = $self->query($insert);	
	    if (defined($sth)) {
	        my $res = $sth->affected_rows;
	        if ($res) {
	            $id = $newid;
	            $self->debug(2, "New ID ($newid) generated.");
	        } else {
	            $self->debug(0, "Don't know what happened at pb_bugid insert($res).");
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


=back

=head1 AUTHOR

Chris Masto chrism@netmonger.net and Richard Foley perlbug@rfi.net Oct 1999 2000 2001 

=cut

1;
