#!/usr/bin/perl -w
# Email tests for Perlbug: check the tron switching/decision mechanism: expects context return value(reply|quiet|etc...)
# Richard Foley RFI perlbug@rfi.net
# $Id: 99_Clean.t,v 1.1 2001/03/31 16:15:01 perlbug Exp $
# 00_Test.t also :-)
#
# Note: this only does the mail objects at the moment!
# bugfix will handle the relations...
#

BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::TestBed;
	plan('tests' => 7);
}
use strict;
use lib qw(../);
use Perlbug::Base;
my $test = 0;
my $err  = 0;
my $context = '';
my $o_pb = Perlbug::Base->new;
$o_pb->current('admin', 'richardf');
$o_pb->current('isatest', 1);

my %map = ( # thing types 
	'application'	=> 'primary_in_testids',
	'flag'			=> 'primary_in_testids',
	'item'			=> 'primary_in_testids',
	'mail'			=> qq|sourceaddr LIKE '%perlbug_test\@rfi.net%'|,
);

my $o_thing = $o_pb->object('thing');
TYPE:
foreach my $type (sort $o_thing->col('type')) { #
	next TYPE unless grep(/^$type$/, keys %map);	
	next TYPE unless $type eq 'mail';			# ! -->	
	OBJECT:	
	foreach my $o (sort $o_thing->col('name', "type = '$type'")) {
		next OBJECT unless $o =~ /\w+/;
		$err = 0;
		$test++; 
		my $o_obj = $o_pb->object($o);
		if (!(ref($o_obj))) {
			$err++;
			output("Can't get object($o_obj) with this($o)!");
		} else {
			my ($key, $table, $pri) = ($o_obj->key, $o_obj->attr('table'), $o_obj->primary_key);
			my $case = $map{$type}; 		# <-- !
			my @ids = $o_obj->ids($case);
			my $ids = join("', '", @ids);
			$o_obj->delete(\@ids) if @ids;
			my $del = $o_obj->DELETED;
			$err++ unless scalar(@ids) == 0 || $del >= 1;
			output("$key($table) primary($pri) -> ids(@ids) -> deleted($del) -> err($err)") if $err;
			ok(!$err);
		}
	}
}

# done
