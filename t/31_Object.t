#!/usr/bin/perl -w
# Object retrieval, and oid recognition tests (for objects and relations) for Perlbug 
# Richard Foley RFI perlbug@rfi.net
# $Id: 32_Object.t,v 1.3 2001/12/01 15:24:43 richardf Exp $
#
BEGIN {
	use File::Spec; 
	use lib File::Spec->updir;
	use Perlbug::Test;
	plan('tests' => 3);
}
use strict;
use lib qw(../);
my $test = 0;
my $err = 0;


# Libs
# -----------------------------------------------------------------------------
use Perlbug::Base;
my $o_pb   = Perlbug::Base->new;
my $o_test = Perlbug::Test->new($o_pb);
my @objects= $o_pb->objects;

# Tests
# -----------------------------------------------------------------------------

$test++;
my $i_errs = 0;
my @failed = ();
foreach my $obj (@objects) {
	my $i_err = 0;
	my $o_obj = $o_pb->object($obj);
	my $ref = ref($o_obj);
	my $match = 'Perlbug::Object::'.ucfirst($obj);
	if ($ref !~ /^$match$/) {
		$i_err++;
		output("$obj failed to retrieve correct($match) ref($ref) object($o_obj)");
	}
	if ($i_err != 0) {
		$i_errs++;
		push(@failed, $obj);
	}
		
}
if ($i_errs == 0) {
	ok($test);
} else {
	ok(0);
	output("$i_errs objects failed(@failed)");
}

$test++;
$i_errs = 0;
@failed = ();
my $i_rels = 0;
foreach my $obj (@objects) {
	my $i_err = 0;
	my $o_obj = $o_pb->object($obj);
	foreach my $rel ($o_obj->rels) {
		my $o_rel = $o_pb->object($rel);
		my $ref = ref($o_rel);
		my $match = 'Perlbug::Object::'.ucfirst($rel);
		if ($ref !~ /^$match$/) {
			$i_err++;
			output("$obj rel($rel) failed to retrieve correct($match) ref($ref) relation($o_rel)");
		}
		if ($i_err != 0) {
			$i_errs++;
			push(@failed, "$obj:$rel");
		}
	}	
}
if ($i_errs == 0) {
	ok($test);
} else {
	ok(0);
	output("$i_errs objects failed $i_rels relations(@failed)");
}

# OID recognition
$test++;
$i_errs = 0;
@failed = ();
@objects = (defined($ARGV[0])) ? ($ARGV[0]) : @objects;
MATCH:
foreach my $obj (sort @objects) {
	my $i_err = 0;
	my $o_obj = $o_pb->object($obj);
	my $match = $o_obj->attr('match_oid');
	my $sql   = "SELECT MAX(".$o_obj->primary_key.") FROM ".$o_obj->attr('table');
	my ($maxid) = $o_obj->base->get_list($sql);
	if ($maxid !~ /^\w+/) {
		$i_err++;
		output("failed to retrieve $obj($o_obj) maxid($maxid)!");
	} else {
		my @failed = ();
		my %type   = (
			'plain'		=> [$maxid],
			'dashes'	=> ['-'.$maxid,   $maxid.'-',   '-'.$maxid.'-'],
			'underscore'=> ['_'.$maxid,   $maxid.'_',   '_'.$maxid.'_'],
			'ampersand'	=> ['@'.$maxid,   $maxid.'@',   '@'.$maxid.'@'],
			'numbers'	=> ['123'.$maxid, $maxid.'789', '123'.$maxid.'789'],
			'letters'	=> ['abc'.$maxid, $maxid.'xyz', 'abc'.$maxid.'xyz'], 
			# 'mixed'		=> ['abc'.$maxid, $maxid.'xy9', 'abc'.$maxid.'x8z'],
			'various'	=> [map { $_.$maxid, $maxid.$_, $_.$maxid.$_ } ( 
				qw(' " ` ? + _ | - * ^ & % $ \ / @ ! ~ ] [ { } . : ; > < ), ',', '(', ')'
			), # ' dequote 
			],
		);
		TYPES:
		foreach my $type (sort keys %type) {
			next TYPES if ($maxid =~ /^[a-z]+$/) and ($type eq 'letters');
			next TYPES if ($maxid =~ /^\d+$/)    and ($type eq 'numbers');
			my @fails = ();
			TYPE:	
			foreach my $str (@{$type{$type}}) {
				my ($id) = $o_obj->str2ids($str);	
				if ($id ne $maxid) {
					push(@fails, "str($str) => id($id)");
				}
			}
			push(@failed, "$type: ".join(', ', @fails)."\n") if @fails;
		}
		if (scalar(@failed) >= 1) {
			$i_errs++;
			output("Oid match errors: obj($obj) match($match) id($maxid): \n @failed\n");
			last MATCH;
		}
	}	
}
if ($i_errs == 0) {
	ok($test);
} else {
	ok(0);
	output("$i_errs objects failed matches");
}

# Done
# -----------------------------------------------------------------------------
#
