#!/usr/bin/perl 
# Perlbug mail interface to database (bugdb)
# (C) 1999 2000 Richard Foley RFI perlbug@rfi.net 
# $Id: mail.pl,v 1.3 2000/01/26 11:19:17 richard Exp $
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

my ($cmds) = $pb->parse_mail;
my $out = $pb->process_commands($cmds);
my $a_res = ($out == 1) ? $pb->get_results : "bugdb command failure -> '$out'";
$pb->return_info($mail, $a_res);
$pb->clean_up("$0 done");

exit(0);
