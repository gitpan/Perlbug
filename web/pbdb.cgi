#!/usr/bin/perl 
# Perlbug web frontend
# (C) 1999 Richard Foley RFI perlbug@rfi.net 
# $Id: perlbug.cgi,v 1.2 2000/01/22 22:07:53 richard Exp richard $
#
use strict;
use lib qw(../ ../../);
use Perlbug::Web;
$| = 1;
my $VERSION = 1.01;

my $pb = Perlbug::Web->new;
print $pb->header;
my ($request) = $pb->switch;
print $pb->request($request); # meat here
print $pb->footer;
$pb->clean_up;
exit(0);

