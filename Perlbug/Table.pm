# Perlbug Table access  
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: Table.pm,v 1.1 2000/11/27 08:00:48 perlbug Exp $ 
#

package Perlbug::Table;
my $VERSION = 1.00;
@ISA = qw(Perlbug::Database);
use strict;
use lib qw(..);
use Perlbug::Database;


=head1 NAME 

Perlbug::Table - Table access

=head1 DESCRIPTION

Simple access to all database tables

=head1 USAGE

	my $o_bug = $Perlbug::Table->new('BUG', 'ticketid');

	print "Our table has ".$o_bug->columns." columns\n";
		
	my $h_data = $o_bug->fetch($bug_id);
	
	print "Bug subject: ->$$h_data{'subject'}<- \n";


=head1 METHODS

=item new

Call with table name

	my $o_message = $Perlbug::Table->new('MESSAGE', 'primarykey');

If 'primarykey' is not given, it will be built from "ref($class).'ID'": no support for multiple column primary key combos, yet.

=cut

sub new {
	my $class = shift;
	my $key = shift || $class.'id';
	my $self = {
		'attributes' => {},
		'identifier' => '',
		'primary_key'=> uc($key),
		'records'	 => {},
		'tablename'  => uc($class),
		'values'	 => {},
	};
	bless($self, $class);
	$self->{'attributes'} = $self->setup($class);
	return $self;
}

sub attributes { # wrapper
	return $_[0]->{'attributes'};
}
sub columns {    # wrapper
	return keys %{$_[0]->{'attributes'}};
}
sub identifier { # wrapper
	return $_[0]->{'identifier'}; 
}
sub primary_key { # wrapper
	return $_[0]->{'primary_key'}; 
}
sub records  {   # get and set
	my $self = shift;
	my @recs = @_;
	if (scalar(@recs) >= 1) {
		REC:
		foreach my $h_rec (@recs) {
			next REC unless ref($h_rec) eq 'HASH';
			my $key = $self->primary_key;
			if (defined($$h_rec{$key}) && $$h_rec{$key} =~ /\w+/) {
				$self->{'records'}{$$h_rec{$key}} = $h_rec;
			} else {
				$self->debug(0, "Can't assign record using non-existent primary($key):".Dumper($h_rec));
			}
		}
	}
	return (wantarray ? @{$self->{'records'}} : $self->{'records'}{$_[1]}); 
}
sub tablename  { # wrapper
	return $_[0]->{'tablename'}; 
}
sub values {     # wrapper
	return (wantarray ? @{$_[0]->{'values'}} : $_[0]->{'values'}{$_[1]}); 
}

sub setup { # object
	my $self = shift;
	$self->debug('IN', @_);
	my $table = shift || '';
	my %data = ();
    my @fields = $self->get_data("SHOW fields FROM $table"); # Mysql specific!
	# "SELECT * FROM $table WHERE 1 = 0";
    foreach my $f (@fields) {
        next $f unless ref($f) eq 'HASH';
		my %f = %{$f};
		foreach my $key (qw(Field Type Null Key Default)) {
			$f{$key} = '' unless defined($f{$key});
		}
       	$data{$f{'Field'}} = $f;
    }
	$self->debug('OUT', Dumper(\%data));
	return \%data;
}

sub insert { # this data
	my $self = shift;
	$self->debug('IN', @_);
	my %data = @_;
	my $i_cnt = 0;
	# 
	$self->debug('OUT', $i_cnt);
	return $i_cnt;
}

sub select { # by where
	my $self = shift;
	$self->debug('IN', @_);
	my %data = @_;
	my $i_cnt = 0;
	# 
	$self->debug('OUT', $i_cnt);
	return $i_cnt;
}

sub read {
	return $_[0]->fetch(@_);
}

sub fetch {  # by id (read)
	my $self 	= shift;
	$self->debug('IN', @_);
	my $id 		= shift;
	my $h_data = {};
	if ($id =~ /\w+/) {
		$self->identifier($id);
		$h_data = $self->get_list( ... );
	} else {
		$self->debug(0, "requires an identifier($id)");
	}
	$self->debug('OUT', $i_cnt);
	return $i_cnt;
}

sub update { # this data, where
	my $self 	= shift;
	$self->debug('IN', @_);
	my $h_data 	= shift;
	my $where 	= shift || '';
	my $data 	= $self->gen_update($h_data);
	my $sql 	= "UPDATE ".ref($self)." SET $data ".$self->where($where); 
	my $i_cnt 	= $self->exec($sql);
	$self->debug('OUT', $i_cnt);
	return $i_cnt;
}

sub delete { # by id/where
	my $self = shift;
	$self->debug('IN', @_);
	my $where 	= shift || '';
	my $sql = "DELETE FROM ".ref($self).$self->where($where); 
	my $i_cnt = $self->exec($sql);
	$self->debug('OUT', $i_cnt);
	return $i_cnt;
}

sub where { # by id/where
	my $self = shift;
	$self->debug('IN', @_);
	my $args = shift || ''; 
	my $where = "WHERE ".(($args =~ /\w+/) ? $args : $self->primary_key." = '".$self->identifier."'");
	$self->debug('OUT', $where);
	return $where;
}

sub attr {   # by name
	my $self = shift;
	$self->debug('IN', @_);
	my $attr = shift;
	my $data = '';
	if (grep(/^$attr$/i, $self->columns)) {
		if (defined($self->{'attribute'}{$attr})) {
			$data = $self->{'attribute'}{$attr};
		} else {
			($data) = $self->get_list(
				"SELECT $attr FROM ".ref($self).' '.$self->where
			);
		}
	} else {
		$self->debug(0, ref($self)." has no such attribute($attr)");
	}
	$self->debug('OUT', $data);
	return $data;
}

1;
