# Perlbug object attribute handler
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: Object.pm,v 1.45 2001/10/22 15:29:50 richardf Exp $
#

=head1 NAME

Perlbug::Object - Object handler for Perlbug database

=cut

package Perlbug::Object;
use strict;
use vars(qw($VERSION @ISA $AUTOLOAD));
@ISA = qw(Perlbug::Format); 
$VERSION = do { my @r = (q$Revision: 1.45 $ =~ /\d+/go); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

use Carp;
use CGI;
use Data::Dumper;
use Perlbug::Format; 
# use Perlbug::Template; 
my $o_Perlbug_Base = '';
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

=cut


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
			'match_oid'	=> '(\d+)',  		# default
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
	# push(@{$self->{'_attr'}{'to'}}, 'template');

	$self = bless($self, $class);

	$self->data; $self->attr; $self->flag; # prime
	$self = $self->reinit; # inc. check()
	# print "rjsf: Object::new($name) -> ".sprintf('%-15s', $self)."...\n";

	return $self;
}


=item init_data 

Initialise generic object attr, columns and column_types from table in db.

Returns object

	my $o_obj = $o_obj->init_data($table);

N.B. this may be a bit unstable against different databases (Oracle/Mysql/etc.)

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
		foreach my $targ ( @{$self->attr($type)} ) { # patch change bug address user
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
	my $oid = shift || $self->oid;

	$self->CREATED(0);
	$self->READ(0);
	$self->UPDATED(0);
	$self->DELETED(0); 
	$self->STORED(0);
	$self->TRACKED(0);
	$self->REINIT(1);

	my @fields = $self->init_data($self->attr('table'));
	my $i_ok = $self->check();

	my @types  = @{$self->attr('types')};
	my @rels   = $self->init_types(@types);
	# $self->oid($oid) if $oid;
	$self->debug(3, "rjsf: object($oid) reinit(".$self->attr('key').") types(@types) rels(@rels)") if $Perlbug::DEBUG;

	return $self;
}


=item refresh_relations

Refresh relation data

=cut

sub refresh_relations {
	my $self = shift;

	foreach my $rel ($self->relations) { # should not be here! -> call rel($rel, 'ids')
		my @rids  = $self->rel_ids($rel, '', 'refresh');	# refresh
		my @names = $self->rel_names($rel); 	# $self->relation($rel)->id2name(\@rids);
		$self->{'_relation'}{$rel}{'ids'}   = \@rids; # need this for format/templates
		$self->{'_relation'}{$rel}{'count'} =  @rids;	
		$self->{'_relation'}{$rel}{'names'} = \@names;	
	}

	return $self;
}


=item check

Check all attr are initialised

	my $i_ok = $o_obj->check(@keys_to_check);

=cut

sub check{
	my $self  = shift;
	my $h_ref = shift || $self->_oref('attr');

	my $i_ok  = 1;

	CHECK:
	foreach my $key (keys %{$h_ref}) {
		if ($$h_ref{$key} !~ /\w+/ && $key !~ /(debug|objectid)/i) {
			$i_ok = 0;
			$self->error(" is incomplete key($key) val($$h_ref{$key}): ".Dumper($h_ref));
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
				  " WHERE $pri LIKE '_%' AND $pri IN ('$ids')"
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
				  " WHERE $pri LIKE '_%' AND $pri IN ('$ids')"
		;
		@IDS = $self->base->get_list($sql);
	}

	return @IDS;
}


=item data_fields

Returns all valid data field names for this object

	my @fields = $o_obj->data_fields;

=cut

sub data_fields {
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
		@ids = ($str =~ /$match/gs);
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

Wrapper to get and set objectid, (and data(<objectid>) at the same time. 

	my $oid = $o_obj->objectid($id);

=cut

sub oid { my $self = shift; return $self->objectid(@_); } # shortcut

sub objectid {
	my $self = shift;
	my $in = shift || '';

	if ($self->ok_ids([$in])) { # are appropriate
		$self->attr( { 'objectid', $in } ); # explicit	
		$self->data( { $self->attr('primary_key'), $in } );
	}
	my $oid = $self->attr('objectid');

	return $oid;
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
	
	my $sql = "SELECT DISTINCT ".$self->attr('primary_key')." FROM ".$self->attr('table');
	if (ref($input)) {				# OBJECT with ids, etc.
		$sql .= ' WHERE '.$input->attr('primary_key')." LIKE '".$input->oid()."'";		
		$sql .= " AND $extra" if $extra;
	} elsif ($input =~ /\w+/o) { 	# SQL where clause
		$input =~ s/^\s*WHERE\s*//io;	
		$sql  .= " WHERE $input";	
	} 								# ALL
	$sql .= " ORDER BY name " if $self->identifier eq 'name';
	
	@ids = $self->base->get_list($sql, $refresh);
	# print "rjsf: <hr>$self, input($input), extra($extra), refresh($refresh) -> ids(@ids)<hr>";
	$self->debug(2, "input($input) extra($extra) -> ids(@ids)") if $Perlbug::DEBUG;

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
			$sql .= ' WHERE '.$input->attr('primary_key')." LIKE '".$input->oid()."'";		
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
			$sql .= ' WHERE '.$input->attr('primary_key')." LIKE '".$input->oid()."'";		
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
		$self->debug(0, "no input ids given to convert($a_input)");
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

	my $i_cnt = $o_obj->count("$objectid LIKE '$criteria'");

=cut

sub count {
	my $self 	= shift;
	my $input = shift || '';
	my $extra = shift || '';

	my $i_cnt 	= 0;
	
	my $sql = "SELECT COUNT(".$self->attr('primary_key').") FROM ".$self->attr('table');
	if (ref($input)) {				# OBJECT with ids, etc.
		$sql .= ' WHERE '.$input->attr('primary_key')." LIKE '".$input->oid()."'";		
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


# -----------------------------------------------------------------------------

=item popup 

Create scrolling web list popup with given pre-selection (or B<any>), with (alphabetically sorted) names where possible

	my $popup = $o_obj->popup('unique_name', [$selected]); # or none('') 

=cut

sub popup {
	my $self = shift;
	my $name = shift || $self->attr('name');
	my $sel  = shift || '';

	my $cgi  = $self->base->cgi;
	($sel)  = @{$sel} if ref($sel) eq 'ARRAY';

	my %map = ('any' => 'any', '' => '',);
	my $pri = $self->attr('primary_key');
	# my $col = (grep(/^name$/i, $self->data_fields)) ? 'name' : $pri;
	my ($col) = map { ($_ =~ /^name$/o ? $_ : $pri ) } $self->data_fields ? 'name' : $pri;

	if (1) { # all - better than foreach id -> SQL 
		my @ids = $self->col("CONCAT($pri, ':', $col)"); 
		foreach my $id (@ids) {
			my ($pre, $post) = split(':', $id);
			$map{$pre} = $post;
		}
	} else { # rjsf: redundant
		my @ids = $self->ids; # all
		foreach my $id (@ids) {
			($map{$id}) = $self->col($col, "WHERE $pri = '$id'");
		}
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
	# $self->debug(3, "name($name) pop($pop)") if $Perlbug::DEBUG;
	return $pop;
}


=item selector

Create scrolling web list selector with given pre-selections, with names where possible

	my $selctr = $o_obj->selector('unique_name', @pre_selected);

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

	if (1) { # all - better than foreach id -> SQL 
		my @ids = $self->col("CONCAT($pri, ':', $col)"); 
		foreach my $id (@ids) {
			my ($pre, $post) = split(':', $id);
			$map{$pre} = $post;
		}
	} else {
		my @ids = $self->ids; # all
		foreach my $id (@ids) {
			($map{$id}) = $self->col($col, "WHERE ".$self->attr('primary_key')." LIKE '$id'");
		}
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
	);
	# $self->debug(3, "name($name) sel($sel)") if $Perlbug::DEBUG;
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
	return $txt;
}


=item _gen_field_handler

Generate code to handle get and set object fields, returns 1|0

	my $i_ok = $o_obj->_gen_field_handler('header');

	my $var = $o_obj->header($msg); # var has msg

=cut

sub _gen_field_handler {
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


sub _oref { # unsupported 
	my $self = shift;
	my $key  = shift;
	my $href = ''; # !

	my @refs = keys %{$self};
	# if (!grep(/^_$key$/, @refs)) { # sneaky :-]
	if (!(map { ($_ =~ /^_$key$/ ? 1 : 0) } @refs)) {
		$self->error("unknown key($key) requested! valid keys(@refs)");	
	} else {
		$href = { %{$self->{"_$key"}} }; # copy
	}
	return $href;
}

=pod

=back

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

sub rel_types { my $self = shift; return $self->relation_types(@_); } # wrapper for relation_types()

sub relation_types {
	my $self = shift;
	return @{$self->attr('types')};
}


=item isarel

Returns 1|0 dependant on whether relation($rel), is of given type (or any), or not

	print "yup\n" if $o_obj->isarel($rel);

eg:

	print "patch is related to a bug\n" if $o_pat->isarel('bug');

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

sub rels { my $self = shift; return $self->relations(@_); } # wrapper for relations()

sub relations {
	my $self = shift;
	my $type = shift || ''; # float|from|to
	my @rels = ();
	if (defined($type) && $type =~ /\w+/o) {
		@rels = @{$self->attr($type)}; 
	} else {	
		@rels = map { @{$self->attr($_)} } $self->rel_types;
	}
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

sub rel { my $self = shift; return $self->relation(@_); } # wrapper for relation()

sub relation {
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

sub rel_ids { my $self = shift; return $self->relation_ids(@_); } # wrapper for relation_ids()

sub relation_ids { # object 
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
			$self->debug(3, "rel($rel) -> o_rel($o_rel) -> ids(".@ids.')') if $Perlbug::DEBUG;
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

sub rel_names { my $self = shift; return $self->relation_names(@_); } # wrapper for relation_names()

sub relation_names { # object 
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

Work through the given hash using the objects' B<relations()>,  
B<assign()>ing any relation-ids found, alternatively,  
B<_assign()>ing any relation-names found. 

Prejudicial against $o_rel->attr('prejudicial') relationships.

Designed to take the output of B<Perlbug::Base::parse_str()>:

Returns number of objects assigned to.

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
			my $track = '';
			my %track = ();
			$self->debug(2, "relating for oid: ".$self->oid);
			RELATE:
			foreach my $rel ($self->rels) {
				next RELATE unless $rel =~ /\w+/o;
				my $prej  = ($self->object($rel)->attr('prejudicial') == 1) ? 1 : 0;
				my $o_rel = $self->rel($rel);
				my $a_ids = $$h_ships{$rel}{'ids'} || [];
				my $call  = $prej ? 'store' : 'assign';
				if (ref($$h_ships{$rel}{'ids'})) {
					$o_rel->$call($a_ids);
					$track{$rel}{'ids'} = $o_rel->ASSIGNED.' of ('.join(', ', @{$a_ids}).')';
				} 
				my $a_names = $$h_ships{$rel}{'names'} || [];
				if (ref($$h_ships{$rel}{'names'}) eq 'ARRAY') {
					my $call  = $prej ? '_store' : '_assign';
					$o_rel->$call($a_names);
					$track{$rel}{'names'} = $o_rel->ASSIGNED.' of ('.join(', ', @{$a_names}).')';
				}
				if (ref($track{$rel})) {
					push(@rels, $rel) if keys %{$track{$rel}} >= 1;
				}	
			}
			$self->debug(2, 'oid('.$self->oid.') related: '.Dumper(\%track)) if $Perlbug::DEBUG;
			$self->track($track);
		}
	}

	return @rels;
}


=pod

=back

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
	# $self->reinit; # always want a fresh one
	$self->READ(0);
	if ($self->ok_ids([$oid]) != 1) {
		$self->debug(0, "$self requires a valid id($oid) to read against!");
	} else {
		my $pri	  = $self->attr('primary_key');
		my $table = $self->attr('table');
		my $sql = "SELECT * FROM $table WHERE $pri LIKE '$oid'"; # SQL
		my ($h_data) = $self->base->get_data($sql);
		$h_data = '' unless $h_data;
		if (ref($h_data) ne 'HASH') {
			$self->debug(0, "failed to retrieve data($h_data) with $pri = '$oid' in table($table)"); 
		} else {
			$self->debug(2, $self->key." oid($oid)") if $Perlbug::DEBUG;
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
			$val =~ s/^\s+//o;		# front
			$val =~ s/\s+$//o;		# back
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
			$self->error("requires an objectid($oid) to create record".Dumper($h_data));
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
					$self->debug(2, "sql($sql) -> insertid($oid)");
					if (!$oid) {
						$self->error("Failed to fetch new oid($oid) from sql($sql)");
					} else {
						$self->CREATED(1);
						$oid = $self->oid($oid); # if $oid =~ /\w+/ && $oid !~ '0';
						$self->track($sql." -> oid($oid)");
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


=item update

Update the given data into the db, loaded from current object, or given data.

	$o_obj->update(); 			# using object data

	$o_obj->update($h_data);	# using given data, note B<only> this data is used!

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
					$self->track($sql); # rjsf: too much (remove msgheader/body/entry) 
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
				$self->error("can't delete non-existing objectid($oid)!");	
			} else { # recursion handled by application (foreach rel)
				my $sql = "DELETE FROM ".$self->attr('table')." WHERE ".$self->primary_key." = '$oid'";
				my $sth = $self->base->exec($sql);	# DOIT
				if (!$sth) {
					$self->error("Delete($oid) failed: sql($sql)!");
				} else {	
					$self->DELETED(1); 
					$self->track($sql);
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
		if ($oid =~ /^(\s*|NULL)$/) {
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

	# Bug expected to generate it's own
	# Mysql specific
	# Oracle requires SELECT FROM SEQUENCE ...
	# Relations map differently...

=cut

sub new_id {
	my $self = shift;

	my $newid = 'NULL'; 
	$self->debug(1, "new objectid($newid)") if $Perlbug::DEBUG;
	
	return $newid;
}


=back

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

	my %map = (
		'a'	=> 5, 	'A'	=> 1, 
		'h'	=> 10, 	'H'	=> 1,
		'i'	=> 1, 	'I'	=> 15,
		'l'	=> 250, 'L'	=> 25,
		'x'	=> 1, 	'X'	=> 1,
	);
	$self->max($map{$fmt}); # !

	$self->refresh_relations; # ek

	return $self->FORMAT($fmt, @_); # Perlbug::FORMAT
	return $self->template($func, $fmt, @_);
}


=item template

Simple wrapper for L<TEMPLATE()>

	my $str = $o_obj->template([$fmt, [$h_data, [$h_rels]]]);

Unless given, this uses the internal object structures B<data> and B<rel>, (if primed).

=cut

sub template { # return $o_template->TEMPLATE(@_)  
	my $self   = shift;
	my $fmt    = shift || $self->base->current('format');
	my $h_data = shift || $self->_oref('data');
	my $h_rel  = shift || $self->_oref('relation'); # :-\
	my $str    = '';

	$self->refresh_relations; # ek

	my $o_object   = $self->object('object');
	my $o_template = $self->object('template');
	my $o_user     = $self->object('user');
	my $o_tmpusr   = $o_template->rel('user');

	my $obj        = $self->key;
	my ($type)     = $o_object->col('type', "name = '$obj'");
	my $userid     = $self->base->isadmin;
	
	my $template_user = "SELECT ".$o_template->primary_key." FROM ".$o_tmpusr->attr('table')." WHERE userid = '$userid'";
	my @tempids  = $self->base->get_list($template_user);
	my $tempids  = join("', '", @tempids);

	my $cond = "object = '$obj' AND format = '$fmt' AND templateid IN('$tempids')";
	my ($tempid) = reverse sort { $a <=> $b } my @tids = $o_template->ids($cond);
	$self->debug(0, "template($tempid) for user($userid) from($cond)");
	if (!$tempid) { # default?
		$cond = "object = '' AND type = '$type' AND format = '$fmt' AND templateid IN('$tempids')";
		($tempid) = reverse sort { $a <=> $b } my @tids = $o_template->ids($cond);
	}

	my $withheader = 0;
	$self->attr({'printed', $self->attr('printed') + 1});
	if ($self->attr('printed') >= $o_template->data('repeat')) {
		$withheader = 1;
		$self->attr({'printed', 0});
	}

	if ($tempid !~ /^\d+$/) {
		$self->debug(0, "using default display!");	
		$str = $o_template->_template($h_data, $h_rel, $fmt, $withheader);
	} else {
		$o_template->read($tempid);
		$self->debug(0, "using template($tempid) read(".$o_template->READ.")");	
		$str = $o_template->template($h_data, $h_rel, $fmt, $withheader);
	}

	return $str;
}


=item diff

Returns differences between two (format|templat)ed strings, on a per line basis.

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


=item track 

Tracks object administration, where $entry is the relevant statement, etc.

	$o_obj = $o_obj->track($entry, 'bug', '<bugoid>');

=cut

sub track {
	my $self = shift;
	my $data = shift || '';
	my $type = shift || $self->key;
	my $oid  = shift || $self->oid;
	
	my $i_tracked = $self->base->track($type, $oid, $data) 
		unless $type =~ /(log|range)/io; # || $type =~ /^pb_[a-z]+_[a-z]+$/); # relly

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


=item attr

Get and set attributes

	my $objectid = $o_obj->attr('objectid');			# get

	my $newobjid = $o_obj->attr({'objectid', $newid});	# set

=cut

# sub xattr { my $self = shift; return $self->xattribute(@_); } # wrapper for testing attribute()

sub xattr { # test method
	my $self = shift;
	my $get  = shift;
	my @ret  = ();

	if (!defined($get)) {
		@ret = keys %{$self->{'_attr'}}; 			# ref
	} else {
		if (ref($get) ne 'HASH') { 					# get
			@ret = ($self->{'_attr'}{$get});
		} else {									# set
			my $keys = join('|', keys %{$self->{'_attr'}}); 	# ref
			SET:
			foreach my $key (keys %{$get}) {
				if ($key =~ /^($keys)$/) {
					$self->{'_attr'}->{$key} = $$get{$key}; # SET
					push(@ret, $$get{$key});
				} else {
					$self->debug(2, ref($self)." has no such attribute key($key) valid($keys)") if $Perlbug::DEBUG;
				}
			}
		}
	}
	return wantarray ? @ret : $ret[0];
}


=item data 

Get and set data by hash B<ref>.

Returns data values, all if none specified.

	$o_obj->data({
		'this' 	=> 'that',
		'and'	=> 'so on',
	});

	my $name = $o_obj->data('name');

	my @vals = $o_obj->data;

=cut


=item flag 

Get and set flags 

	my $i_read = $o_obj->flag('read');			# get

=cut


=item attr 

=item data

=item flag

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

			# if (ref($self->{"_$meth"}) ne 'HASH') {
			#	$self->error("invalid object($pkg) structure($meth): ".Dumper($self));
			# } else {
				if (!defined($get)) {
					@ret = keys %{$self->{"_$meth"}}; 			# ref
				} else {
					if (ref($get) ne 'HASH') { 					# get
						@ret = ($self->{"_$meth"}{$get});
					} else {									# set
						my $keys = join('|', keys %{$self->{"_$meth"}}); 	# ref
						SET:
						foreach my $key (keys %{$get}) {
							if ($key =~ /^($keys)$/) {
								$self->{"_$meth"}->{$key} = $$get{$key}; # SET
								push(@ret, $$get{$key});
							} else {
								$self->debug(2, "$pkg has no such $meth key($key) valid($keys)") if $Perlbug::DEBUG;
							}
						}
					}
				}
				return wantarray ? @ret : $ret[0];
			# }	
		}
    }
	return wantarray ? @ret : $ret[0];
}


=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut

1;

