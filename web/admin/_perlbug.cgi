#!/usr/bin/perl 
# Perlbug web frontend
# (C) 1999 Richard Foley RFI perlbug@rfi.net 
# $Id: bugcgi,v 1.5 2001/09/18 13:37:50 richardf Exp $
#
use strict;
use vars qw($VERSION);
$VERSION = do { my @r = (q$Revision: 1.5 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1;

use FindBin;
use lib ("$FindBin::Bin/..", "$FindBin::Bin/../..");
use Perlbug::Interface::Web;

my $o_pb = Perlbug::Interface::Web->new(@ARGV);
my $req = $o_pb->switch();

print $o_pb->start($req); 	# header - html - form

print $o_pb->request($req); # <-- doit 

print $o_pb->finish($req); 	# form - html 
$o_pb->clean_up;

exit(0);

