#!/usr/bin/perl -w
# Clean pre- and post- test runs 00_Clean.t 99_Clean.t
# Richard Foley RFI perlbug@rfi.net
# $Id: 99_Clean.t,v 1.3 2001/10/19 12:40:21 richardf Exp $
# 00_Test.t also :-)
#
# Note: this only does the mail objects at the moment!
# bugfix will handle the relations...
#

use strict;
use lib qw(../);
use Perlbug::Base;
use Perlbug::Test;
plan('tests' => 7);
my $test = 0;
my $err  = 0;
my $context = '';
my $o_pb = Perlbug::Base->new;
$o_pb->current('admin', 'richardf');
$o_pb->current('isatest', 1);

my %map = ( # object types 
	'application'	=> 'primary_in_testids',
	'flag'			=> 'primary_in_testids',
	'item'			=> 'primary_in_testids',
	'mail'			=> qq|sourceaddr LIKE '%perlbug_test\@rfi.net%'|,
);

my $o_object = $o_pb->object('object');
TYPE:
foreach my $type (sort $o_object->col('type')) { #
	next TYPE unless grep(/^$type$/, keys %map);	
	next TYPE unless $type eq 'mail';			# ! -->	
	OBJECT:	
	foreach my $o (sort $o_object->col('name', "type = '$type'")) {
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
