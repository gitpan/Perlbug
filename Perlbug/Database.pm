# Perlbug Bug support functions
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Database.pm,v 1.12 2001/04/21 20:48:48 perlbug Exp $
#
# Based on TicketMonger.pm: Copyright 1997 Christopher Masto, NetMonger Communications
# Perlbug(::Database) integration: RFI 1998 -> 2001
#

=head1 NAME

Perlbug::Database - Bug support functions for Perlbug

=cut

package Perlbug::Database;
use strict;
use vars qw($VERSION);
$VERSION = do { my @r = (q$Revision: 1.12 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 

use Data::Dumper;
use IO::File;
use Mysql;
use Carp;
my ($o_DBH, $lasterror) = (undef, '');
my $i_SQL = 0;
my $DEBUG = $ENV{'Perlbug_Database_DEBUG'} || $Perlbug::Database::DEBUG || '';
my %DB    = ();


=head1 DESCRIPTION

Access to the database for Perlbug

=head1 SYNOPSIS

	my $o_db = Perlbug::Database->new;
	
	my @tables = $o_db->query('show tables');
	
	print "tables: @tables\n";


=head1 METHODS

=over 4

=item new

=cut

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	%DB = @_;
	# undef $o_DBH;

	my $self = bless({}, $class);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	return $self;
}

sub DESTROY { 
	undef $o_DBH if defined($o_DBH); 
}

sub quote { 
	my $self = shift;
	return $self->dbh->quote(@_);
}


=item dbh

Returns database handle for queries

=cut

my $i_CNT = 0;

sub dbh {
	my $self = shift;	

	$i_CNT++;
	$o_DBH = ref($o_DBH) ? $o_DBH : $self->DBConnect;
	# carp("[$i_CNT] dbh ...($o_DBH)\n"); #.Dumper($o_DBH) unless $o_DBH;

	return $o_DBH;
}


###
# DBConnect() checks to see if there is an open connection to the
# Savant database, opens one if there is not, and returns a global
# database handle.  This eliminates opening and closing database
# handles during a session.  undef is returned 
sub DBConnect {
    my $self = shift;
    unless (defined $o_DBH) {
        my ($secretspath) =''; # $DB{'config'}.'/.mysql'; # Path to passwd 
=pod
        unless (defined $sqlpassword) {  # Get password if not assigned above
            my $sqlpasswordfh=new IO::File("<$secretspath");
            unless (defined $sqlpasswordfh) {
                croak($lasterror="Can't open secrets file: '$secretspath'");
                return undef;
            }
            chomp($sqlpassword=$sqlpasswordfh->getline);
            $sqlpasswordfh->close;
        }
=cut
        # A bit Mysql|Oracle specific just here ($o_conf->database('connect'))
        $o_DBH=Mysql->Connect($DB{'sqlhost'}, $DB{'database'}, $DB{'user'}, $DB{'password'});
		# use CGI; print CGI->new->header, '<pre>'.Dumper($self).'</pre>';
        if (!(defined($o_DBH))) {
            croak("Can't connect to db($o_DBH): '$Mysql::db_errstr'".Dumper(\%DB));
        }
    }
    return $o_DBH;
}


sub query {
    my $self = shift;
    # my ($sql) = $self->quote(shift); 
	# $sql =~ s/^\s*\'\s*(.+)\s*\'\s*$/$1/; 
	my $sql = shift;
    $i_SQL++;    
    my $sth = undef;
    $o_DBH=$self->dbh; # or return undef;
    if (!(defined($o_DBH))) {
        croak("Undefined dbh($o_DBH)");
    } else {
        $sth=$o_DBH->Query($sql);
        if (defined $sth) {
			my $rows = 0;
			$rows = $sth->rows if $sth->can('rows');
            my ($selected, $affected) = ($sth->num_rows, $sth->affected_rows);
        } else {
            $lasterror="Query <$i_SQL> ($sql) failed: '$Mysql::db_errstr'";
            croak($lasterror);
        }
    }

    return $sth;
}


=back

=head1 AUTHOR

Chris Masto chrism@netmonger.net and Richard Foley perlbug@rfi.net Oct 1999 2000 2001 

=cut

1;
