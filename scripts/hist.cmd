#!/usr/bin/perl 
# Perlbug historical data or archive processor 
# (C) 1999 Richard Foley RFI perlbug@rfi.net 
# $Id: hist.cmd,v 1.2 2000/01/26 11:19:36 richard Exp richard $
#

=head1 NAME

HIST - historical perlbug data processor

=head1 DESCRIPTION

Loops through all files in a given directory, looking for a potential mail message for entry, or otherwise in the perlbug database.

=head1 USAGE

	hist.cmd some_dir

=cut

use Carp; 
use IO::File;
use Mail::Internet;
use File::Spec; 
use lib (File::Spec->updir, qw(/home/richard/Live /home/perlbug));
use Perlbug::Email;
use strict;

my $VERSION = 1.01;

# Read the mail
# -----------------------------------------------------------------------------
my $ok = 1;
my $dir  = $ARGV[0];
if (($dir !~ /\w+/) || (! -d $dir) || (! -r _)) {
    $ok = 0;
    confess("Directory ($dir) invalid: $!");
}
if ($ok == 1) {
    print "Opening dir($dir)\n";
    opendir(DIR, $dir) || confess("Can't open dir($dir): $!");
    my @files = grep{ /\w+/ && -f "$dir/$_" } readdir(DIR);
    close DIR;
    if (@files >= 1) { 
        my $cnt = 1;
        print "Found [".@files."] files\n";
        foreach my $file (@files) {
	    	my $star = '';
			next unless $file =~ /\w+/ and  -e $dir.'/'.$file;
            # print "Opening file($dir/$file)\n";
            my $FH = IO::File->new;
            if (open($FH, "$dir/$file")) {
                my $mail = Mail::Internet->new($FH);
                close $FH;
				my $pb = Perlbug::Email->new($mail);
	    		$pb->mailing(0); # don't inform the list, just enter the data in the db!
            	my $meth = $pb->switch($mail);
                if ($meth =~ /new|reply/i) {
                    $star = '*';
                }
                my $ok = $pb->$meth($mail);
                undef $mail;
                $pb->clean_up("$0 meth($meth) -> ($ok)");
                print "[$cnt] -> ${meth}$star -> ok($ok)\n";
            } else {
                carp("Can't open file($dir/$file): $!");
            }
            last if $cnt >= 111; # keep it low for the moment
            $cnt++;
        }
        print "All [".($cnt - 1)."] files done -> ok($ok)\n";
    }
}

print "All over -> ok($ok)\n";

exit 0;
