#!/usr/bin/perl 
# Perlbug mail bugtron processor (tron) 
# (C) 1999 2000 Richard Foley RFI perlbug@rfi.net 
# $Id: tron.pl,v 1.2 2000/01/26 11:18:57 richard Exp $
#
use strict;
use File::Spec; 
use lib (File::Spec->updir, qw(/home/richard/Live /home/perlbug));
use Mail::Internet;
use Perlbug::Email;
use vars qw($VERSION);
$VERSION = 1.03;
$|=1;

my $mail = Mail::Internet->new(*STDIN);
my $pb = Perlbug::Email->new($mail);

my ($meth, $args) = $pb->switch;
my $ok = $pb->$meth($mail); 
$pb->clean_up("$0 meth($meth) -> ($ok)");

exit 0;
