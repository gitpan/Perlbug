# Perlbug object attribute handler
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: Object.pm,v 1.32 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object - Object handler for Perlbug database

=cut

package Perlbug::Object;
use strict;
use vars(qw($VERSION @ISA $AUTOLOAD));
@ISA = qw(Perlbug::Format); 
$VERSION = do { my @r = (q$Revision: 1.32 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_DEBUG'} || $Perlbug::Object::DEBUG || '';
$|=1;

use Carp;
use CGI;
use Data::Dumper;
use Perlbug::Base;
use Perlbug::Format; 
my $o_Perlbug_Base = '';


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
	unless ($key =~ /\w+/) {
		$o_Perlbug_Base->error("Fatal error: no keyname($name) given!\n".Dumper(\%input)."\n");
	}

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 
	my $self = { 												# eg:
		'_attribute'	=> {			
			'debug'		=> $DEBUG,			# level
			'float'		=> [],				# rel
			'from'		=> [],				# rel
			'hint'		=> "$name($key)",	# Bug(Child)...
		    'key'		=> $key,			# bug
		    'name'  	=> $name,			# Bug
			'match_oid'	=> '(\d+)',  		# default
		    'objectid'	=> '',				# 21, 200011122.003
			'primary_key'=> $key.'id',		# bugid
			'sql_clean'	=> 1,				# clean sql on create, update, delete, etc.
		    'table' 	=> 'pb_'.$key,		# db_bug
			'track'		=> '1',				# usually
			'to'		=> [],				# rel
			'type'		=> 'friendly', 		# ...|prejudicial
			'types'		=> [qw(from to)], 	# of rels
			%input,
		},  	
		'_data'			=> {}, 		 		# 'field' 	=> 'value' ...
		'_type'			=> {},				# 'field'	=> 'INTEGER'...
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
	# push(@{$self->{'_attribute'}{'to'}}, 'template');

	$self = bless($self, $class);

	$self->data; $self->attribute; $self->flag; # prime
	$self = $self->reset; # inc. check()
	# print "rjsf: Object::new($name) -> ".sprintf('%-15s', $self)."...\n";

	return $self;
}


=item init_data 

Initialise generic object attribute, columns and column_types from table in db.

Returns object

	my $o_obj = $o_obj->init_data($table);

N.B. this may be a bit unstable against different databases (Oracle/Mysql/etc.)

=cut

sub init_data { # generic attribute from db
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
		$type = 'DATETIME' if $$f{'Type'} =~ /^DATE(TIME)*$/i;
		$type = 'INTEGER'  if $$f{'Type'} =~ /^(BIG|SMALL)*INT(EGER)*(\(\d+\))*/i;
		$self->{'_data'}{$field} = ''; 		# init	
		$self->{'_type'}{$field} = $type; 	# init	
		# $self->_gen_field_handler($field);# don't call 
	}

	return $self;
}


=item init_types

Initialise generic object attribute based on table from db, returns relation names.

	my @rels = $o_obj->init_types(@rel_types);

=cut

sub init_types { # generic attribute from db
	my $self  = shift;
	my @types = @_;
	my @rels  = ();
	
	$self->{'_relation'} = {}; # reset
	foreach my $type (@types) { # float|from|to
		foreach my $targ ( @{$self->attr($type)} ) { # patch changeid bug address user
			$self->{'_relation'}{$targ}{'type'} = $type;
			push(@rels, $targ);
		}
	}

	return @rels;
}


=item reset

Reset object to default values, with optional object_id where different, returns object

	$o_obj->reset($oid);

To check whether the object was succesfully reset, ask:

	my $i_isok = $o_obj->RESET; # ?

=cut

sub reset { 
	my $self = shift; 
	my $oid = shift || $self->oid;

	$self->CREATED(0);
	$self->READ(0);
	$self->UPDATED(0);
	$self->DELETED(0); 
	$self->STORED(0);
	$self->TRACKED(0);
	$self->RESET(1);

	my @fields = $self->init_data($self->attr('table'));
	my $i_ok = $self->check();

	my @types  = @{$self->attr('types')};
	my @rels   = $self->init_types(@types);
	# $self->oid($oid) if $oid;
	$self->debug(3, "rjsf: object($oid) reset(".$self->attr('key').") types(@types) rels(@rels)") if $DEBUG;

	$self;
}


=item check

Check all attribute are initialised

	my $i_ok = $o_obj->check(@keys_to_check);

=cut

sub check{
	my $self  = shift;
	my $h_ref = shift || $self->_oref('attribute');

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


=item RESET 

Returns 0|1 depending on whether object has been reset

	my $i_isok = $o_obj->RESET;

=cut

sub RESET {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag('reset', $1) if $i_flag =~ /^(1|0)$/;	

	$i_flag = $self->flag('reset');

	return $i_flag;	
}


=item exists

Examines the database to see if current object exists already.

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
		$self->debug(0, "no string($str) given to inspect for ids!");
	} else {
		my $match = $self->attr('match_oid');
		# my %x = ($dmc =~ /\<(\w+)\>(\w+)?(?:)\<\/\1\>/gi)
		@ids = ($str =~ /$match/gs);
		$self->debug(2, "str($str) match($match) -> ids(@ids)") if $DEBUG;
	}

	return @ids;
}


=item ok_ids 

Checks to see if given oid/s look anything like we are expecting them to.

Returns list of acceptable object ids

	my @ok_ids = $o_obj->ok_ids(\@some_ids);

=cut

sub ok_ids { # 
	my $self = shift;
	my $a_ids = shift || '';
	my @ok = ();

	if (!ref($a_ids) eq 'ARRAY') {
		$self->error("expecting array_ref($a_ids) of object ids!");
	} else {
		my $ids = join('|', my @ids = @{$a_ids});
		if (!(scalar(@ids) >= 1)) {
			$self->debug(2, "no ids(@ids) given") if $DEBUG;
		} else {
			my @wids = map { ($_ =~ /\w+/ ? $_ : ()) } @ids;  
			if (!(scalar(@wids))) {
				$self->debug(2, "no word-like ids(@wids) given(@ids)") if $DEBUG;
			} else {
				my $i_ids = @wids;
				my $match = $self->attr('match_oid');
				my $i_oks = @ok = map { ($_ =~ /^$match$/ ? $_ : ()) } @wids;  
				if ($i_ids != $i_oks) {
					$self->debug(0, $self->key()." failed to match($match) object ids! given: $i_ids(@wids) => ok_ids: $i_oks(@ok)"); 
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
	
	if ($in =~ /\w+/) {
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

	my @rel_ids  = $o_obj->ids($o_rel, [$further_restrained_by_sql]);

	my @selected = $o_obj->ids($where);

=cut

sub ids { # class 
	my $self  = shift;
	my $input = shift || '';
	my $extra = shift || '';
	my @ids   = ();
	
	my $sql = "SELECT DISTINCT ".$self->attr('primary_key')." FROM ".$self->attr('table');
	if (ref($input)) {				# OBJECT with ids, etc.
		$sql .= ' WHERE '.$input->attr('primary_key')." = '".$input->oid()."'";		
		$sql .= " AND $extra" if $extra;
	} elsif ($input =~ /\w+/) { 	# SQL where clause
		$input =~ s/^\s*WHERE\s*//i;	
		$sql  .= " WHERE $input";	
	} 								# ALL
	$sql .= " ORDER BY name " if $self->identifier eq 'name';

	@ids = $self->base->get_list($sql);
	$self->debug(4, "input($input) extra($extra) -> ids(@ids)") if $DEBUG;

	return @ids;
}


=item names

Get DISTINCT names for this object.

If there is no ident=name, or no names, for the object, returns empty list().

For restraints/parameters see L<ids()>

	my @names = $o_obj->names();

=cut

sub names { # class 
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
		} elsif ($input =~ /\w+/) { 	# SQL where clause
			$input =~ s/^\s*WHERE\s*//i;	
			$sql  .= " WHERE $input";	
		}
		@names = $self->base->get_list($sql);
	}								# ALL
	$self->debug(4, "input($input) extra($extra) -> names(@names)") if $DEBUG;

	return @names;
}


=item col 

Gets DISTINCT column, from all or with a where sql statement

	my @all_cols = $o_obj->cols('name');

	my @rel_cols = $o_obj->cols('name, $o_rel);

	my @selected = $o_obj->cols('name', $where);

=cut

sub col { # class 
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
		} elsif ($input =~ /\w+/) { 	# SQL where clause
			$input =~ s/^\s*WHERE\s*//i;	
			$sql  .= " WHERE $input";	
		} 		 						# ALL 
		@cols = $self->base->get_list($sql);
	}	

	$self->debug(4, "col($col), input($input) -> cols(@cols)") if $DEBUG;
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

	$self->debug(4, "ident($ident)") if $DEBUG;
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
		$self->error("no input ids given to convert($a_input)");
	} else {
		if ($self->identifier ne 'name') {
			$self->debug(4, "identifier ne 'name'!") if $DEBUG;
		} else {
			my @input = @{$a_input};
			if (scalar(@input) >= 1) {
				my $input = join("', '", @input);
				my $sql = 
					"SELECT DISTINCT name FROM ".$self->attr('table').
					" WHERE ".$self->attr('primary_key')." IN ('$input')";
				@output = $self->base->get_list($sql);
				$self->debug(3, "given(@input) -> sql($sql) -> output(@output)") if $DEBUG;
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
			$self->debug(3, "input(@input) -> sql($sql) -> output(@output)") if $DEBUG;
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
		$sql .= ' WHERE '.$input->attr('primary_key')." = '".$input->oid()."'";		
		$sql .= " AND $extra" if $extra;
	} elsif ($input =~ /\w+/) { 	# SQL where clause
		$input =~ s/^\s*WHERE\s*//i;	
		$sql  .= " WHERE $input";	
	} 								# ALL

	($i_cnt) = $self->base->get_list($sql);
	$self->debug(4, "input($input) extra($extra) -> i_cnt($i_cnt)") if $DEBUG;

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
			$arg =~ s/^\s+//;
			$arg =~ s/\s+$//;
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
	my ($col) = map { ($_ =~ /^name$/ ? $_ : $pri ) } $self->data_fields ? 'name' : $pri;

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
	# $self->debug(3, "name($name) pop($pop)") if $DEBUG;
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
	my ($col) = map { ($_ =~ /^name$/ ? $_ : $pri ) } $self->data_fields ? 'name' : $pri;

	if (1) { # all - better than foreach id -> SQL 
		my @ids = $self->col("CONCAT($pri, ':', $col)"); 
		foreach my $id (@ids) {
			my ($pre, $post) = split(':', $id);
			$map{$pre} = $post;
		}
	} else {
		my @ids = $self->ids; # all
		foreach my $id (@ids) {
			($map{$id}) = $self->col($col, "WHERE ".$self->attr('primary_key')." = '$id'");
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
	# $self->debug(3, "name($name) sel($sel)") if $DEBUG;
	return $sel;
}


=item textarea 

Create textarea with given args, prep for select(js) 

	my $ta = $o_obj->textarea('unique_name', 'value', [etc.]);

=cut

sub textarea {
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


=item textfield 

Create textfield with given args, prep for select(js) 

	my $tf = $o_obj->textfield('unique_name', 'value', [etc.]);

=cut

sub textfield {
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
	if (map { ($_ =~ /^name$/ ? 1 : 0) } $self->data_fields) { 
		$self->error("can't gen_field_handler($field)!");
    } else {
		my $ref = ref($self);
		$self->debug(3, "setting($ref) field($field) handler...") if $DEBUG;
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

sub base {
	my $self = shift;
	$o_Perlbug_Base = ref($o_Perlbug_Base) ? $o_Perlbug_Base : Perlbug::Base->new(@_);
	return $o_Perlbug_Base; 
}


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


=head1 RELATIONS

Object relations are handled by a group of methods:

	my @rellies 	= $o_obj->relations('to');	# patch, message, note, test, user, 

	my $o_patch     = $o_obj->relation('patch');	# handler

	my @pids	= $o_patch->ids($o_obj);	# or

	my @pids     	= $o_obj->relation_ids('patch');# ids

Note that relations are between one object and (from or to) another, or of a 'floating' kind.

If it's another object you want, see L<"object()">.

=cut


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
	if (defined($type) && $type =~ /\w+/) {
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
			croak("duff rel($rel) for $self!!!");
			$self->error("inappropriate relation($rel) requested from ".ref($self));
		} else {
			my $type = $self->{'_relation'}{$rel}{'type'};
			$o_rel  = $self->base->object($self->key.'->'.$rel, '', $type);
			my $oid = $self->oid;
			$o_rel->set_source($self->key, $self->oid);
			my $rid = $o_rel->oid;
		}
	}	
	$self->debug(4, "rjsf: Object::relation($rel): ".ref($self)." own_key(".$self->attr('key').") rel($rel) rel_key(".$o_rel->attr('key')." o_rel($o_rel)") if $DEBUG;
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
			@ids = $o_rel->ids($self, $args);
			$self->debug(4, "rel($rel) -> o_rel($o_rel) -> ids(".@ids.')') if $DEBUG;
		}
	}	
	return @ids;
}


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
	
	# $self->debug(4, "rel($rel), args($args) -> ids(@ids), names(@names)") if $DEBUG;
	return @names;
}


=head1 RECORDS

Record handling methods for L<Perlbug::Object::\w+>'s


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

sub read { # by id
	my $self = shift;
	my $oid = shift || $self->oid;
	$self->reset; 
	$self->READ(0);
	if ($self->ok_ids([$oid]) != 1) {
		my @caller = caller(1);
		$self->error("requires a valid id($oid) to read against(@caller)");
	} else {
		my $pri	  = $self->attr('primary_key');
		my $table = $self->attr('table');
		my $sql = "SELECT * FROM $table WHERE $pri = '$oid'"; # SQL
		my ($h_data) = $self->base->get_data($sql);
		if (ref($h_data) ne 'HASH') {
			$self->debug(0, "failed to retrieve data($h_data) with $pri = '$oid' in table($table)"); # if $DEBUG
		} else {
			$self->debug(2, $self->key." oid($oid)") if $DEBUG;
			my $res = $self->data($h_data); 			# set
			my $xoid = $self->oid($oid);				# set
=pod
			migrated to format() :-)
			foreach my $rel ($self->relations) {
				my @rids  = $self->rel_ids($rel); 		#
				my @names = $self->rel_names($rel); 	# $self->relation($rel)->id2name(\@rids);
				$self->{'_relation'}{$rel}{'ids'}   = \@rids; # all we need (should never use this?)
				$self->{'_relation'}{$rel}{'count'} =  @rids;	
				$self->{'_relation'}{$rel}{'names'} = \@names;	
			}
=cut
			# $self = $self->object($self->attr('key'), $self); # cache
			$self->READ(1) if $self->exists([$oid]); 	# catchy :)
		}
	}
	# print "Object::read($oid)...<pre>".Dumper($self)."</pre>\n";

	$self;
} 


=item READ 

Returns 0|1 depending on whether object has had a successful read, post new/init/reset

	my $i_isok = $o_obj->READ;

=cut

sub READ {
	my $self = shift;
	my $i_flag = shift || ''; 

	$self->flag({'read', $1}) if $i_flag =~ /^(1|0)$/;	

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

	if (!($col =~ /^\w+$/ && grep(/^$col$/, keys %{$self->{'_type'}}))) {

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
			$self->debug(3, "key($key) type($type) val(".length($val).")") if $DEBUG;
			# $val =~ s/(\&nbsp\;)//gsi;	# trim against duff web updates
			$val =~ s/^\s+(.+)/$1/;	# and so on...
			$val =~ s/(.+)\s+$/$1/;	# and so on...
			if ($type eq 'DATETIME') {
				if ($key =~ /modified/i || ($key =~ /created/i && $control eq 'INSERT')) {
					push(@args, "$key = SYSDATE()");
				} else {
					push(@args, "$key = ".$self->to_date($val));
				}
				$self->debug(3, "DATETIME($val): args(@args)") if $DEBUG;
			} elsif ($type eq 'INTEGER')  {
				push(@args, "$key = $val");
				$self->debug(3, "INTEGER($val): args(@args)") if $DEBUG;
			} else { # default and handles all strings
				push(@args, "$key = ".$self->base->quote($val));
				$self->debug(3, "VARCHAR($val): args(@args)") if $DEBUG;
			}
		}
		$sql = "$do $table SET ".join(', ', @args);
		$self->debug(3, "sql($sql)") if $DEBUG;
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

sub create { # by id from hashref
	my $self = shift;
	my $h_data = shift || $self->_oref('data');
	my $flag   = shift || ''; # anything
	my $sqlclean= shift || '1';
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
				if (!(defined($sth))) {
					$self->error("Failed($oid) to create sql($sql)!");
				} else {	
					$self->CREATED(1);
					$oid = $self->insertid($sth);
					$oid = $self->oid($oid) if $oid =~ /\w+/ && $oid != 0;
					$self->track($sql." -> oid($oid)");
					$self->base->clean_cache('sql');
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

	$self->flag({'created', $1}) if $i_flag =~ /^(1|0)$/;	

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

	$self->flag({'stored', $1}) if $i_flag =~ /^(1|0)$/;	

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

sub update { # by id from hashref
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
				$sth = $self->base->exec($sql);	# DOIT
				if (!(defined($sth))) {
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

	$self->flag({'updated', $1}) if $i_flag =~ /^(1|0)$/;	

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

sub delete { # by id from hashref
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
				$sth = $self->base->exec($sql);	# DOIT
				if (!(defined($sth))) {
					$self->error("Delete($oid) failed: sql($sql)!");
				} else {	
					$self->DELETED(1); 
					$self->track($sql);
					$self->base->clean_cache('sql');
				}	
			}	
		}
		# $self->reset;
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

	$self->flag({'deleted', $1}) if $i_flag =~ /^(1|0)$/;	

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
	
	my $new_oid = $o_obj->insertid($sth);

=cut

sub insertid {
	my $self = shift;
	my $sth = shift;

	my $newid = defined($sth) ? $sth->insertid : '0';	
	$self->debug(0, "newly inserted objectid($newid)") if $DEBUG;

	return $newid;
}


=item web_update

Update object based on web criteria

	my $o_obj = $o_obj->web_update($cgi);

=cut

sub x_web_update {
	my $self = shift;
	my $cgi  = shift || '';

	if (!ref($cgi)) {
		$self->error("require cgi($cgi) object for web update");
	} else {
		print "unsupported method: new_web_updated(@_)<br>\n";
	}

	return $self;
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
	$self->debug(0, "new objectid($newid)") if $DEBUG;
	
	return $newid;
}


=head1 CONVENIENCE

Convenient wrappers for the following methods are supported, for more details see L<Perlbug::Base>


=item error

Wrapper for $o_obj->base->error()

=cut

sub error {
	my $self = shift;
	my $hint = '<'.($self->attr('key')).'>';
	return $self->base->error($hint, @_);
}


=item debug

Wrapper for $o_obj->base->method()

=cut

sub debug { # wrapper 
	my $self = shift;
	# my $ORIG = $Perlbug::DEBUG;
	# $Perlbug::DEBUG = $Perlbug::DEBUG || $DEBUG;	
	$self->base->debug(@_);
	# $Perlbug::DEBUG = $ORIG;	
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

=cut

sub format { # return $self->FORMAT(@_)  
	my $self = shift;
	my $fmt = shift || $self->base->current('format');
	my %map = (
		'a'	=> 5, 	'A'	=> 1, 
		'h'	=> 10, 	'H'	=> 1,
		'i'	=> 1, 	'I'	=> 15,
		'l'	=> 250, 'L'	=> 25,
		'x'	=> 1, 	'X'	=> 1,
	);
	$self->max($map{$fmt}); # !
	foreach my $rel ($self->relations) {
		my @rids  = $self->rel_ids($rel); 		#
		my @names = $self->rel_names($rel); 	# $self->relation($rel)->id2name(\@rids);
		$self->{'_relation'}{$rel}{'ids'}   = \@rids; # all we need (should never use this?)
		$self->{'_relation'}{$rel}{'count'} =  @rids;	
		$self->{'_relation'}{$rel}{'names'} = \@names;	
	}
	return $self->FORMAT($fmt, @_); # Perlbug::FORMAT
}


=item _format

simple wrapper for combined B<read()>, B<format()>, B<print()>

	$o_obj->_format('h');

=cut

sub x_format { # return $self->format(@_)  
	my $self = shift;

	print $self->format(@_);

	return $self; #
}


=item track 

Tracks object administration, where $op may be a sql statement, etc.

	$o_obj = $o_obj->track($sql, 'bug', '<bugoid>');

=cut

sub track {
	my $self = shift;
	my $data = shift || '';
	my $type = $self->key;
	my $oid  = $self->oid;
	
	my $i_tracked = $self->base->track($type, $oid, $data) 
		unless $type =~ /(log|range)/i; # || $type =~ /^pb_[a-z]+_[a-z]+$/); # relly

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

	$self->flag({'tracked', $1}) if $i_flag =~ /^(1|0)$/;	

	$i_flag = $self->flag('tracked');

	return $i_flag;	
}


=item attribute

Get and set attribute

	my $objectid = $o_obj->attribute('objectid');			# get

	my $newobjid = $o_obj->attribute({'objectid', $newid});	# set

=cut

sub attr { my $self = shift; return $self->attribute(@_); } # wrapper for attribute()

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
    return if $meth =~ /::DESTROY$/; 
    $meth =~ s/^(.*):://;
	my $pkg = ref($self);
	my @ret = ();

    if ($meth !~ /^(attribute|data|flag)$/) { # not one of ours :-)
        $self->error("$pkg->$meth($get, @_) called with a duff method($AUTOLOAD)!  Try: 'perldoc $pkg'");
    } else { 
		no strict 'refs';
		*{$AUTOLOAD} = sub {
			my $self = shift;
			my $get  = shift;
			my @ret = ();

			if (ref($self->{"_$meth"}) ne 'HASH') {
				confess("invalid object($pkg) structure($meth): ".Dumper($self));
			} else {	
				my @keys = @ret = keys %{$self->{"_$meth"}}; 	# ref
				if (defined($get)) {
					if (ref($get) ne 'HASH') { 				# get
						@ret = ($self->{"_$meth"}{$get});
					} else {								# set
						my $keys = join('|', @keys);
						@ret = ();
						SET:
						foreach my $key (keys %{$get}) {
							if ($key !~ /^($keys)$/) {
								$self->error("$pkg has no such $meth key($key) valid($keys)");
							} else {
								$self->{"_$meth"}->{$key} = $$get{$key}; # SET
								push(@ret, $$get{$key});
							}
						}
					}
				}
				return wantarray ? @ret : $ret[0];
			}
		}
    }
	return wantarray ? @ret : $ret[0];
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut

1;

