# Perlbug object attribute handler
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: Object.pm,v 1.53 2002/02/01 08:36:45 richardf Exp $
#

=head1 NAME

Perlbug::Object - Object handler for Perlbug database

=cut

package Perlbug::Object;
use strict;
use vars(qw($VERSION @ISA $AUTOLOAD));
@ISA = qw(Perlbug::Format); 
$VERSION = do { my @r = (q$Revision: 1.53 $ =~ /\d+/go); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

use Carp;
use CGI;
use Data::Dumper;
use Perlbug::Format; 
# use Perlbug::Template; 
my $o_Perlbug_Base = '';
%Perlbug::Object::Data = (); # ?
%Perlbug::Object::Data = (
	'relation'	=> {
		'from'	=> [],
		'to'	=> [],
	},
	'type'		=> {
		'field'	=> 'VARCHAR',
	},
);

=head1 DESCRIPTION

Handles Perlbug database objects, typically bug, group, message, patch, note, test, user, and severity, status etc....

Methods included to recognise objects by their id or by their also unique name.


=head1 SYNOPSIS

	my $o_obj 	= Perlbug::Object->new(\%init); # see L<new()>

	$o_obj 		= $o_obj->read($oid);		# data

	my $name   	= $o_obj->data('name'); 	# Bug

	# ALL bugids (optionally) constrained by sql 'where' clause
	my @ids         = $o_obj->ids($where);	# where

	# Relation ids
	my @patchids	= $o_obj->rel_ids('patch');	# relids 

	print = $o_obj->format('h');		

=head1 METHODS

=over 4

=item new

Create a new object, you need to supply up to three (3) things: 

	1. A pre-initialised Perlbug::Base->new() object:

	2. Attribute pairs: 

	3. Relation array refs:

		b<float> is a straight column related to our id and has no distinct object handler, 

		b<from> and B<to> are related with full ids, handlers, etc. treatment.

Example:

	my $o_obj = Perlbug::Object->new( 
		# Optional base object, useful to maintain transactions
			$o_Perlbug_Base_Object, 	# 
		# Attributes
			'name'	=> 'Bug',		# mandatory key 
		# Relationships	
			'float'	=> [qw(change)],			
			'from'	=> [],
			'to'	=> [qw(message note patch test user)], 
	};

=cut

sub new { # table, key
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	$o_Perlbug_Base = (ref($_[0])) ? shift : Perlbug::Base->new;
	my %input  = @_;

	my $name = ucfirst($input{'name'});
	my $key  = lc($name);
	unless ($key =~ /\w+/o) {
		$o_Perlbug_Base->error("Fatal error: no keyname($name) given!\n".Dumper(\%input)."\n");
	}

	my $self = { 												# eg:
		'_attr'	=> {			
			'float'		=> [],				# rel
			'from'		=> [],				# rel
			'hint'		=> "$name($key)",	# Bug(Child)...
		    'key'		=> $key,			# bug
		    'name'  	=> $name,			# Bug
			'match_oid'	=> '[\b\D]*(\d+)[\b\D]*',  		# default
		    'objectid'	=> '',				# 21, 200011122.003
			'primary_key'=> $key.'id',		# bugid
			'printed'	=> 0,				# i_cnt
			'prejudicial'=> 0,				# single only (ie; status, severity, etc.)?
			'sql_clean'	=> 1,				# clean sql on create, update, delete, etc.
		    'table' 	=> 'pb_'.$key,		# db_bug
			'track'		=> '1',				# usually
			'to'		=> [],				# rel
			'types'		=> [qw(from to)], 	# of rels
			%input,
		},  	
		'_data'			=> {}, 		 		# 'field' 	=> 'value' ...
		'_type'			=> {},				# 'field'	=> 'DATE|INTEGER|VARCHAR'...
		'_relation'		=> {},				# 'from' => [], 'to' => [qw(patch status ...)],
		'_flag'			=> {
			'assigned'	=> 0,				# flags
			'created'	=> 0,				#  -"- 
			'deleted'	=> 0,				#  -"- 
			'read'		=> 0,				#  -"- 
			'reset'		=> 0,				#  -"- 
			'stored'	=> 0,				#  -"-
			'tracked'	=> 0,				#  -"-
			'updated'	=> 0,				#  -"-
		},
	};

	$self = bless($self, $class);

	$self->data; $self->attr; $self->flag; # prime
	$self = $self->reinit; # inc. check()

	return $self;
}


=item init_data 

Initialise generic object attr, columns and column_types from table in db (specific).

	my $o_obj = $o_obj->init_data($table);

=cut

sub init_data { # generic attr from db
	my $self  = shift;
	my $table = shift || $self->attr('table');

	$self->{'_data'} = {};
	$self->{'_type'} = {};

	# my $fields = "SELECT * FROM $table WHERE 1 = 0";
	my $fields = "SHOW fields FROM $table"; # Mysql specific?
	my @fields = $self->base->get_data($fields);
	FIELD:
	foreach my $f (@fields) { 
		next FIELD unless ref($f) eq 'HASH';
		my $field = $$f{'Field'};
		my $type  = 'VARCHAR'; # default
		$type = 'DATETIME' if $$f{'Type'} =~ /^DATE(TIME)*$/io;
		$type = 'INTEGER'  if $$f{'Type'} =~ /^(BIG|SMALL)*INT(EGER)*(\(\d+\))*/io;
		# $Perlbug::Object{'_data'}{$field} = '';
		# $Perlbug::Object{'_type'}{$field} = $type;
		$self->{'_data'}{$field} = ''; 		# init	
		$self->{'_type'}{$field} = $type; 	# init	
		# $self->_gen_field_handler($field);# don't call 
	}

	return $self;
}

=item init_types

Initialise generic object attr based on table from db, returns relation names.

	my @rels = $o_obj->init_types(@rel_types);

=cut

sub init_types { # generic attr from db
	my $self  = shift;
	my @types = @_;
	my @rels  = ();
	
	$self->{'_relation'} = {}; # 
	foreach my $type (@types) { # float|from|to
		foreach my $targ ( $self->attr($type) ) { # patch change bug address user
			$self->{'_relation'}{$targ}{'type'} = $type;
			push(@rels, $targ);
		}
	}

	return @rels;
}

=item reinit 

Reset object to default values, with optional object_id where different, returns object

	$o_obj->reinit($oid);

To check whether the object was succesfully reinit, ask:

	my $i_isok = $o_obj->REINIT; # ?

=cut

sub reinit { 
	my $self = shift; 
	my $oid = shift || ''; #  || $self->oid;

	$self->CREATED(0);
	$self->READ(0);
	$self->UPDATED(0);
	$self->DELETED(0); 
	$self->STORED(0);
	$self->TRACKED(0);
	$self->REINIT(1);

	my @fields = $self->init_data($self->attr('table'));
	my $i_ok   = $self->check();
	my @types  = $self->attr('types');
	my @rels   = $self->init_types(@types);

	$self->attr( { 'objectid', $oid} ); # explicit	
	$self->data( { $self->attr('primary_key'), $oid} );

	$self->debug(3, "object($oid) reinit(".$self->attr('key').") types(@types) rels(@rels)") if $Perlbug::DEBUG;

	return $self;
}

=item refresh_relations

Refresh relation data, optionally restricted to only those given, others are cleared.

	$self->refresh_relations([\@wanted]);

=cut

sub refresh_relations {
	my $self = shift;
	my @args = my @rels = @_;
	my $obj  = $self->key;

	my $rellies = join('|', my @rellies = $self->rels);
	@rels = grep(/($rellies)/, @args);
	$self->debug(2, ref($self).": args(@args) rellies($rellies) => rels(@rels)") if $Perlbug::DEBUG;

	$self->{'_relation'} = {};	

	REL:
	foreach my $rel (@rels) {
		next REL if $rel =~ /^$obj$/i; # no recurse
		my @rids  = $self->rel_ids($rel, '', 'refresh');		# if ids	
		# my @names = $self->rel_names($rel, '', 'refresh');	# 
		my @names = $self->object($rel)->id2name(\@rids);		# if names
		$self->{'_relation'}{$rel}{'count'} =  @rids;	
		$self->{'_relation'}{$rel}{'ids'}   = \@rids; 
		$self->{'_relation'}{$rel}{'names'} = \@names;	
	}
	$self->debug(3, 'relations: '.Dumper($self->{'_relation'})) if $Perlbug::DEBUG;

	return $self;
}

=item check

Check all attr are initialised

	my $i_ok = $o_obj->check(\%attributes);

=cut

sub check {
	my $self  = shift;
	my $h_ref = shift || $self->_oref('attr');

	my $i_ok  = 1;

	CHECK:
	foreach my $key (keys %{$h_ref}) {
		unless ($key =~ /(debug|objectid)/io) {
			if ($$h_ref{$key} !~ /\w+/) {
				$i_ok = 0;
				$self->error(" is incomplete key($key) val($$h_ref{$key}): ".Dumper($h_ref));
			}
		}
	}

	return $i_ok;
}

=item REINIT 

Returns 0|1 depending on whether object has been reinit 

	my $i_isok = $o_obj->REINIT;

=cut

sub REINIT {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag('reinit', $1) if $i_flag =~ /^(1|0)$/o;	

	$i_flag = $self->flag('reinit');

	return $i_flag;	
}

=item exists

Examines the database to see if current object exists already.

Second optional parameter overrides sql caching

Return @ids

	print "yup\n" if $o_obj->exists([$oid]);

=cut

sub exists {
	my $self = shift;
	my $a_oids = shift || [ $self->oid ];
	my @IDS = ();

	if (ref($a_oids) ne 'ARRAY') {
		$self->error("requires array ref($a_oids) of oids!");
	} else {
		my $ids = join("', '", @{$a_oids});
		my $pri = $self->attr('primary_key');
		my $sql = "SELECT DISTINCT $pri FROM ".$self->attr('table'). 
				  # " WHERE $pri Like '_%' AND $pri IN ('$ids')"
				  " WHERE $pri IN ('$ids')"
		;
		@IDS = $self->base->get_list($sql);
	}

	return @IDS;
}

=item _exists

Examines the database to see if current object exists by B<identifier> already.

Second optional parameter overrides sql caching

	print "yup\n" if $o_obj->_exists(\@ids);

=cut

sub _exists {
	my $self = shift;
	my $a_ids = shift || [ $self->attr($self->identifier) ];
	my @IDS = ();

	if (ref($a_ids) ne 'ARRAY') {
		$self->error("requires array ref($a_ids) of ids!");
	} else {
		my $ids = join("', '", @{$a_ids});
		my $pri = $self->identifier;
		my $sql = "SELECT DISTINCT $pri FROM ".$self->attr('table'). 
				  # " WHERE $pri Like '_%' AND $pri IN ('$ids')"
				  " WHERE $pri IN ('$ids')"
		;
		@IDS = $self->base->get_list($sql);
	}

	return @IDS;
}

=item fields

Returns all valid data field names for this object

	my @fields = $o_obj->fields;

=cut

sub data_fields { my $self = shift; return $self->fields(@_); }

sub fields {
	my $self = shift;

	my @fields = keys %{$self->{'_data'}};

	return @fields;
}

=item str2ids

Return appropriate (B<match_oid>)s found in given string

	my @ids = $o_obj->str2ids($str);

=cut

sub str2ids {
	my $self = shift;
	my $str  = shift || '';
	my @ids  = ();

	if ($str !~	/\w+/) {
		$self->error("no string($str) given to inspect for ids!");
	} else {
		my $match = $self->attr('match_oid');
		# my %x = ($dmc =~ /\<(\w+)\>(\w+)?(?:)\<\/\1\>/gi)
		@ids = ($str =~ /$match/cgs);
		$self->debug(2, "str($str) match($match) -> ids(@ids)") if $Perlbug::DEBUG;
	}

	return @ids;
}

=item ok_ids 

Checks to see if given oid/s look anything like we are expecting them to.

Returns list of acceptable object ids

	my @ok_ids = $o_obj->ok_ids(\@some_ids);

=cut

sub ok_ids {
	my $self = shift;
	my $a_ids = shift || '';
	my @ok = ();

	if (!ref($a_ids) eq 'ARRAY') {
		$self->error("expecting array_ref($a_ids) of object ids!");
	} else {
		my $ids = join('|', my @ids = @{$a_ids});
		if (!(scalar(@ids) >= 1)) {
			$self->debug(2, "no ids(@ids) given") if $Perlbug::DEBUG;
		} else {
			my @wids = map { ($_ =~ /\w+/o ? $_ : ()) } @ids;  
			if (!(scalar(@wids))) {
				$self->debug(2, "no word-like ids(@wids) given(@ids)") if $Perlbug::DEBUG;
			} else {
				my $i_ids = @wids;
				my $match = $self->attr('match_oid');
				my $i_oks = @ok = map { ($_ =~ /^$match$/ ? $_ : ()) } @wids;  
				if ($i_ids != $i_oks) {
					$self->debug(2, $self->key()." failed to match($match) object ids! given: $i_ids(@wids) => ok_ids: $i_oks(@ok)") if $Perlbug::DEBUG; 
				}
			}
		}
	}

	return @ok;
}

=item primary_key 

Wrapper to only get primary_key.

	my $pri = $o_obj->primary_key;

=cut

sub primary_key {
	my $self = shift;
	
	my $pri = $self->attr('primary_key');

	return $pri;
}

=item key 

Wrapper to get and set key. 

	my $key = $o_obj->key($key);

=cut

sub key {
	my $self = shift;
	my $in = shift || '';
	
	if ($in =~ /\w+/o) {
		$self->attr({'key', $in}); # explicit	
	}

	my $key = $self->attr('key');

	return $key;
}

=item objectid 

Wrapper to get and set objectid, and data(<objectid>) at the same time. 

	my $oid = $o_obj->objectid($id);

=cut

sub objectid { my $self = shift; return $self->oid(@_); } # shortcut

sub oid {
	my $self = shift;
	my $in = shift || '';

	if ($self->ok_ids([$in])) { # are appropriate
		$self->attr( { 'objectid', $in } ); # explicit	
		$self->data( { $self->attr('primary_key'), $in } );
	}
	my $oid = $self->attr('objectid');

	return $oid;
}

=item id

Returns any ok_ids found in given data structure under B<id> or B<${obj}_id>

	my @ids = $o_obj->id({
		'id'	  => [(23, 44, 7)], 
		'testid'  => [(23, 44, 7)], 
		'testids' => [(23, 44, 7)], 
		'test_id' => [(23, 44, 7)],
	});

=cut

sub id {
	my $self  = shift;
	my $h_ref = shift; #$o_cgi
	my @ids   = ();

	if (!(ref($h_ref))) {
		$self->error("requires some sort of data ref($h_ref)!");
	} else {
		my $obj = $self->key;
		my @vars = ('id', $obj.'id', $obj.'_id', $obj.'_ids');
		foreach my $var (@vars) {
			if (ref($h_ref) eq 'CGI') {
				push(@ids, $h_ref->param($var)) if $h_ref->param($var);
			} else {
				if (ref($h_ref) eq 'ARRAY') {
					push(@ids, @{$h_ref}) if scalar(@{$h_ref}) >= 1;
				} else {
					if (ref($$h_ref{$var}) eq 'ARRAY') {
						push(@ids, @{$$h_ref{$var}}) if scalar(@{$$h_ref{$var}}) >= 1;
					} else {
						push(@ids, $$h_ref{$var}) if $$h_ref{$var} =~ /.+/o;
					}
				}
			}
		}
		$self->debug(3, "ok id(@ids)from: ".Dumper($h_ref)) if $Perlbug::DEBUG;
	} 

	return @ids;
}

=item ids

Gets DISTINCT ids, for this object

	my @all_ids  = $o_obj->ids(); 

Which is a bit like an unrestricted B<col($primary_key, '')> call.

More useful are the following examples, restrained by object, or sql WHERE statement:

	my @rel_ids  = $o_obj->ids($o_rel, [$further_restrained_by_sql], 'refresh');

	my @selected = $o_obj->ids($where);

=cut

sub ids {
	my $self  = shift;
	my $input = shift || '';
	my $extra = shift || '';
	my $refresh = shift || '';
	my @ids   = ();
	
	my $prime = $self->attr('primary_key');
	my $table = $self->attr('table');
	my $sql   = "SELECT DISTINCT $prime FROM $table ";

	if (ref($input)) {				# OBJECT with ids, etc.
		$sql .= " WHERE $prime = '".$input->oid()."'";		
		$sql .= " AND $extra" if $extra;
	} elsif ($input =~ /\w+/o) { 	# SQL where clause
		$input =~ s/^\s*WHERE\s*//io;	
		$sql  .= " WHERE $input";	
	} 								# ALL
	$sql .= " ORDER BY name " if $self->identifier eq 'name';
	
	@ids = $self->base->get_list($sql, $refresh);
	$self->debug(3, "input($input) extra($extra) -> ids(@ids)") if $Perlbug::DEBUG;

	return @ids;
}

=item names

Get DISTINCT names for this object.

If there is no ident=name, or no names, for the object, returns empty list().

For restraints/parameters see L<ids()>

	my @names = $o_obj->names();

=cut

sub names {
	my $self = shift;
	my $input = shift || '';
	my $extra = shift || '';
	my @names = ();
	
	my $ident = $self->identifier;
	if ($self->identifier eq 'name') {
		my $sql = "SELECT DISTINCT name FROM ".$self->attr('table');
		if (ref($input)) {				# OBJECT with ids, etc.
			$sql .= ' WHERE '.$input->attr('primary_key')." = '".$input->oid()."'";		
			$sql .= " AND $extra" if $extra;
		} elsif ($input =~ /\w+/o) { 	# SQL where clause
			$input =~ s/^\s*WHERE\s*//io;	
			$sql  .= " WHERE $input";	
		}
		@names = $self->base->get_list($sql);
	}								# ALL
	$self->debug(3, "input($input) extra($extra) -> names(@names)") if $Perlbug::DEBUG;

	return @names;
}

=item col 

Gets DISTINCT column, from all or with a where sql statement

	my @all_cols = $o_obj->cols('name');

	my @rel_cols = $o_obj->cols('name, $o_rel);

	my @selected = $o_obj->cols('name', $where);

=cut

sub col { 
	my $self = shift;
	my $col  = shift;
	my $input = shift || '';
	my @cols = ();
	
	if ($col !~ /\w+/) {
		$self->error("No column($col) given to retrieve!");
	} else {	
		my $sql = "SELECT DISTINCT $col FROM ".$self->attr('table');
		if (ref($input)) {				# OBJECT with ids, etc.
			$sql .= ' WHERE '.$input->attr('primary_key')." = '".$input->oid()."'";		
		} elsif ($input =~ /\w+/o) { 	# SQL where clause
			$input =~ s/^\s*WHERE\s*//io;	
			$sql  .= " WHERE $input";	
		} 		 						# ALL 
		@cols = $self->base->get_list($sql);
	}	

	$self->debug(3, "col($col), input($input) -> cols(@cols)") if $Perlbug::DEBUG;
	return @cols;
}

=item identifier

Return identifying string key for this object, 'name' or whatever

=cut

sub identifier {
	my $self = shift;
	
	my $ident = (grep(/^name$/i, $self->data_fields)) 
	# my $ident = (map { ($_ =~ /^name$/ ? 1 : 0) } $self->data_fields) 
		? 'name' 
		: $self->attr('primary_key');

	$self->debug(3, "ident($ident)") if $Perlbug::DEBUG;
	return $ident;
}

=item id2name 

Convert ids to names

	my @names = $o_obj->id2name(\@ids);

=cut

sub id2name {
	my $self    = shift;
	my $a_input = shift;
	my @output  = ();

	if (!ref($a_input)) {
		$self->debug(0, "no input ids given to convert($a_input)") if $Perlbug::DEBUG;
	} else {
		if ($self->identifier ne 'name') {
			$self->debug(3, "identifier ne 'name'!") if $Perlbug::DEBUG;
		} else {
			my @input = @{$a_input};
			if (scalar(@input) >= 1) {
				my $input = join("', '", @input);
				my $sql = 
					"SELECT DISTINCT name FROM ".$self->attr('table').
					" WHERE ".$self->attr('primary_key')." IN ('$input')";
				@output = $self->base->get_list($sql);
				$self->debug(3, "given(@input) -> sql($sql) -> output(@output)") if $Perlbug::DEBUG;
			}
		}
	}
	$self->debug(2, "given(@{$a_input}) output(@output)") if $Perlbug::DEBUG;

	return @output;
}

=item name2id

Convert names to ids 

	my @ids = $o_obj->name2id(\@names);

=cut

sub name2id {
	my $self = shift;
	my $a_input   = shift;
	my @output = ();
	if (!ref($a_input)) {
		$self->error("no input names given to convert($a_input)");
	} else {
		my @input = @{$a_input};
		if (scalar(@input) >= 1) {
			my $input = join("', '", @input);
			my $sql = 
				 "SELECT DISTINCT ".$self->attr('primary_key').
				  " FROM ".$self->attr('table')." WHERE ".$self->identifier." IN ('$input')";
			@output = $self->base->get_list($sql);
			$self->debug(3, "input(@input) -> sql($sql) -> output(@output)") if $Perlbug::DEBUG;
		}
	}
	return @output;
}

=item count

Return number of objects, optionally restrained by argument given

	my $i_cnt = $o_obj->count;

	my $i_cnt = $o_obj->count($o_rel); # uses o_rel(objectid) 

	my $i_cnt = $o_obj->count("$objectid Like '$criteria'");

=cut

sub count {
	my $self 	= shift;
	my $input = shift || '';
	my $extra = shift || '';

	my $i_cnt 	= 0;
	
	my $sql = "SELECT COUNT(".$self->attr('primary_key').") FROM ".$self->attr('table');
	if (ref($input)) {				# OBJECT with ids, etc.
		$sql .= ' WHERE '.$input->attr('primary_key')." = '".$input->oid()."'";		
		$sql .= " AND $extra" if $extra;
	} elsif ($input =~ /\w+/o) { 	# SQL where clause
		$input =~ s/^\s*WHERE\s*//io;	
		$sql  .= " WHERE $input";	
	} 								# ALL

	($i_cnt) = $self->base->get_list($sql);
	$self->debug(3, "input($input) extra($extra) -> i_cnt($i_cnt)") if $Perlbug::DEBUG;

	return $i_cnt;
}

=item trim

Return args trimmed of whitespace, ready for comparison checks

	my @trimmed = $o_obj->trim([qw(this and that)]);

=cut

sub trim {
	my $self = shift;
	my $a_in = shift;
	my @trimmed = ();

	if (!ref($a_in) eq 'ARRAY') {
		$self->error("expecting array_ref($a_in) to trim!");
	} else {
		foreach my $arg (@{$a_in}) {
			$arg =~ s/^\s+//o;
			$arg =~ s/\s+$//o;
			push(@trimmed, $arg);
		}
	}

	return @trimmed;
}


=item keys_sorted_by_value 

Return list of keys sorted by values

	my @sorted = $o_obj->keys_sorted_by_value(\%hash);

=cut

sub keys_sorted_by_value {
	my $self = shift;
	my $h_in = shift;

	my @sort = ();

	if (ref($h_in) ne 'HASH') {
		$self->error("expecting hash_ref($h_in) to sort!");
	} else {
		my %in = %{$h_in};
		foreach my $arg (sort { $in{$a} cmp $in{$b} } keys %in) {
			push(@sort, $arg);
		}
	}

	return @sort;
}

# HTTP specific methods
# -----------------------------------------------------------------------------

=item link

Return an href link to this object given optional ids, or search link if none given, (eg with a o_test object): 

	my $link = $o_obj->link($fmt, \@testids, $js); # bugcgi?req=test_id&test_id=37&format=h&etc.

=cut

sub link {
	my $self = shift;
	my $fmt  = shift || $self->base->current('format');
	my $aoid = shift || [];
	my $js   = shift || '';
	my $stat = (ref($aoid) eq 'ARRAY') ? join(', ', @{$aoid}) : '';
	
	my $targ = $self->key;

    my @link = $self->href($targ.'_id', $aoid, ucfirst($targ), $stat, $aoid, $js, $fmt);

	$self->debug(3, "targ($targ) oid($aoid) => link(@link)") if $Perlbug::DEBUG;

	return @link;
}

=item choice

Returns appropriate B<popup()> or B<selector()> for object, based on B<prejudicial> setting.

	print $o_obj->choice($unique_name, [$selected]); # or none('') 

=cut

sub choice {
	my $self = shift;

	my $choice = ($self->attr('prejudicial') == 1) ? 'popup' : 'selector';

	$self->debug(3, "choice($choice)...") if $Perlbug::DEBUG;

	return $self->$choice(@_);
}


=item popup 

Create scrolling web list popup with given pre-selection (or B<any>), with (alphabetically sorted) names where possible, and optional WHERE clause

	my $popup = $o_obj->popup('unique_name', $selected, [$where]); 

=cut

sub popup {
	my $self = shift;
	my $name = shift || $self->attr('name');
	my $sel  = shift || ''; # any?
	my $where= shift || ''; # sql
	($sel)   = @{$sel} if ref($sel) eq 'ARRAY';

	my $cgi  = $self->base->cgi;

	my %map = ('' => '',);
	%map = (%map, 'any' => 'any') if $sel eq 'any';
	my $pri = $self->attr('primary_key');
	# my $col = (grep(/^name$/i, $self->data_fields)) ? 'name' : $pri;
	my ($col) = map { ($_ =~ /^name$/o ? $_ : $pri ) } $self->data_fields ? 'name' : $pri;

	my @ids = $self->col("CONCAT($pri, ':', $col)", $where); 
	foreach my $id (@ids) {
		my ($pre, $post) = split(':', $id);
		$map{$pre} = $post;
	}

	my @sorted = $self->keys_sorted_by_value(\%map);

	# my $pointer = 'parent.perlbug.document.forms[0].';
	my $pop = $cgi->popup_menu(
		-'name' 	=> $name, 			# xxx_groupids
		-'values' 	=> \@sorted, # keys %map
		-'onChange'	=> 'pick(this);',
		-'default' 	=> $sel,	
		-'labels' 	=> \%map, 
		-'override' => 1,
		@_,
	);
	
	$self->debug(3, "name($name) selected($sel) pop($pop)") if $Perlbug::DEBUG;

	return $pop;
}

=item selector

Create scrolling web list selector with given pre-selections, with names where possible.  Also appends simple list of selected items.

	my $selctr = $o_obj->selector('unique_name', \@pre_selected);

=cut

sub selector {
	my $self = shift;
	my $name = shift || $self->attr('name');
	my @selected = @_;

	my $cgi  = $self->base->cgi;
	@selected = @{$selected[0]} if ref($selected[0]) eq 'ARRAY';

	my %map = ();
	my $pri = $self->attr('primary_key');
	# my $col = (grep(/^name$/i, $self->data_fields)) ? 'name' : $pri;
	my ($col) = map { ($_ =~ /^name$/o ? $_ : $pri ) } $self->data_fields ? 'name' : $pri;

	my @ids = $self->col("CONCAT($pri, ':', $col)"); 
	foreach my $id (@ids) {
		my ($pre, $post) = split(':', $id);
		$map{$pre} = $post;
	}

	my @sorted = $self->keys_sorted_by_value(\%map);

	my $sel  = $cgi->scrolling_list(
		-'name' 	=> $name, 			# xxx_groupids
		-'values' 	=> \@sorted, # keys %map
		-'default' 	=> \@selected,	
		-'labels' 	=> \%map, 
		-'multiple' => 'true', 
		-'size' 	=> 3, 
		-'override' => 1,
		-'onChange'	=> 'pick(this);',
		@_,
	).'<br>'.join(', ', map { $map{$_} } @selected);
	
	$self->debug(3, "name($name) selected(@selected) => sel($sel)") if $Perlbug::DEBUG;

	return $sel;
}


=item text_area 

Create text_area with given args, prep for select(js) 

	my $ta = $o_obj->text_area('unique_name', 'value', [etc.]);

=cut

sub text_area {
	my $self = shift;
	my $name = shift || $self->attr('name');
	my $val  = shift || '';

	($val)  = @{$val} if ref($val) eq 'ARRAY';
	my $cgi  = $self->base->cgi;

	my $txt  = $cgi->textarea(
		-'name' 	=> $name, 			# xxx_groupids
		-'value' 	=> $val,
		-'override' => 1,
		-'onChange'	=> 'pick(this);',
		-'rows'		=> 3,
		-'cols'		=> 25,
		@_, 							# etc. 
	);

	$self->debug(3, "name($name) val($val) => txta($txt)") if $Perlbug::DEBUG;

	return $txt;
}


=item text_field 

Create text_field with given args, prep for select(js) 

	my $tf = $o_obj->text_field('unique_name', 'value', [etc.]);

=cut

sub text_field {
	my $self = shift;
	my $name = shift || $self->attr('name');
	my $val  = shift || '';

	($val)  = @{$val} if ref($val) eq 'ARRAY';
	my $cgi  = $self->base->cgi;

	my $txt  = $cgi->textfield(
		-'name' 	=> $name, 			# xxx_groupids
		-'value' 	=> $val,
		-'override' => 1,
		-'onChange'	=> 'pick(this);',
		-'size'		=> 12,
		-'maxlength'=> 12,
		@_, 							# etc. 
	);

	$self->debug(3, "name($name) val($val) => txtf($txt)") if $Perlbug::DEBUG;

	return $txt;
}

=item htmlify

Returns args with select this object inserted, calls B<Format::htmlify>

	my \%data = $o_obj->htmlify(\%data);

=cut

sub htmlify {
	my $self   = shift;
	my $h_data = $self->SUPER::htmlify(@_);

	if (ref($h_data) ne 'HASH') {
		$self->error("requires hashed data ref($h_data)!");
	} else {
		my $obj = $self->key;
		my $oid = $self->oid;
		$$h_data{'select'} = $self->base->cgi->checkbox(
			-'name'		=>"${obj}id", 
			-'checked' 	=> '', 
			-'value'	=> $oid, 
			-'label' 	=> '', 
			-'override' => 1
		);

		my $OPTIONAL = $self->base->help_ref('optional', 'Optional');
		my $TRANSFER = $self->base->help_ref('transfer', 'Transfer');
		my $transfer = '<td>&nbsp;</td><td>&nbsp;</td>';
		if (grep(/^$obj$/, $self->base->objects('mail'))) {
			$transfer = qq|<td><b>$TRANSFER type:</b>&nbsp;</td>|.
				'<td>'.
				$self->object('object')->popup("${oid}_transfer", $obj, 
				"UPPER(type) = 'MAIL' 
				AND name IN('message', 'note', 'patch', 'test') AND NAME != '$obj'", 
				# -'onChange'	=> "pick(this); return newcoms('read');",
			) . '</td>';
		}
		$$h_data{'options'} = qq|
		<table border=0>
			<tr>$transfer</tr>
			<tr>
				<td><b>$OPTIONAL information here:</b>&nbsp;</td>
				<td><input type="text" name="${oid}_opts" value="" size="30" 
				onChange="return pick(this);"></td>
			</tr>
		</table>
		|;
	}

	$self->debug(3, "$h_data => <pre>\n".Dumper($h_data)."</pre>\n") if $Perlbug::DEBUG;

	return $h_data;
}

=item form 

Return a web form for this object

	print $o_obj->form($fmt);

=cut

sub form {
	my $self  = shift;
	my $o_cgi = shift; # ignored
	my $title = shift || 'form';
	my $obj   = $self->key;
	my $cgi   = $self->base->cgi;

	my $form = qq|<table border=1>\n|.
		q|<tr><th>&nbsp;</th><th><h3>|.ucfirst($obj).qq| $title</h3></th></tr>\n|;

	$self->reinit() unless $title =~ /^initial/io;

	my $h_data = $self->_oref('data');

	KEY:
	foreach my $key (sort keys %{$h_data}) {
		my $val = $$h_data{$key} || '';
		unless ($key eq 'userid') {
			if ($key =~ /^(created|modified|${obj}id)$/io) { 
				next KEY if $cgi->param('req') =~ /_initform$/io;
			}
		}
		$form .= qq|<tr><td><b>$key</b></td>|;
		if ($key =~ /body|header/io) {
			$form .= qq|<td><textarea name="$key" rows="3" cols="40">$val</textarea></td>|;
		} else {
			my $size = ($key =~ /(description|email_msgid|subject|(to|source)addr)/io) ? 'size="35"' : '';
			$form .= qq|<td><input type="text" name="$key" value="$val" $size></td>|;
		}
		$form .= qq|</tr>\n|;
	}

	$form .= qq|</table>\n|;

	$self->debug(3, "obj($obj) form($form)") if $Perlbug::DEBUG;

	return $form; 
}


=item search

Return a web search form for this object

	print $o_obj->search($fmt);

=cut

sub search {
	my $self = shift;
	my $o_cgi = shift; # ignored
	my $obj  = $self->key;
	my $cgi  = $self->base->cgi;

	my $form = $self->form($cgi, 'search');

	my $FMT		 = $self->base->help_ref('format', 'Formatter');
	my $SHOWSQL  = $self->base->help_ref('show_sql', 'Show SQL');
	my $RESTRICT = $self->base->help_ref('restrict', 'Restrict returns to');
    my %format   = ( 'h' => 'Html list', 'H' => 'Html block', 'L' => 'Html lean', 'a' => 'Ascii list', 'A' => 'Ascii block', 'l' => 'Ascii lean',); 
	my $format   = $cgi->radio_group(-'name' => 'format',  -values => \%format, -'default' => 'h', -'override' => 1);
    my $sqlshow  = $cgi->radio_group(-'name' => 'sqlshow',	-'values' => ['Yes', 'No'], -'default' => 'No', -'override' => 1);
    my $restrict = $cgi->popup_menu(-'name' => 'trim',      -'values' => ['All', '5', '10', '25', '50', '100'],  -'default' => 10, -'override' => 1);

	$form .= qq|
		<table border=0>
		<tr><td>$FMT:     	</td><td>$format</td></tr> 
		<tr><td>$SHOWSQL: 	</td><td>$sqlshow</td></tr> 
		<tr><td>$RESTRICT:	</td><td>$restrict</td></tr> 
		</table>\n
		<input type=hidden name=req value="${obj}_query">\n
	|;

	$self->debug(3, "obj($obj) form($form)") if $Perlbug::DEBUG;

	return $form;
}

=item initform

Return an web based object initialisation form.

	my $nix = $o_obj->initform(); # N.B. <-- actually prints the form!

=cut

sub initform {
	my $self  = shift;
	my $o_cgi = shift; # ignored
	my $obj   = $self->key;
	my $cgi   = $self->base->cgi;

	$self->reinit;
	$self->data(
		$self->minimal_create_info({})	
	);

	my $form = $self->form($cgi, 'initialisation');

	my $optional = $self->base->help_ref('optional', 'Optional');
	$form .= qq|<hr>
		<b>$optional information here:</b>&nbsp;<input type="text" name="opts" value="" size="30">
	<hr>| if $self->isarel('bug'); # group (users)
	$form .= qq|
		<input type=hidden name=req value="${obj}_create">\n
		<input type=hidden name=format value="H">\n
		|;
=pod
	assign to rels...
	$form .= qq|
		<table border=0>
		<tr><td>$FMT:     	</td><td>$format</td></tr> 
		<tr><td>$SHOWSQL: 	</td><td>$sqlshow</td></tr> 
		<tr><td>$RESTRICT:	</td><td>$restrict</td></tr> 
		</ table>\n
		<input type=hidden name=req value="${obj}_query">\n
	|;
=cut
	$self->debug(3, "obj($obj) form($form)") if $Perlbug::DEBUG;

	print $form; # <- !!!

	return (); 
}

# =============================================================================

=item _gen_field_handler

Generate code to handle get and set object fields, returns 1|0

	my $i_ok = $o_obj->_gen_field_handler('header');

	my $var = $o_obj->header($msg); # var has msg

=cut

sub x_gen_field_handler { # AUTOLOAD'd
    my $self  = shift;
    my $field = shift;
    # if (!(grep(/^$field$/, $self->data_fields))) { 
	if (map { ($_ =~ /^name$/o ? 1 : 0) } $self->data_fields) { 
		$self->error("can't gen_field_handler($field)!");
    } else {
		my $ref = ref($self);
		$self->debug(3, "setting($ref) field($field) handler...") if $Perlbug::DEBUG;
		my $code = qq|
			package $ref;
			sub $field {
				my \$self = shift;
				my \$val  = shift;
				if (defined(\$val)) {
					\$self->{'_data'}{'$field'} = \$val;
				}
				
				my \$ret = \$self->{'_data'}{'$field'};
				# print "returning $field data(\$ret) setting? val(\$val)\n";

				return \$ret;
			}		
		|;
		my $x = eval { $code }; 
		$self->error("Couldn't eval the($ref) field($field) handler: $@") if ($@);
    }
    $self;
}

=item base

Return application specific Perlbug::Base object, given as $o_obj->new($o_base) or new object altogether. 

=cut

{ $^W=0; eval ' 
sub base {
	my $self = shift;

	$o_Perlbug_Base = ref($o_Perlbug_Base) ? $o_Perlbug_Base : Perlbug::Base->new(@_);

	return $o_Perlbug_Base; 
} 
'; }

{ $^W=0; eval ' 
sub db {
	my $self = shift;

	return $self->base->db;
} 
'; }

=item _oref

Unsupported method to retrieve hash ref of requested type

	my $h_ref = $o_obj->_oref('attr');

=cut

sub _oref { # unsupported 
	my $self  = shift;
	my $key   = shift;
	my $h_ref = ''; # !

	my @refs = keys %{$self};
	# if (!grep(/^_$key$/, @refs)) { # sneaky :-]
	if (!(map { ($_ =~ /^_$key$/ ? 1 : 0) } @refs)) {
		$self->error("unknown key($key) requested! valid keys(@refs)");	
	} else {
		$h_ref = { %{$self->{"_$key"}} }; # copy
	}

	$self->debug(3, "key($key) => href: ".Dumper($h_ref)) if $Perlbug::DEBUG;
	
	return $h_ref;
}

=pod

=back


# 
# ===============================================================================

=head1 RELATIONS

Object relations are handled by a group of methods:

	my @rellies 	= $o_obj->relations('to');	# patch, message, note, test, user, 

	my $o_patch     = $o_obj->relation('patch');	# handler

	my @pids	= $o_patch->ids($o_obj);	# or

	my @pids     	= $o_obj->relation_ids('patch');# ids

Note that relations are between one object and (from or to) another, or of a 'floating' kind.

If it's another object you want, see L<"object()">.

=cut

=over 4

=item relation_types

Return relation types for current object

	my @types = $self->relation_types; # from, to

=cut

sub relation_types { my $self = shift; return $self->rel_types(@_); } # wrapper for rel_types()

sub rel_types {
	my $self = shift;
	return $self->attr('types');
}


=item isarel

Returns 1|0 dependant on whether relation($rel), is of given type (or any), or not

	print "yup\n" if $o_obj->isarel($rel);

eg:

	print "patch is related to a bug\n" if $o_pat->isarel('bug');

=cut

sub isarel {
	my $self = shift;
	my $rel  = shift;
	my $type = lc(shift) || '';

	# my $isa  = (grep(/^$rel$/, $self->rels($type))) ? 1 : 0;
	my $isa = map { ($_ =~ /^$rel$/ ? 1 : 0) } $self->rels($type);

	return $isa;
}


=item relations

Return relations, filtered by arg, or all if none given

	my @rellies = $self->relations('from'); # patch, user, etc.

=cut

sub relations { my $self = shift; return $self->rels(@_); } # wrapper for rels()

sub rels { 
	my $self = shift;
	my $type = shift || ''; # float|from|to
	my @rels = ();
	if (defined($type) && $type =~ /\w+/o) {
		@rels = $self->attr($type); 
	} else {	
		@rels = map { $self->attr($_) } $self->rel_types;
	}
	$self->debug(3, "type($type) => rels(@rels)") if $Perlbug::DEBUG;

	return @rels;
}


=item relation

Return object handler for given relation

	my $o_b2p = $o_bug->relation('patch');

	print $o_b2p->assign(\@list_new_patch_ids_2_bug);

If the original (in this case B<bug>) object had already an B<oid()> assigned, (it knew which bug it represented), the relation will be pre-initialised with the relevant bugid, by for example a L<read()> call.  Note, however, that where the sourceid is unknown, then only a B<generic> relationship object is returned.  eg; this should explicitly work:

	print $o_bug->read('19870502.007')->relation('patch')->assign(\@pids);

Note that the B<read()> method takes a single liberty, in that it calls L<Perlbug::Relation::set_source()> on the retrieved relation, thus ensuring said relation knows which object, (of the two that it holds) to regard as source. 

See L<Perlbug::Relation> for more info on relation methods.

=cut

sub relation { my $self = shift; return $self->rel(@_); } # wrapper for rel()

sub rel {
	my $self = shift;
	my $rel  = shift;
	my $o_rel = undef;
	if (!(defined($rel))) { 
		$self->error("No relation($rel) given to handle");
	} else {
		# if (!(grep(/^$rel$/, $self->relations))) {
		$rel =~ s/^.+?\W(\w+)$/$1/;
		if (!(map { ($_ =~ /^$rel$/ ? 1 : 0) } $self->rels)) { 
			$self->error("inappropriate relation($rel) requested from ".ref($self));
		} else {
			my $type = $self->{'_relation'}{$rel}{'type'};
			$o_rel  = $self->base->object($self->key.'->'.$rel, '', $type);
			my $oid = $self->oid;
			$o_rel->set_source($self->key, $self->oid);
			my $rid = $o_rel->oid;
		}
	}	
	$self->debug(3, "rjsf: Object::relation($rel): ".ref($self)." own_key(".$self->attr('key').") rel($rel) rel_key(".$o_rel->attr('key')." o_rel($o_rel)") if $Perlbug::DEBUG;
	return $o_rel;
}


=item relation_ids

Return relation IDs for given object

	my @patch_ids = $o_obj->relation_ids('patch');

=cut

sub relation_ids { my $self = shift; return $self->rel_ids(@_); } # wrapper for rel_ids()

sub rel_ids { # object 
	my $self = shift;
	my $rel  = shift;
	my $args = shift || '';
	my $refresh = shift || '';
	
	my @ids  = ();
	if (!defined($rel)) { 
		$self->error("Unable to get ids for non-existent ".ref($self)." relation($rel)");
	} else {
		my @rellies = $self->rels;
		# if (!(grep(/^$rel$/, @rellies))) {
		if (!(map { ($_ =~ /^$rel$/ ? 1 : 0) } $self->rels)) { 
			$self->error("inappropriate relation($rel) given for rel_ids from ".ref($self)." object ok(@rellies)");
		} else {
			my $o_rel = $self->relation($rel);
			@ids = $o_rel->ids($self, $args, $refresh);
			$self->debug(3, "rel($rel) args($args) -> ids(".@ids.')') if $Perlbug::DEBUG;
		}
	}	
	return @ids;
}


=item _rel_ids

Refresh rel_ids

=cut

sub _rel_ids { my $self = shift; return $self->rel(@_, 'refresh'); } # wrapper for rel_ids()


=item relation_names

Return relation names for given object, or empty list() if no names, or not ident=name

	my @os_names = $o_obj->relation_names('osname');

=cut

sub relation_names { my $self = shift; return $self->rel_names(@_); } # wrapper for rel_names()

sub rel_names { # object 
	my $self = shift;
	my $rel  = shift;
	my $args = shift || '';

	my @names = ();

	my @ids = $self->rel_ids($rel, $args);
	if (scalar(@ids) >= 1) {
		@names = $self->object($rel)->id2name(\@ids) if @ids;
	}
	
	# $self->debug(3, "rel($rel), args($args) -> ids(@ids), names(@names)") if $Perlbug::DEBUG;
	return @names;
}

=item relate

Work through the given hash using the objects' B<relations()>:

	B<assign()>ing any relation-ids found

	B<_assign()>ing any relation-names found

Prejudicial against $o_rel->attr('prejudicial') relationships, and 
is designed to take the output of B<Perlbug::Base::parse_str()>.

Returns name of objects assigned to.

	my $i_rels = my @rels = $o_obj->relate(\%relationships);

	where B<%relationships> = (
		'address'	=> {
			'ids'	=> [qw(7 223 78 26 13)],
		},
		'address'	=> {
			'names'	=> [qw(me@home.net buggy@system.com etc@the.net)],
		},
		'bug'		=> {
			'ids'	=> [qw(19870502.007)],
		},
		'group'		=> {
			'ids'	=> [qw()],
		},
		'osname'	=> {
			'ids'	=> [qw(3 7 21 23)],
			'names'		=> [qw(aix irix macos win32)],
		},
		'status'	=> {
			'names'	=> [qw(open)],	
		},
		'version'	=> {
			'ids'	=> [qw(4 28 273)],
			'names'	=> [qw(5.7.3)],
		},
	); 

See also L<parse_str()> and L<rtrack()>

=cut

sub relate {
	my $self    = shift;
	my $h_ships = shift;
	my @rels    = ();

	if (ref($h_ships) ne 'HASH') {
		$self->debug(0, "requires relationships: ".Dumper($h_ships)) if $Perlbug::DEBUG;
	} else {
		my $oid = $self->oid;
		if ($oid !~ /\w+/) {
			$self->error("$self has no object id($oid) to relate with!");
		} else {
			my $obj = $self->key;
			if ($obj eq 'bug') {
				unless (ref($$h_ships{'status'}{'names'}) eq 'ARRAY') {
					my $i_has_status = $self->rel_ids('status');
					$$h_ships{'status'}{'names'} = ['open'] unless $i_has_status;
				}
			}
			my %track = ();
			$self->debug(1, 'oid: '.$self->oid.' relatable: '.Dumper($h_ships)) if $Perlbug::DEBUG;
			RELATE:
			foreach my $rel ($self->rels) {
				next RELATE unless $rel =~ /\w+/o;
				my $prej  = ($self->object($rel)->attr('prejudicial') == 1) ? 1 : 0;
				my $o_rel = $self->rel($rel);
				my $a_ids = $$h_ships{$rel}{'ids'} || [];
				my $call  = $prej ? 'store' : 'assign';
				if (ref($$h_ships{$rel}{'ids'})) {
					$o_rel->$call($a_ids);
					$track{$rel}{'ids'} = $o_rel->ASSIGNED.' <= ('.join(', ', @{$a_ids}).')';
				} 
				my $a_names = $$h_ships{$rel}{'names'} || [];
				if (ref($$h_ships{$rel}{'names'})) { 
					my $call  = $prej ? '_store' : '_assign';
					$o_rel->$call($a_names);
					$track{$rel}{'names'} = $o_rel->ASSIGNED.' <= ('.join(', ', @{$a_names}).')';
				}
				if (ref($track{$rel})) {
					push(@rels, $rel) if keys %{$track{$rel}} >= 1;
				}	
			}
			$self->debug(1, 'oid('.$self->oid.') related: '.Dumper(\%track)) if $Perlbug::DEBUG;
			$self->rtrack(\%track);
		}
	}

	return @rels;
}

=item appropriate

Attempts to relate relatable bug relations to relevant bugs :-)

The idea is that a test can call B<appropriate()> after a B<relate()>, 
and this will apply appropriate status flags to any bugids found, etc.

See L</relate()> for more info.

	my @bugids = $o_obj->appropriate(\%rels);

=cut

sub appropriate {
	my $self    = shift;
	my $h_ships = shift;
	my @bugids  = ();

	if (ref($h_ships) ne 'HASH') {
		$self->debug(0, "requires relationships: ".Dumper($h_ships)) if $Perlbug::DEBUG;
	} else {
		@bugids   = (ref($$h_ships{'bug'}{'ids'}) eq 'ARRAY') 
			? @{$$h_ships{'bug'}{'ids'}}
			: ();
		if (scalar(@bugids) >= 1) {
			my $o_bug = $self->object('bug');
			foreach my $bugid (@bugids) {
				$o_bug->read($bugid)->relate($h_ships);
			}
		}
	}

	return @bugids;
}

=back

# =============================================================================

=head1 RECORDS

Record handling methods for L<Perlbug::Object::\w+>'s

=over 4

=item read 

Read the data, from the db, by id, and load into current object.

After this it is possible to get to meaningful relations via L<rel_ids()>, and correct L<format()>ing

Returns object so it is possible to chain calls.

	$o_obj->read($id);

And...

	print $o_obj->read($id)->format('h'); # etc.

To check whether the object was succesfully read, ask:

	my $i_isok = $o_obj->READ; 

=cut

sub read {
	my $self = shift;
	my $oid = shift || $self->oid;

	$self->reinit(''); # always want a fresh one
	if ($self->ok_ids([$oid]) != 1) {
		$self->debug(0, "$self requires a valid id($oid) to read against!") if $Perlbug::DEBUG;
	} else {
		my $pri	  = $self->attr('primary_key');
		my $table = $self->attr('table');
		my $sql = "SELECT * FROM $table WHERE $pri = '$oid'"; # SQL
		my ($h_data) = $self->base->get_data($sql);
		$h_data = '' unless $h_data;
		if (ref($h_data) ne 'HASH') {
			$self->debug(0, "failed to retrieve data($h_data) with $pri = '$oid' in table($table)") if $Perlbug::DEBUG;
		} else {
			$self->debug(2, $self->key." oid($oid)") if $Perlbug::DEBUG;
			# $DB::single=2;
			my $res = $self->data($h_data); 			# set
			my $xoid = $self->oid($oid);				# set
			# $self = $self->object($self->attr('key'), $self); # cache
			$self->READ(1) if $self->exists([$oid]); 	# catchy :)
		}
	}
	# print "Object::read($oid)...<pre>".Dumper($self)."</pre>\n";

	$self;
} 

=item READ 

Returns 0|1 depending on whether object has had a successful read, post new/init/reinit

	my $i_isok = $o_obj->READ;

=cut

sub READ {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'read', $1}) if $i_flag =~ /^(1|0)$/o;

	$i_flag = $self->flag('read');

	return $i_flag;	
}

=item _read

Wrap B<read()> call to operate by name (if possible)

	print $o_obj->_read($name)->format('h'); # etc.

=cut

sub _read {
	my $self = shift;
	my $name = shift || $self->data('name');

	my ($oid) = $self->name2id([$name]);

	return $self->read($oid);
}

=item column_type

Return sql type for given column name 

	my $datetime = $o_obj->column_type('created'); # DATETIME

	my $integer  = $o_obj->column_type('created'); # INTEGER 

	my $varchar  = $o_obj->column_type('created'); # VARCHAR <default>

=cut

sub column_type {
	my $self = shift;
	my $col  = lc(shift || '');
	my $type = 'VARCHAR';

	if (!($col =~ /^\w+$/o && grep(/^$col$/, keys %{$self->{'_type'}}))) {
		$self->error("can't define type for unrecognised column($col)");
	} else {
		$type = $self->{'_type'}{$col};
	}

	return $type;	
}

=item to_date

Currently redundant, because Mysql takes care of this, but Oracle may want to do more than this...

	my $sql_date = $o_obj->to_date($date_string);

=cut

sub to_date {
	my $self = shift || '';
	return "'@_'";
}

=item prep 

Quote (or not) given data, ready to go into our table

	my $sql = $o_obj->prep('insert', $h_data); # or 'update'

=cut

sub prep {
	my $self = shift;
	my $control = uc(shift || '');
	my $h_data	= shift; 
	my $table 	= $self->attr('table');
	my $sql = '';
	
	if (ref($h_data) ne 'HASH') {
		$self->error("can't prep non-existing data hash ref($h_data)");
	} else {
		my $do = (($control eq 'INSERT') ? 'INSERT INTO' : 'UPDATE');
		my @args = (); 
		foreach my $key (keys %{$h_data}) {
			my $type = $self->column_type($key); # def = (VARCHAR|BLOB)
			my $val = $$h_data{$key};
			$self->debug(3, "key($key) type($type) val(".length($val).")") if $Perlbug::DEBUG;
			# $val =~ s/^\s+//o;		# front
			# $val =~ s/\s+$//o;		# back
			my $data = '';
			if ($type eq 'DATETIME') {
				$data = "$key = SYSDATE()";
				if (!($key =~ /modified/io || ($key =~ /created/io && $control eq 'INSERT'))) {
					$data = "$key = ".$self->to_date($val);
				}
			} elsif ($type eq 'INTEGER')  {
				$data = "$key = '$val'";
			} else { # default and handles all strings, requoting!
				$data = "$key = '".$self->base->db->quote($val)."'";
			}
			unless ($key =~ /^(header|body)$/i) {
				$self->debug(3, "Type($type) key($key) val($val) => data($data)") if $Perlbug::DEBUG;
			}
			push(@args, $data) if $data;
		}
		$sql = "$do $table SET ".join(', ', @args).(' ' x rand(10));
		$self->debug(2, "sql($sql)") if $Perlbug::DEBUG;
	}

	return $sql;
}

=item massage

Massage given o_cgi data into a form appropriate for B<query>, B<update> or B<create()> usage 

Returns B<only> object data specific reference!

	my $h_data = $o_obj->massage(\%query);

=cut

sub massage {
	my $self  = shift;
	my $o_cgi = shift;
	my $oid   = shift || '';
	my $obj   = $self->key;
	my %ret   = ();

	if (!(ref($o_cgi))) {
		$self->error("$obj requires cgi obj($o_cgi) to massage!");
	} else {
		$self->debug(2, "given: ".Dumper($o_cgi)) if $Perlbug::DEBUG;
		my $objid = $obj.'id';
		$ret{$objid} = [$self->id($o_cgi)];
		
		foreach my $key ($self->fields, '_opts') {
			my $oid_key = $oid.'_'.$key;
			my $val = $o_cgi->param($key) || $o_cgi->param($oid_key) || '';
			if ($val =~ /(.+)/) {
				if ($key =~ /^(created|modified)$/) {	
					$val = "TO_DATE($val)";
				}
				$ret{$key} = $val unless $ret{$val};
			}
		}
		$self->debug(2, "massaged: ".Dumper(\%ret)) if $Perlbug::DEBUG;

		if ($o_cgi->param('req') =~ /_create$/) {
			%ret = %{$self->minimal_create_info(\%ret)};
		}
	} 

	return \%ret;
}

=item minimal_create_info

Pad out data for new object creation, only B<adds> to data if nothing found.

	my $h_out = $o_obj->minimal_create_info(\%in);

=cut

sub minimal_create_info {
	my $self   = shift;
	my $h_data = shift;
	my %ret    = ();

	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires hash ref($h_data) minimally!");
	} else {
		$self->debug(2, "mci given: ".Dumper($h_data)) if $Perlbug::DEBUG;
		my $admin = $self->base->isadmin;
		if ($admin !~ /\w+/) {
			$self->error("shouldn't get here?"); # web create only for admins
		} else {
			%ret = %{$h_data};
			my $o_usr = $self->base->object('user')->read($admin);

			my $obj = $self->key;
			my $oid = $obj.'id';
			$ret{$oid} = $self->new_id($self->id($h_data)); # unless $ret{$oid} =~ /\w+/o;

			my $msgid	= $ret{'email_msgid'} 	|| $self->base->get_rand_msgid;
			my $from 	= $ret{'sourceaddr'} 	|| $o_usr->data('address');
			my ($to) 	= $ret{'toaddr'} 		|| $self->base->target('generic'); 
			my $subject	= $ret{'subject'}		|| 'no subject given'; 

			$ret{'header'} = qq|
				From: $from
				To: $to
				Message-ID: $msgid
				Subject: $subject

			|; $ret{'header'} =~ s/^\s+//gmos;
			$ret{'subject'} 	= $subject;
			$ret{'email_msgid'}	= $msgid;
			$ret{'sourceaddr'} 	= $from;
			$ret{'toaddr'}	= $to;
		}
		$self->debug(2, "mci return: ".Dumper(\%ret)) if $Perlbug::DEBUG;
	}

	return \%ret;
}


=item query

Setup and execute sensible SQL, returning ids found, from given h_data for relevant object fields.

	my @ids = $o_obj->query(\%query);

=cut

sub query {
	my $self   = shift;
	my $h_data = shift;
	my $cgi    = $self->base->cgi;
	my @ids    = ();

	if (ref($h_data) ne 'HASH') {
		$self->error("requires data hash ref($h_data) to query!");
	} else {
		my @sql = ();
		foreach my $key (sort $self->fields) {
			my $param = $$h_data{$key} || '';
			if (ref($param) eq 'ARRAY') {
				if (scalar(@{$param}) >= 1) {
					my $params = join("', '", @{$param});
					push(@sql, "$key IN ('$params')")
				}
			} elsif ($param =~ /(.+)/) {
				$param = "'$1'";
				my $cmp = $self->db->comp($param);
				if ($key =~ /^(created|modified)$/) {	
					$key = "TO_DAYS($key)";
					$cmp = '>='; 
					$param = "TO_DAYS($param)"; # nice and open via mysql
					# TO_DAYS(modified) >= TO_DAYS('TO_DATE(2001-01-10)')
				}
				push(@sql, "$key $cmp $param");
			}
		}
		my $sql = join(' AND ', @sql);
		$sql =~ s/\*/\%/g;
		my $sqls = $cgi->param('sqlshow') || '0';
		my $trim = $cgi->param('trim') || '25';
		if ($sqls eq 'Yes') {
			print "SQL(".$self->key."): $sql<hr>";
		}
		@ids = $self->ids($sql);
		$self->debug(1, "sql($sql) trim($trim) ids: ".@ids) if $Perlbug::DEBUG;
		if (!(scalar(@ids) >= 1)) {
			print 'no '.$self->key.' ids found<hr>';
		} else {
			print 'found '.@ids.' '.$self->key." ids with trim factor($trim)<hr>";
			my $o_rng = $self->object('range');
			$o_rng->create({
				'name'		=> $self->key,
				'rangeid'	=> $o_rng->new_id,
				'processid'	=> $$,
				'range'		=> $o_rng->rangeify(\@ids),
				# $o_rng->relation('bug')->assign(\@bids); # ouch!
			});
			$#ids = ($trim - 1) if scalar(@ids) > $trim;
			$self->base->{'_range'} = $o_rng->oid if $o_rng->CREATED; 
		}
	} 

	return @ids;
}

=item create

Creates a new system object via inserting the given data into the db, loaded from current object, or given data.

Returns $o_object->read($id).

	$o_obj->create(); 		# using object data

	$o_obj->create($h_data);	# using given data, note B<only> this data is used!

	$o_obj->create($h_data, 'relation');	# ignore exists call

N.B. caller must set up the appropriate objectid (\d+|<bugid>|NULL|Sequence|...) previously.

To check whether the object was succesfully created, ask:

	my $i_isok = $o_obj->CREATED; #

=cut

sub create {
	my $self = shift;
	my $h_data = shift || $self->_oref('data');
	my $flag   = shift || ''; # anything
	my $sqlclean = shift || '1';
	my ($table, $pri) = ($self->attr('table'), $self->attr('primary_key'));

	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires data hash ref($h_data) to store object data!");
	} else {
		my $oid = $$h_data{$pri} || '';
		if ($oid !~ /\w+/) {
			$self->error("requires an objectid($oid) to create record: ".Dumper($h_data));
		} else {
			if ($flag eq '' && $oid ne 'NULL' && $self->exists([$oid])) {	# relations (clunky) ...
				$self->error("can't create already existing $pri($oid) in $table");
			} else {					# INSERT
				$self->data($h_data);
				my $sql = $self->prep('insert', $self->_oref('data'));
				my $sth = $self->base->exec($sql);	# DOIT
				if (!$sth) {
					$self->error("Failed($oid) to create sql($sql)!");
				} else {	
					$oid = $self->insertid($sth, $oid); # 
					$self->debug(2, "sql($sql) -> insertid($oid)") if $Perlbug::DEBUG;
					if (!$oid) {
						$self->error("Failed to fetch new oid($oid) from sql($sql)");
					} else {
						$self->CREATED(1);
						$oid = $self->oid($oid); # if $oid =~ /\w+/ && $oid !~ '0';
						# $self->track($sql." -> oid($oid)"); rjsf !
					}
					$self->base->clean_cache('sql', 'force');
				}
			}
		}
	}

	return $self;
}

sub _create {
	my $self = shift;

	$self->attr('clean_sql', 0);
	$self->create(@_);
	$self->attr('clean_sql', 1);

	return $self;
}


=item CREATED 

Returns 0|1 depending on whether object has been succesfully created 

	my $i_isok = $o_obj->CREATED;

=cut

sub CREATED {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'created', $1}) if $i_flag =~ /^(1|0)$/o;

	$i_flag = $self->flag('created');

	return $i_flag;	
}



=item store

Stores the given data into the db, (creates new data record), loaded from current object, or given data.

Executes an B<insert()> or B<update()> dependent on whether the object pre-exists or not.

For more info see L<create()> and L<update()>.  

Returns $o_object->read($id). 

	$o_obj->store(); 		# using object data

	$o_obj->store($h_data);	# using given data, note B<only> this data is used!

To check whether the object was succesfully stored, ask:

	my $i_isok = $o_obj->STORED; # ?

=cut

sub store { # by id from hashref
	my $self = shift;
	my $h_data = shift || $self->_oref('data');
	my ($table, $pri) = ($self->attr('table'), $self->attr('primary_key'));

	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires data hash ref($h_data) to store object data!");
	} else {
		my $oid = $$h_data{$pri} || '';
		my $call = ($self->exists([$oid])) ? 'update' : 'create';
		$self = $self->$call($h_data);
		if (ref($self)) {
			$self->STORED(1);
		}
	}

	return $self;
}


=item STORED 

Returns 0|1 depending on whether object has been succesfully stored

	my $i_isok = $o_obj->STORED;

=cut

sub STORED {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'stored', $1}) if $i_flag =~ /^(1|0)$/o;

	$i_flag = $self->flag('stored');

	return $i_flag;	
}

=item transfer 

Transfer the data to another object (type)

	my $new_oid = $o_obj->transfer(\%data, $oid);

=cut

sub transfer { # webtransfer
	my $self   = shift;
	my $h_data = shift;
	my $oid    = shift;
	my $cgi    = $self->base->cgi;
	
	unless ($self->read($oid)->READ) {
		$self->error("can't read oid($oid) for transfer!");
	} else {
		my $transferid = $cgi->param($oid.'_transfer') || '';
		if ($transferid !~ /\w+/) {
			$self->error("require a transferid($transferid) for target object type!");
		} else { 
			my ($targ) = $self->object('object')->col('name', "objectid = '$transferid'"); 
			my $o_tgt = $self->object($targ);
			my $s_data = $self->_oref('data');
			my $pri = $o_tgt->attr('primary_key'); 
			$$s_data{$pri} = $o_tgt->new_id;
			my $i_created = $o_tgt->create($s_data)->CREATED; 
			if ($i_created != 1) {
				$self->error("failed to transfer oid($oid) data from ".ref($self)." -> to($targ)"); 
			} else {
				my $targoid = $o_tgt->oid;
				$self->debug(0, 'transferred '.ref($self)."($oid) -> target($targ) oid($targoid)") if $Perlbug::DEBUG;
				# my $t_ref = $self->href($targ.'_id', [$targoid], $targoid, 'click ', '', "return go('${targ}_id&${targ}_id=$targoid&commands=write');");
				my $t_ref = $self->href($targ.'_id', [$targoid], $targoid, 'click ', '', "return go('${targ}_id&${targ}_id=$targoid');");
				print "<h3>New $targ: $t_ref</h3>\n";
				my $opts = $cgi->param($oid.'_opts') || $cgi->param('_opts') || '';
				my $pars = join(' ', $opts);
				my %update = $self->base->parse_str($pars);
				# scan subject, etc.?

				my @curr = ();
				REL:
				foreach my $rel ($self->rels) {
					my @extant = $self->rel_ids($rel);
					$self->rel($rel)->delete([$oid]);
					next REL unless grep(/^$rel$/, $o_tgt->rels);
					push(@{$update{$rel}{'ids'}}, join(' ', @extant));
				}
				$o_tgt->relate(\%update);
				my $i_deleted = $self->delete([$self->oid]); # !
			}
		}
	}

	return ();
}

=item webupdate

Update object via web interface, accepts relations via param('_opts')

Generically does B<not> update object data itself.

	$oid = $o_obj->webupdate(\%cgidata, $oid);

=cut

sub webupdate {
	my $self   = shift;
	my $h_data = shift;
	my $oid    = shift;
    my $cgi    = shift || $self->base->cgi();

	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires data hash ref($h_data) to update ".ref($self)." data via the web!");
	} else {
		if ($self->read($oid)->READ) {
			$self->debug(0, "oid: ".$self->oid) if $Perlbug::DEBUG;
			# my $pri = $self->attr('primary_key'); 
			# $$h_data{$pri} = $oid;
			# my $i_updated = $self->update($h_data)->UPDATED; # called separately
			# if ($i_updated == 1) {
				my $opts = $cgi->param($oid.'_opts') || $cgi->param('_opts') || '';
				my @curr = ();
				REL:
				foreach my $rel ($self->rels) {
					my @idents = ($self->object($rel)->identifier eq 'name') 
						? $self->id2name([$self->rel_ids($rel)]) 
						: $self->rel_ids($rel);
					push(@curr, join(' ', @idents));
					$self->debug(0, ref($self)."($oid) rel($rel) -> idents(@idents)") if $Perlbug::DEBUG;
				}
				my $pars = join(' ', $opts, @curr);
				my %cmds = $self->base->parse_str($pars);
				$self->relate(\%cmds);
			# }
		}
	}
	
	return $oid;
}

=item update

Update the given data into the db, loaded from current object, or given data.

	$o_obj->update(); 			# using object data

	$o_obj->update(\%data);		# using given data, note B<only> this data is used!

To check whether the object was succesfully updated, ask:

	my $i_isok = $o_obj->UPDATED; # ?

=cut

sub update {
	my $self = shift;
	my $h_data = shift || $self->_oref('data');
	my ($table, $pri) = ($self->attr('table'), $self->attr('primary_key'));

	my ($msg, $sth, $type) = ('', '', '');
	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires data hash ref($h_data) to update object data!");
	} else {
		my $oid = $$h_data{$pri} || $self->oid || ''; # rjsf: messy :-(
		if (!($self->exists([$oid]))) {	#
			$self->error("can't update non-existent objectid($oid)!");
		} else { 
			$self->read($oid); 	# first we read it...(don't need to exists above)!
			if (!$self->READ) {
				$self->error("can't update object(".$self->key.") with unreadable id($oid)");
			} else { 			# then we can set the new stuff
				$self->data({ %{$h_data}, $pri, $oid }); 	# set
				my $sql = $self->prep('update', $self->_oref('data'));
				$sql = $sql." WHERE $pri = '$oid'";
				my $sth = $self->base->exec($sql);	# DOIT
				if (!$sth) {
					$self->error("Failed($oid) $type sql($sql)!");
				} else {	
					$self->UPDATED(1);
					# $self->track($sql); # rjsf: too much (remove msgheader/body/entry) 
					$self->base->clean_cache('sql');
				}
			}
		}
	}

	return $self;
}

=item UPDATED 

Returns 0|1 depending on whether object has been succesfully updated 

	my $i_isok = $o_obj->UPDATED;

=cut

sub UPDATED {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'updated', $1}) if $i_flag =~ /^(1|0)$/o;

	$i_flag = $self->flag('updated');

	return $i_flag;	
}

=item delete

Delete the given objectid/s or current object, and all it's relationships

	$o_obj->delete(); 				# this object

	$o_obj->delete(\@oids);			# list ref

To check whether the object/s was succesfully deleted, ask:

	my $i_isok = $o_obj->DELETED; # 0|1

=cut

sub delete {
	my $self = shift;
	my $a_oids = shift || [$self->oid()];
	my ($table, $pri) = ($self->attr('table'), $self->attr('primary_key'));

	my ($msg, $sql, $sth, $type) = ('', '', '', '');
	if (!(ref($a_oids) eq 'ARRAY')) {
		$self->error("requires oid/s array ref($a_oids) to delete object data!");
	} else {
		foreach my $oid (@{$a_oids}) {
			if (!($self->exists([$oid]))) {	# DOIT 
				$self->debug(0, "Can't delete non-existing objectid($oid)!") if $Perlbug::DEBUG;	
			} else { # recursion handled by application (foreach rel)
				my $sql = "DELETE FROM ".$self->attr('table')." WHERE ".$self->primary_key." = '$oid'";
				my $sth = $self->base->exec($sql);	# DOIT
				if (!$sth) {
					$self->error("Delete($oid) failed: sql($sql)!");
				} else {	
					$self->DELETED(1); 
					my $obj = $self->key;
					$self->base->track($obj, $oid, $sql) unless $obj =~ /(log|range)/io;
					$self->base->clean_cache('sql');
				}	
			}	
		}
		# $self->reinit;
	}

	return $self;
}

=item DELETED 

Returns 0|1 depending on whether object has been succesfully deleted 

	my $i_isok = $o_obj->DELETED;

=cut

sub DELETED {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'deleted', $1}) if $i_flag =~ /^(1|0)$/o;

	$i_flag = $self->flag('deleted');

	return $i_flag;	
}

=item updatable 

Check if current object(type) is allowed to be updated

Returns updatable ids

    print 'updatable: '.join(', ', $o_obj->updatable(\@ids));

=cut

sub updatable {
    my $self  = shift;
    my $a_ids = shift || ''; # ignored

	$self->error("requires an array_ref or uids($a_ids) to check!") unless ref($a_ids);

	my @ids = $self->base->isadmin ? @{$a_ids} : ();
	
    return @ids;
}

=item insertid

Returns newly inserted id from database statement handle

	my $new_oid = $o_obj->insertid($sth, $oid);

=cut

sub insertid {
	my $self = shift;
	my $sth  = shift;
	my $oid  = shift || '';
	my $newid= '';

	if ($sth) {
		if ($oid =~ /^(\s*|NULL)$/io) {
			$newid = $sth->{'mysql_insertid'};
		} else {
			$newid = $oid;
		}
	}

	$self->debug(1, "inserted($sth) oid($oid) => newid($newid)") if $Perlbug::DEBUG;

	return $newid;
}

=item new_id

Return valid new object id for given object, usually NULL, as Mysql generates own.

	my $new_oid = $o_obj->new_id

	# Bug/User expected to generate it's own
	# Mysql specific
	# Oracle requires SELECT FROM SEQUENCE ...
	# Relations map differently...

=cut

sub new_id {
	my $self = shift;

	my $newid = 'NULL'; 
	$self->debug(1, 'new '.ref($self)." objectid($newid)") if $Perlbug::DEBUG;
	
	return $newid;
}

=back

# =============================================================================

=head1 CONVENIENCE

Convenient wrappers for the following methods are supported, for more details see L<Perlbug::Base>

=over 4

=item error

Wrapper for $o_obj->base->error()

=cut

sub error {
	my $self = shift;

	my $hint = '<'.($self->attr('key')).'>';

	return $self->base->error("$hint - @_");
}

=item debug

Wrapper for $o_obj->base->method()

=cut

sub debug {
	my $self = shift;
	$self->base->debug(@_) if $Perlbug::DEBUG;
}

=item object

Wrapper for $o_obj->base->method()

=cut

sub object {
	my $self = shift;
	return $self->base->object(@_);
}

=item format

Simple wrapper for L<FORMAT()>

	my $str = $o_obj->format('h');

=cut

sub format { # return $o_fmt->FORMAT(@_)  
	my $self = shift;
	my $fmt  = shift || $self->base->current('format');
	my $func = shift || 'display';

	if (0) { # too late to turn back now :-]
		$self->refresh_relations; # ek
		return $self->FORMAT($fmt, @_); # Perlbug::FORMAT
	} else {
		return $self->template($fmt);
	}
}

=item template

Applies appropriate template to this object, based on optional format, h_data, h_rels.

	my $str = $o_obj->template($fmt, [$h_data, [$h_rels]]); # [ahl...]

=cut

sub template { # return $o_template->merge($self, $fmt);
	my $self   = shift;
	my $fmt    = shift || $self->base->current('format');
	my $h_data = shift;
	my $h_rels = shift;
	my $obj    = $self->key;

	my $o_template = $self->object('template');
	my ($hdr, $str, $ftr) = $o_template->merge($self, $fmt, $h_data, $h_rels);

	my $i_printing = $self->attr({'printed', $self->attr('printed') + 1});
	my $i_rep = my $i_reporig = $o_template->data('repeat') || 0; 
	if ($i_rep > 1) {
		my $i_res = $i_printing % $i_rep;
		$i_rep = 0 unless $i_res == 1;
	}
	$self->debug(2, "i_printing($i_printing) % orig($i_reporig) => rep($i_rep)") if $Perlbug::DEBUG;

	$str = $hdr.$str.$ftr if $i_rep;

	$self->debug(3, "!$i_rep!: fmt($fmt) obj($obj) => ".$str) if $Perlbug::DEBUG;

	return $str;
}


=item diff

Returns differences between two (format|templat)ed strings, on a per line basis.

Note that multiple blank lines are reduced to a single blank line.

	my $diff = $o_obj->diff("this\nand\that", "this\nor\nthat\netc.");

Produces:

	old:
		2  and
		4

	new:
		2  or
		4  etc.

=cut

sub diff {
	my $self = shift;
	my $xone = shift;
	my $xtwo = shift;
	my $diff = '';

	unless (defined($xone) and defined($xtwo)) {
		$self->debug(0, "requires one($xone) and two($xtwo) to differentiate") if $Perlbug::DEBUG;
	} else { 
		$xone =~ s/^(\s*\n)+/\n/go;
		$xtwo =~ s/^(\s*\n)+/\n/go;
		my $i_one = my @one = split("\s*\n\s*", $xone);
		my $i_two = my @two = split("\s*\n\s*", $xtwo);

		my ($old, $new) = ('', '');
		my $i_max = (($i_one > $i_two) ? $i_one : $i_two) + 1;
		foreach my $i_num (1..$i_max) {
			my $one = (scalar(@one) >= 1) ? shift(@one) : '';
			my $two = (scalar(@two) >= 1) ? shift(@two) : '';
			my $qtwo = quotemeta($two);
			if ($one =~ /^$qtwo$/) {
				$self->debug(3, "$i_max: \n\tone($one) looks like \n\ttwo($two)") if $Perlbug::DEBUG;
			} else {
				$self->debug(3, "$i_max: \n\tone($one) differs from \n\ttwo($two)") if $Perlbug::DEBUG;
				$old .= "$i_num  $one\n";
				$new .= "$i_num  $two\n";
			}
		}
		$diff = "old: \n$old\nnew: \n$new\n" if $old && $new;
	}
	$self->debug(2, "one($xone) two($xtwo) => diff($diff)") if $Perlbug::DEBUG;

	return $diff;
}

=item rtrack 

Tracks object administration (relations), where %entry is the relevant B<relate()> data, etc.

	$o_obj = $o_obj->rtrack(\%data, [$obj, [$objectid]]);

=cut

sub rtrack {
	my $self   = shift;
	my $h_data = shift || '';
	my $type   = shift || $self->key;
	my $oid    = shift || $self->oid;
	
	my $indent = $Data::Dumper::Indent;
	$Data::Dumper::Indent=0;
	my $i_tracked = $self->base->track($type, $oid, Dumper($h_data)) 
		unless $type =~ /(log|range)/io; #
	$Data::Dumper::Indent=$indent;

	$self->TRACKED(1) if $i_tracked;

	return $self;
}


=item TRACKED 

Returns 0|1 depending on whether object has been succesfully TRACKED 

	my $i_isok = $o_obj->TRACKED;

=cut

sub TRACKED {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'tracked', $1}) if $i_flag =~ /^(1|0)$/o;

	$i_flag = $self->flag('tracked');

	return $i_flag;	
}

# =============================================================================

=item attr

Get and set attributes

	my $objectid = $o_obj->attr('objectid');			# get

	my $newobjid = $o_obj->attr({'objectid', $newid});	# set

=item data 

Get and set data by hash B<ref>.

Returns data values, all if none specified.

	$o_obj->data({
		'this' 	=> 'that',
		'and'	=> 'so on',
	});

	my $name = $o_obj->data('name');

	my @vals = $o_obj->data;

=item flag 

Get and set flags 

	my $i_read = $o_obj->flag('read');			# get

=item var

Note that to set any of these you have to send in a hashref!

Returns keys of succesful updates

	my $attr = $self->attr('objectid'); 			# get

	my @keys = $self->data();						# get

	my $data = $self->flag({'created' => 1}); 		# set $data=created

	my @data = $self->data({'name' => 'newname', 'body'	=> 'stuff'}); # set 

=cut

sub AUTOLOAD {
    my $self = shift;
    my $get  = shift || '';	# get || { set => 'this' }
	my $meth = $AutoLoader::AUTOLOAD = $AUTOLOAD;
    return if $meth =~ /::DESTROY$/o;

    $meth =~ s/^(.*):://o;
	my $pkg = ref($self);
	my @ret = ();

    if ($meth !~ /^(attr|data|flag)$/) { # not one of ours :-)
        $self->error("$pkg->$meth($get, @_) called with a duff method($AUTOLOAD)!  Try: 'perldoc $pkg'");
    } else { 
		no strict 'refs';
		*{$AUTOLOAD} = sub {
			my $self = shift;
			my $get  = shift;
			my @ret  = ();

			if (!defined($get)) {
				@ret = keys %{$self->{"_$meth"}}; 						# ref
			} else {
				if (ref($get) ne 'HASH') { 								# get
					@ret = ref($self->{"_$meth"}{$get}) eq 'ARRAY' 
						? @{$self->{"_$meth"}{$get}} 
						:  ($self->{"_$meth"}{$get});
				} else {												# set the hashref
					my $keys = join('|', keys %{$self->{"_$meth"}});	# ref
					SET:
					foreach my $key (keys %{$get}) {
						if ($key =~ /^($keys)$/) {
							$self->{"_$meth"}->{$key} = $$get{$key};	# SET
							push(@ret, $$get{$key});
						} else {
							$self->debug(2, "$pkg has no such $meth key($key) valid($keys)") if $Perlbug::DEBUG;
						}
					}
				}
			}
			return wantarray ? @ret : $ret[0];
		}
    }

	return wantarray ? @ret : $ret[0];
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001 2002

=cut

1;

