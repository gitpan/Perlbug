#!/pro/bin/perl -w

package Perlbug::Interface::Tk;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

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

my $dbtype;
my $dbh;	# Everyone else uses prepex () or do ()
my $dbh_st;

$SIG{__DIE__} = sub {
    $_[0] =~ m/^DBD::/ or return;
    $dbh && ($dbh->err || $dbh->state) or return;

    my ($depth, $file, $line) = (1, __FILE__);
    while ($file =~ m:/Tk.pm$:) { ($line, $file) = (caller ($depth++))[2, 1] }
    printf STDERR "DBI:DBD Failure from line %d in %s\n", $line, $file;
    $dbh->err    and print STDERR "    err:\t",    $dbh->err,    "\n";
    $dbh->errstr and print STDERR "    errstr:\t", $dbh->errstr, "\n";
    $dbh->state  and print STDERR "    state:\t",  $dbh->state,  "\n";
    if ($DBI::lasth) {
	my $s = $DBI::lasth->{Type} eq "st" ? $DBI::lasth->{Statement} : $dbh_st;
	print STDERR "    ", (join "\n    " =>
	    "--------",
	    split (m/\n/ => $s),
	    "--------"), "\n";
	}
    die "";
    }; # __DIE__

### SQL utils #################################################################

sub DBDlogon (;$$)	# Default Read-Only
{
    $dbh and return $dbh;

    my $wr   = 0;
    my %attr = (
	RaiseError => 1,
	PrintError => 1,
	AutoCommit => 0,
	ChopBlanks => 1,
	);
    $DBI::VERSION >= "1.15" and $attr{ShowErrorStatement} = 1;
    @_ && !ref $_[0] and $wr = shift;
    if (@_ &&  ref $_[0]) {
	my $r = shift;
	foreach my $attr (keys %$r) { $attr{$attr} = $r->{$attr} }
	}

    if (exists $ENV{ORACLE_HOME} && -d $ENV{ORACLE_HOME}) {
	my ($dbu, $dbp) = split m:/: => $ENV{DBUSER};
	$dbh = DBI->connect ("DBI:Oracle:", $dbu, $dbp, \%attr) or
	    croak "connect: $!";
	$wr or $dbh->do ("set transaction read only");
	$dbtype = "Oracle";
	}
    else {
	my $db = exists $ENV{MYSQLDB} ? $ENV{MYSQLDB} : "perlbug";
	delete $attr{AutoCommit};	# MySQL still croaks on this one
	$dbh = DBI->connect ("DBI:mysql:database=$db", $ENV{LOGNAME}, undef, \%attr) or
	    croak "connect: $!";
	$dbtype = "mysql";
	}
    $dbh;
    } # DBDlogon

sub DBDlogoff ()
{
    $dbh and $dbh->disconnect;
    $dbh = undef;
    } # DBDlogoff

# prepar () / prepex () serve two purposes:
# 1. Ease passed statement to allow statement lines in array
# 2. Hide $dbh to the outside world
# 3. Enable immediate column binding
# 4. Combine the ever occuring execute method after the prepare
# We do not have to check anything, since RaiseError is on
sub prepar (@)
{
    $dbh or DBDlogon ();
    my (@st, @bc);
    for (@_) { ref $_ ? push @bc, $_ : push @st, $_ }
    $dbh_st = join "\n", @st;
    my $sth = $dbh->prepare ($dbh_st);
    # MySQL does not support bind before execute.
    if (@bc) {
	$dbtype eq "mysql" and $sth->execute ((undef) x $sth->{NUM_OF_PARAMS});
	$sth->bind_columns (@bc);
	$dbtype eq "mysql" and $sth->finish;
	}
    $sth;
    } # prepar

sub prepex (@)
{
    my $sth = prepar (@_);
    $sth->execute;
    $sth;
    } # prepex

sub getrow (@)
{
    $dbh or DBDlogon ();
    $dbh_st = join "\n", @_;
    $dbh->selectrow_array ($dbh_st);
    } # getrow

sub getrows (@)
{
    my $sth = prepex (@_);
    $sth->getrows;
    } # getrows

sub describe ($)
{
    $dbh or DBDlogon ();
    my $sth = prepex ("select * from $_[0] where 0 = 1");
    my @desc;
    my @name = @{$sth->{NAME}};
    foreach my $i (0 .. $#name) {
	foreach my $col (qw( NAME TYPE PRECISION SCALE NULLABLE )) {
	    $desc[$i]{$col} = $sth->{$col}[$i];
	    }
	}
    @desc;
    } # describe

### ###########################################################################

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

sub DBI::st::getrows ($@)
{
    my $sth = shift;
    my @r = ();
    $sth->execute (@_);
    while (my @f = $sth->fetchrow_array) {
	push @r, @f == 1 ? $f[0] : [ @f ];
	}
    @r;
    } # getrows
