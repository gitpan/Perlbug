#!/pro/bin/perl -w

package Perlbug::Tk;

use strict;
use vars qw($VERSION);

$VERSION = "1.00";

use DBI;

use Carp;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = ("Exporter", scalar caller);
@EXPORT = qw(
    DBDlogon DBDlogoff
    describe
    prepar prepex
    getrow getrows
    local_sql sql_into
    );

umask 0;

my $dbh;	# Everyone else uses prepex () or do ()

my @prepex_sql = ();

$SIG{__DIE__} = sub {
    $dbh && ($dbh->err || $dbh->state) or return;

    printf STDERR "DBI:DBD Failure from line %d in %s\n", (caller (1))[2, 1];
    $dbh->err    and print STDERR "    err:\t",    $dbh->err,    "\n";
    $dbh->errstr and print STDERR "    errstr:\t", $dbh->errstr, "\n";
    $dbh->state  and print STDERR "    state:\t",  $dbh->state,  "\n";
    @prepex_sql or return;
    print STDERR "    ", (join "\n    " =>
	"--------",
	grep (m/\S/ => @prepex_sql),
	"--------"), "\n";
    print caller (1), "\n";
    }; # __DIE__

### SQL utils #################################################################

sub DBDlogon (;$)	# Default Read-Only
{
    my $wr = shift || 0;
    $dbh and return $dbh;
    my $db = exists $ENV{MYSQLDB} ? $ENV{MYSQLDB} : "test";
    $dbh = DBI->connect ("DBI:mysql:database=$db", $ENV{LOGNAME}, 'm0use1', {
	RaiseError => 1,
	PrintError => 1,
	ChopBlanks => 1,
#	AutoCommit => 0,	# Croaks on this one.
	}) or
	    croak "connect: $!";
    $dbh;
    } # DBDlogon

sub DBDlogoff ()
{
    $dbh and $dbh->disconnect ();
    $dbh = undef;
    } # DBDlogoff

# prepex () serves two purposes:
# 1. Ease passed statement to allow statement lines in array
# 2. Hide $dbh to the outside world
# 3. Combine the ever occuring execute method after the prepare
# We do not have to check anything, since RaiseError is on
# It'll show the saved statement from @prepex_sql
sub prepar (@)
{
    $dbh or DBDlogon ();
    @prepex_sql = @_;
    my $sth = $dbh->prepare (join " " => @_);
    $sth;
    } # prepex

sub prepex (@)
{
    $dbh or DBDlogon ();
    @prepex_sql = @_;
    my $sth = $dbh->prepare (join " " => @_);
    $sth->execute ();
    @prepex_sql = ();
    $sth;
    } # prepex

# Next two are to prevent DB's like Oracle to convert empty strings to NULL

sub DBI::st::insert ($@)
{
    my $sth = shift;
    $sth->execute (map { defined ($_) && $_ eq "" ? " " : $_ } @_);
    } # insert

sub DBI::st::update ($@)
{
    my $sth = shift;
    $sth->execute (map { defined ($_) && $_ eq "" ? " " : $_ } @_);
    } # update

1;
