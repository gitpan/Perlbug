#!/usr/bin/perl -w
# Format (href|mailto|popup) tests for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 31_Format.t,v 1.1 2000/08/07 07:31:26 perlbug Exp perlbug $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Data::Dumper;
	use Perlbug::Testing;
	plan('tests' => 6);
}
use strict;
use lib qw(../);
my $test = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_fmt = Perlbug::Base->new;

# Tests
# -----------------------------------------------------------------------------
my %tkt = (
	'bugid' 	=> '19990102.003',	
	'address'  	=> 'perlbug_test@rfi.net',
	'osname'   	=> 'generic',
	'unique_id'	=> 'abc_today',
);

# 1
# href? 
$test++; 
my ($href) = $o_fmt->href('bid', [$tkt{'bugid'}], 'Bug report');
if ($href =~ /^\<a\shref\=\".+\?req\=bid\&bid=$tkt{'bugid'}.+?\"\s*\>Bug\sreport\<\/a\>$/i) {	
	ok($test);
} else {
	notok($test);
	output("href($href) failed from data -> ($tkt{'bugid'})");
}

# 2
# href? 
$test++; 
my ($xhref) = $o_fmt->href('bid', [$tkt{'bugid'}], 'Bug repoort');
if ($xhref !~ /^\<a\shref\=\".+\?req\=bid\&bid=$tkt{'bugid'}.+?\"\s*\>Bug\sreport\<\/a\>$/i) {	
	ok($test);
} else {
	notok($test);
	output("href($xhref) failed from data -> ($tkt{'bugid'})");
}

# 3
# mailto -> generic
$test++;
my $mailto = $o_fmt->mailto(\%tkt); 
my $generic = $o_fmt->forward('generic');
if ($mailto =~ /^\<a\shref\=\"mailto:$generic\"\>reply\<\/a\>$/i) {
	ok($test);
} else {
	notok($test);
	output("mailto($mailto -> $generic) failed from data -> ".Dumper(\%tkt));
}

# 4
# mailto -> !generic
$test++;
$tkt{'osname'} = 'macos';
my $xmailto = $o_fmt->mailto(\%tkt); 
$generic = $o_fmt->forward('generic');
if ($xmailto !~ /^\<a\shref\=\"mailto:$generic\"\>reply\<\/a\>$/i) {
	ok($test);
} else {
	notok($test);
	output("mailto($xmailto -> $generic) failed from data -> ".Dumper(\%tkt));
}

# 5
# popup?
$test++;
my $popup = $o_fmt->popup('status', $tkt{'unique_id'}, 'onhold');
if ($popup =~ /^\<SELECT\sNAME\=\"$tkt{'unique_id'}"\>\n\<OPTION.+/i) {	
    # $popup =~ /\<OPTION\sSELECTED\sVALUE\=\"onhold\"\>onhold/msi) {	
	ok($test);
} else {
	notok($test);
	output("popup($popup) failed from data -> ($tkt{'unique_id'})");
}

# 6
# popup?
$test++;
my $xpopup = $o_fmt->popup('status', 'xyz', 'onhold');
if ($xpopup !~ /^\<SELECT\sNAME\=\"$tkt{'unique_id'}"\>\n\<OPTION.+/i) {	
    # $popup =~ /\<OPTION\sSELECTED\sVALUE\=\"onhold\"\>onhold/msi) {	
	ok($test);
} else {
	notok($test);
	output("popup($xpopup) failed from data -> ($tkt{'unique_id'})");
}

# Done
# -----------------------------------------------------------------------------
# .
