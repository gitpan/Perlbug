#!/usr/bin/perl 
# Perlbug cron daemon - assign open bugs to active admins, backup database etc.
# (C) 1999 Richard Foley RFI perlbug@rfi.net 
# $Id: cron.cmd,v 1.3 2000/07/26 11:06:23 perlbug Exp perlbug $
# 
# 22.09.1999 Initial version
# 25.09.1999 active admin list
# 22.10.1999 Config, debug, assign_bugs v1.01
# 20.06.2000 backup database
# 26.07.2000 overview (again)
# 

use File::Spec; 
use lib (File::Spec->updir, qw(/home/richard/Live /home/perlbug));
use Mail::Header;
use Perlbug::Email;
use Perlbug::Cmd;
use strict;
my $VERSION = 1.04;

# -----------------------------------------------------------------------------
my $pb = Perlbug::Email->new();
$pb->_original_mail($pb->_duff_mail);
my $cmd = Perlbug::Cmd->new;
$pb->debug(1, "$0: $pb");
$cmd->prioritise(22); # what the heck.

my $ok = 1;
my $admin  = $pb->system('maintainer');
my $admins = my @admins = $pb->active_admins;
my @addresses = $pb->active_admin_addresses;

# overview
if ($ok == 1) {
	$ok = $pb->doo;
	my $overview = $pb->get_results;
	my $o_ver = $pb->get_header;
	$o_ver->add('To' => $admin);
	$o_ver->add('Cc' => join(', ', @addresses, $pb->forward('generic')));
    $o_ver->add('Subject' => $pb->system('title').' overview');
    $ok = $pb->send_mail($o_ver, $overview);
}

# ADMINS (active list), UN/CLAIMED
if ($ok == 123) {
	$pb->debug(1, "Doing active administrators");
	my @claimed   = $pb->get_list("SELECT DISTINCT bugid FROM tm_bug_user");
	my $claimed   = join("', '", @claimed);
	my $getuncl   = "SELECT bugid FROM tm_bug WHERE bugid NOT IN ('$claimed')";
	my @unclaimed = $pb->get_list($getuncl);
	my $unclaimed = @unclaimed;
	my $max = sprintf("%03d", (scalar @unclaimed / scalar @admins || 1));
	my $MAX = ($max >= 5) ? $pb->system('max_age') : $max;
	$pb->debug(0,"Admins($admins), unclaimed($unclaimed), each($max->$MAX)");
	foreach my $admin (@admins) {
    	my $ok = $pb->assign_bugs($admin, $MAX, \@unclaimed);
	}    
}

# backup db
if ($ok == 1) {	
	$cmd->debug(1, "Doing database backup");
	$ok = $cmd->doD;
}

$pb->debug(1, "$0 -> ($ok)");
$pb->clean_up;
exit 0;
