# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Relation.pm,v 1.34 2001/10/22 15:29:50 richardf Exp $
#

=head1 NAME

Perlbug::Object - Relation class

=cut

package Perlbug::Relation;
use strict;
use vars(qw($VERSION @ISA));
@ISA = qw(Perlbug::Object); 
$VERSION = do { my @r = (q$Revision: 1.34 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

=head1 DESCRIPTION

Perlbug relation class.

Handles reading of existing, and assignment of new etc., relations between existing objects.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;


=head1 SYNOPSIS

	use Perlbug::Relation;

	my $o_rel = Perlbug::Relation->new('bug', 'patch', 'from');

	my @pids  = $o_rel->read('19870502.007', '')->ids;


=head1 METHODS

=over 4

=item new

Create new Relation object, using text indicators or the object itself, if you have it

	my $o_rel = Perlbug::Relation->new('bug', 'patch', 'to'); 

Or the other way round:

	my $o_rel = Perlbug::Relation->new('patch', 'bug', 'from');

If missing, the third argument will default to 'to'.

	my $o_rel = Perlbug::Relation->new($o_src, 'address'); # implied 'to'

Normally this won't be called directy, as you'll ask for an relation object 
from the object itself directly, and the object will pre-initialise the 
relationship, which is far more useful, like this:

	my $o_rel = $o_obj->relation('patch'); # <-- !

For more on this, see L<Perlbug::Object::relation()> and L<Perlbug::Base::object()>

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_Perlbug_Base = 
		(ref($_[0]) =~ /^Perlbug::(Base|Fix|(Interface::(Cmd|Email|Web)))$/o) 
		? shift 
		: Perlbug::Base->new; # yek, but...

	my $src    = shift;
	my $tgt    = shift;
	my $type   = shift || 'to';
	($src, $tgt) = ($type eq 'from') ? ($tgt, $src) : ($src, $tgt);

	my $o_src = (ref($src)) ? $src : $o_Perlbug_Base->object($src);	# cache?
	my $s_key = $o_src->attr('key');

	my $o_tgt = (ref($tgt)) ? $tgt : $o_Perlbug_Base->object($tgt);	# cache?
	my $hint = $src.'_x_'.$tgt;
	my $t_key = lc(($hint =~ /(parent|child)/io) ? $1 : $o_tgt->attr('key')); # ek s too?
	
	# $self->check($o_src, $o_tgt);
	my $table = 'pb_'.join('_', sort($s_key, $t_key));
	my $self = Perlbug::Object->new( $o_Perlbug_Base, 
		'hint'			=> $hint,					# bug->child|parent
		'key'			=> $s_key.'->'.$t_key,		# bug->patch
		'match_oid'		=> $o_src->attr('match_oid'),
		'name' 			=> ucfirst($s_key),
		# 'table'   		=> 'pb_'.$s_key.'_'.$t_key,	# pb_bug_patch | pb_address_bug
		'table'   		=> $table,					# pb_bug_patch | pb_address_bug
		'type'			=> $type,					# from|to
	);
	$self->{'_attr'}{'source'} = $s_key;		# indicator	
	$self->{'_attr'}{'target'} = $t_key;		# indicator

	bless($self, $class);

	$table = $self->attr('table');
	$self->debug(3, "rjsf: Relation::new($type) src($src)\t-> ".
		sprintf('%-15s', $o_src).") & tgt($tgt)\t-> ".
		sprintf('%-15s', $o_tgt)." table($table)"
	) if $Perlbug::DEBUG;

	$self->source($o_src); 
	$self->target($o_tgt); 
	$self->check();

	return $self;
}


=item source

Get and set Source object

	my $o_src = $o_rel->source();

=cut

sub source {
	my $self  = shift;
	my $o_src = shift;
	my $key   = lc(shift || $self->attr('source'));

	my $o_obj = $self->object($key, $o_src);

	return $o_obj;
}	
 
 
=item target

Get and set target object

	my $o_tgt = $o_rel->target();

=cut

sub target {
	my $self  = shift;
	my $o_tgt = shift;
	my $key   = lc(shift || $self->attr('target'));

	my $o_obj = $self->object($key, $o_tgt);

	return $o_obj;
}	


=item check

Check the relations are OK to each other

	my $i_ok = $o_rel->check();

=cut

sub check {
	my $self  = shift;
	my $o_src = shift || $self->source;
	my $o_tgt = shift || $self->target;
	my $i_ok  = 0;

	my $hint  = $self->attr('hint');
	my $name  = $self->attr('name');
	my $table = $self->attr('table');

	my $src = $o_src->key;
	my @src_from = @{$o_src->attr('from')};
	my @src_to = @{$o_src->attr('to')};

	my $tgt = $o_tgt->key;
	my @tgt_from = @{$o_tgt->attr('from')};
	my @tgt_to   = @{$o_tgt->attr('to')};

	# $src = 'parent' if $o_src =~ /parent/i;
	# $tgt = 'child'  if $o_tgt =~ /child/i;

	# VET
	my $err = '';
	unless ($hint =~ /(parent|child)/io) {
		if (lc($src) eq lc($tgt)) {
			$err = "Source(".ref($o_src).") is the same as target(".ref($o_tgt).")!"; 
		}
		if (!(grep(/^$tgt$/, @src_to, @src_from))) {
			$err = "Source(".ref($o_src).") doesn't recognise target(".ref($o_tgt).")!";
		}
		if (!(grep(/^$src$/, @tgt_to, @tgt_from))) {
			$err = "Target(".ref($o_tgt).") doesn't recognise source(".ref($o_src).")!";
		}
	}

	if ($err !~ /\w+/) {
		$i_ok++;
	} else {
		$self->error(qq|$self $hint $name $table
		Src($src) $o_src 
			from(@src_from) 
			to(@src_to)
		Tgt($tgt) $o_tgt
			from(@tgt_from) 
			to(@tgt_to)
		$err
		|); 
	}

	return $i_ok;
}


=item set_source

Set source to given argument key, and objectid, used to ensure the relation object is reading/setting/etc. from the correct source/target combination.  

	my $o_rel = $o_rel->set_source('status', '33');

An example of where this might be necessary or useful is when object caching is enabled from the application side, a B<bug> and a B<status> object have been created, and they both require a relation to one another to be handled.  

Alternatively, from the command line, one can do this, noting that at the return of B<relation()> and B<assign()> the source is by default set to the creating object, in this case the B<bug>, and to read the B<patch> record, we need to B<set_source()> the relation:

	perl -MPerlbug::Base -e "\
		print Perlbug::Object::Bug->new(\
		)->read('20000801.007')->relation('patch')->assign(\
		[('12', '1', '2', '4', '5')])->set_source('patch'\
		)->read('2')->format('A')\
		" 
Enjoy :-)

=cut

sub set_source {
	my $self  = shift;
	my $key = lc(shift);
	my $oid = shift || '';

	my ($o_src, $o_tgt) = ($self->source, $self->target);
	my ($s_key, $t_key) = ($o_src->key, $o_tgt->key);
	my $type = ($self->attr('type') eq 'from') ? 'to' : 'from';
	if ($key =~ /\w+/o && $key eq $t_key) { # swap'em
		$self->attr({
			'type'   => $type, # 
			'source' => $t_key,
			'target' => $s_key
		}); # 
		$self->source($o_tgt, $t_key);	
		$self->target($o_src, $s_key);	
		$o_src = $self->source;
		$o_tgt = $self->target;
	}
	$o_src->oid($oid) if $oid;

	$self->check();
	$self->debug(3, qq|key($key) oid($oid) type($type)...
		src($s_key)\t-> o_src($o_src)
		tgt($t_key)\t-> o_tgt($o_tgt)
	|) if $Perlbug::DEBUG;	

	return $self;
}	


=item key 

get B<source> or B<target> primary (relation) key(), default is source

	my $s_key = $o_obj->key;

	my $t_key = $o_obj->key('target');

=cut

sub key {
	my $self = shift;
	my $type = shift || 'source';

	my $res = lc($self->$type()->key).'id';

	return $res;
}


=item oid 

Wrapper to get and set self and source objectid. 

	my $rel_oid = $o_rel->oid($id);

=cut

sub oid { # ?
	my $self = shift;
	my $in  = shift || '';

	my ($o_src, $s_key) = ($self->source, $self->key('source'));
	my ($o_tgt, $t_key) = ($self->target, $self->key('target'));

	if (defined($in)) {
		my $src = $self->source->oid($in);
		$self->attr({'objectid' => $in});
		$self->data({ $s_key => $in });
	}
	my $oid = $self->attr('objectid');
	# my $oid = $self->SUPER::oid($src);
	$self->debug(3, "oid: src($s_key) tgt($t_key) -> in($in) oid($oid)") if $Perlbug::DEBUG;

	return $oid;
}


=item ids

Returns list of target ids, restrained by optionally supplied object or sql where statement:

	my @all_ids  = $o_rel->ids();

	my @rel_ids  = $o_obj->ids($o_rel, [$further_restrained_by_sql]);

	my @selected = $o_rel->ids($where);

=cut

sub ids { # class 
	my $self = shift;
	my $input = shift || '';
	my $extra = shift || '';
 
	my ($o_src, $s_key) = ($self->source, $self->key('source'));
	my ($o_tgt, $t_key) = ($self->target, $self->key('target'));

	my $sql = "SELECT DISTINCT $t_key FROM ".$self->attr('table');
	if (ref($input)) {				# OBJECT with ids, etc.
		$sql .= ' WHERE '.$input->key."id = '".$input->oid()."'";		
		$sql .= " AND $extra" if $extra;
	} elsif ($input =~ /\w+/o) { 	# SQL where clause
		$input =~ s/^\s*WHERE\s*//io;
		$sql  .= " WHERE $input";	
	} # else = all 
	
	my @ids = $self->base->get_list($sql);

	return @ids;
}


=item reinit 

Reset relation to default values

For more info see L<Perlbug::Object::reinit()>

=cut

sub reinit { 
	my $self = shift; 
	my $oid = shift || $self->oid;

	$self->SUPER::reinit($oid);
	$self->ASSIGNED(0);

	$self;
}


sub prep {
	my $self = shift;
	my $sql = $self->SUPER::prep(@_);

	$self->error("NULL's not allowed in relations: ".$sql) if $sql =~ /NULL/o;
	
	# useless query while patchid=3, addressid=3
	# $self->error("Duplicate ids? 1($1) 2($2): ".$sql) 
	#	if $sql =~ /(\w+)id\s*=\s*\'*([^\'])\'*/ && $sql =~ /\G.+($1)id\s*=\s*\'*$2\'*/g;

	return $sql;
}


sub track { # do nothing (wasteful)
	my $self = shift;

	$self->TRACKED(1);

	return $self;
}

=pod

=back

=head1 RECORDS

Record handling methods for L<Perlbug::Relation::\w+>'s

These all return the object reference, so calls may be chained.

=over 4

=item assign

Assign these ids (additionally), ie; B<non>-prejudicial to other ids.

	$o_rel->assign(\@new_ids);

=cut

sub assign {
	my $self = shift;
	my $a_input = shift;

	if (!ref($a_input)) {
		$self->error("no input ids given to assign($a_input)");
	} else {
		my @given = @{$a_input};

		my ($o_src, $s_key) = ($self->source, $self->key('source'));
		my ($o_tgt, $t_key) = ($self->target, $self->key('target'));
		
		my @ids = $o_tgt->exists($a_input);
		my $oid = $o_src->oid;
		if (!$o_src->exists([$oid])) { # rjsf - problem with sql caching!
			$self->error("has no source valid objectid($oid) to assign from!");
		} else {
			my $ids = join("', '", @ids);
			$self->debug(1, "working with ids(@ids) from ".Dumper($a_input)) if $Perlbug::DEBUG;
			foreach my $id (@ids) {
				$self->oid($oid);
				$self->data({ $t_key => $id, });
				$self->create($self->_oref('data'), 'relation');
				if ($self->CREATED) {
					$self->ASSIGNED(1);
					$self->debug(2, "assigned: $s_key($oid) $t_key($id)") if $Perlbug::DEBUG;
				}
			}
		}
	}

	return $self;
}


=item ASSIGNED 

Returns 0|1 depending on whether object has been succesfully assigned to 

	my $i_isok = $o_obj->ASSIGNED;

=cut

sub ASSIGNED {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'assigned', $1}) if $i_flag =~ /^(1|0)$/o;

	$i_flag = $self->flag('assigned');


	return $i_flag;	
}


=item _assign

Wraps B<assign()> to allow usage of name instead of id.

	$o_rel->_assign(\@names);

=cut

sub _assign {
	my $self = shift;
	my $a_input = shift;

	if (!ref($a_input)) {
		$self->error("no input names given to _assign($a_input)");
	} else {
		my $rel = ref($self);
		$self->create_target($a_input);	
		my @ids = $self->target->name2id($a_input);
		$self->assign(\@ids);
	} 


	return $self;
}


=item store

Assign these target ids (only) to the source, (given at L<new()>)

A bit like L<assign()>, but B<very> prejudicial against non-mentioned ids.

	$o_rel->store(\@ids);

B<Warning>: this will remove B<all> relative ids that are B<not> mentioned!  If in doubt use B<assign()>.

=cut

sub store {
	my $self = shift;
	my $a_input= shift || '';

	if (!ref($a_input)) {
		$self->error("no input ids given to store($a_input)");
	} else {
		my @orig = @{$a_input};
		my @IDS  = ();

		my ($o_src, $s_key) = ($self->source, $self->key('source'));
		my ($o_tgt, $t_key) = ($self->target, $self->key('target'));

		my @ids = $o_tgt->exists($a_input);
		my $ids = join("', '", @ids);
		my $oid = $o_src->oid();

		if (scalar($o_src->exists([$oid])) == 0) {
			$self->error("has no source objectid($oid) to store against!");
		} else {
			if (!(scalar(@ids) >= 1)) {
				$self->debug(0, "not trashing($oid) records unless supplied(@orig) with valid objectids(@ids)!"); # try using delete()
			} else { # can't use $self->delete([target NOT IN (...)])
				$self->assign(\@ids); # first!
				$self->debug(0, "assigned(".$self->ASSIGNED.") ids(@ids)") if $Perlbug::DEBUG;
				if ($self->ASSIGNED) {
					my $where = " WHERE $s_key = '".$o_src->oid()."'";		
					my $sql = "DELETE FROM ".$self->attr('table')." $where AND $t_key NOT IN ('$ids')"; 
					my $sth = $self->base->exec($sql);
					$self->debug(3, "prejudicial(".$self->ASSIGNED.") DELETE WHERE NOT IN ids($ids)") if $Perlbug::DEBUG;
					if ($sth) {
						$self->STORED(1);
						$self->base->clean_cache('sql');
					} else { 
						$self->error(ref($self)." trim failed: sql($sql) -> sth($sth)");
					}
				}
			}
		}
	}


	return $self;
}


=item _store

Wraps L<store()> to allow usage of name instead of id.

	$o_rel->_store(\@names);

=cut

sub _store {
	my $self = shift;
	my $a_input = shift || '';

	if (!ref($a_input)) {
		$self->error("no input names given to _store($a_input)");
	} else {
		$self->create_target($a_input);	
		my @ids = $self->target->name2id($a_input);
		$self->store(\@ids);
	}


	return $self;
}


=item delete 

Delete these target ids

	$o_rel->delete(@unwanted_ids);

=cut

sub delete {
	my $self = shift;
	my $a_input= shift || '';

	if (!ref($a_input)) {
		$self->error("no input ids given to delete($a_input)");
	} else {
		my @orig = @{$a_input};
		my @IDS  = ();

		my ($o_src, $s_key) = ($self->source, $self->key('source'));
		my ($o_tgt, $t_key) = ($self->target, $self->key('target'));

		my @ids = $o_tgt->exists($a_input);
		$self->debug(3, "working with ids(@ids)") if $Perlbug::DEBUG;
		my $ids = join("', '", @ids);
		my $oid = $o_src->oid();
		if (scalar($o_src->exists([$oid])) == 0) {
			$self->error("has no source objectid($oid) to delete!");
		} else {
			my $where = " WHERE $s_key = '$oid'";		
			my $sql = "DELETE FROM ".$self->attr('table')." $where AND $t_key IN ('$ids')"; 
			my $sth = $self->base->exec($sql);
			if (!$sth) {
				$self->error(ref($self)." delete failed: sql($sql) -> sth($sth)");
			} else {
				$self->DELETED(1);
				$self->base->clean_cache('sql');
			}
		}
	}


	return $self;
}


=item _delete

Wraps L<delete()> to allow usage of name instead of id

	$o_rel->_delete(\@names);

=cut

sub _delete {
	my $self = shift;
	my $a_input = shift || '';

	if (!ref($a_input)) {
		$self->error("no input names given to _delete($a_input)");
	} else {
		my @ids = $self->target->name2id($a_input);
		$self->delete(\@ids);
	}


	return $self;
}


=item create_target 

Create these target ids - note that there is no implicit B<assign()> here, if you want that, see L<_assign()>

Input is expected to be the non-internally known B<identifier> itself, rather than the system known B<id()>.  

	$o_rel->create_target(\@names); 			# eg; changeids|versions|...

	$o_rel->assign([$o_rel->name2id(\@names)]); # then?

=cut

sub create_target { # by id from hashref
	my $self = shift;
	my $a_input= shift;

	my ($table, $pri) = ($self->attr('table'), $self->attr('primary_key'));

	if (!ref($a_input) eq 'ARRAY') {
		$self->error("no ids given to create_target($a_input) from");
	} else {
		my @given = $self->trim($a_input);

		my ($o_src, $s_key) = ($self->source, $self->key('source'));
		my ($o_tgt, $t_key) = ($self->target, $self->key('target'));
		my $t_pri = $o_tgt->primary_key;

		if (scalar(@given) == 0) {
			$self->error("has no target objectids(@given) to create_target for!");
		} else {
			my @exist = $o_tgt->_exists(\@given);
			my @extantids = $o_tgt->name2id(\@exist);
			$self->debug(1, "pri($t_pri) given(@given) exist(@exist) extant(@extantids)") if $Perlbug::DEBUG;
			IDENT:
			foreach my $ident (@given) {
				next IDENT unless $ident =~ /\w+/o;
				$self->debug(1, "does $ident exist(@exist)?") if $Perlbug::DEBUG;
				next IDENT if grep(/^$ident$/, @exist);
				$self->debug(1, "NOPE($ident) -> inserting!") if $Perlbug::DEBUG;
				$o_tgt->reinit->data({ 
					$t_key => $self->new_id,	
					$o_tgt->identifier => $ident, 
				});
				$o_tgt->create($o_tgt->_oref('data')); # the new target
			}
		}
	}


	return $self;
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut


# 
1;

