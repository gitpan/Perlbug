# Perlbug object attributes handler
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: Attributes.pm,v 1.1 2000/08/16 12:31:22 perlbug Exp $
#

package Perlbug::Attributes;
my $VERSION = 1.01;
use lib qw(..);
use Perlbug::Base;
@ISA = qw(Perlbug::Base); 
use strict;


=item new

Create a new object

=cut

sub new { # table, key
	my $class = shift;
	my $table = shift;
	my $key   = shift;
	my $self = {
		'data'  => undef,
		'def'   => \&setup($table, @_), 
		'id'    => undef,
		'key'   => lc($key),
		'table' => lc($table),
	};
	bless ($self, $class);
}


=item setup

Setup generic object attributes based on table from db.

=cut

sub setup { # generic attributes from db
	my $self = shift;
	$self->debug('IN', @_);
	my $table = shift;
	my $rels = @_;
	my $h_data = {};
	if ($table !~ /\w+/) {
		$self->debug(0, "requires table($table) to find attributes");
	} else {
		my @fields = $self->get_list("SHOW fields FROM $table"); # Mysql specific?
		foreach my $f (@fields) {
    		if (ref($f) eq 'HASH') {
				$$h_data{'field'} = lc($${'Field'}) || ''; 
				# qw(Field Type Null Key Default))
			}
    	}
	}
	$self->debug('OUT', $h_data);
	return $h_data;
}


=item attr

Returns the value of the given attribute.

In array context returns the names of all valid attributes.

=cut

sub attr { # get | set
	my $self = shift;
	$self->debug('IN', @_);
	my $attr = shift;
	my @data = ();
	if ($attr !~ /\w+/) {
		$self->debug(1, "no attr($attr) returning all attribute names");
		@data = keys %{$self->{'def'}};
	} else {
		if (!(grep(/^$attr$/, keys %{$self->{'def'}}))) {
			$self->debug(0, "unknown attribute($attr)");
		} else {
			if (defined($self->{'id'})) {
				@data = @{$self->{'data'}{$attr}};
				$self->debug(0, "allocating data(@data) from id(".$self->{'id'}.")");	
			} else {
				$self->debug(0, "possibly unprimed -> fetch(".$self->{'id'}.")?");
			}
		}
	}
	$self->debug('OUT', @data);
	return (wantarray ? @data : $data[0]);
}


=item data

Returns copy of complete object data as a hashref

=cut

sub data { # current copy
	my $self = shift;
	$self->debug('IN', @_);
	my %data = ();
	if (ref($self->{'data'}) ne 'HASH') {
		$self->debug(0, "has no data");
	} else {
		%data = %{$self->{'data'}};
	}
	$self->debug('OUT', \%data);
	return \%data;
}


=item fetch

Retrieve the data from the db, by id, and load into current object, return 0|1 

=cut

sub fetch { # by id
	my $self = shift;
	$self->debug('IN', @_);
	my $id = shift;
	my $i_ok = 1;
	$self->{'data'} = undef;
	if ($id !~ /\w+/) {
		$i_ok = 0;
		$self->debug(1, "requires a valid id($id) for type(".$self->{'type'}.")");
	} else {
		my ($table, $key) = ($self->{'table'}, $self->{'key'});
		my $get = "SELECT * FROM $table WHERE $key = '$id'";
		my ($h_data) = $self->get_data($get);
		if (ref($h_data) eq 'HASH') {
			$self->{'id'} = $id;
			$self->{'data'} = $h_data;
			$self->debug(2, "retrieved data($h_data) with id($id)");
		} else {
			$i_ok = 0;
			$self->debug(0, "failed to retrieve data($h_data) with id($id)");
		}
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item store

Stores the given data from the db, by new id, and load into current object, return 0|1 

=cut

sub store { # by id from hashref
	my $self = shift;
	$self->debug('IN', @_);
	my $h_data = shift;
	my $i_ok = 1;
	$self->{'data'} = undef;
	if (ref($h_data) ne 'HASH') {
		$i_ok = 0;
		$self->debug(1, "requires a hashref($h_data) for the db");
	} else {
		my $ident = $self->{'key'};
		my $id = $$h_data{$ident};
		if ($id !~ /\w+/) {
			$i_ok = 0;
			$self->debug(1, "requires a valid id($id) for type(".$self->{'type'}.") to store");
		} else {
			my ($table, $key) = ($self->{'table'}, $self->{'key'});
			my $data = 'nothing to store($id) yet';	
			if ($self->existsindb) { # update
				my $current = $self->gen_update(%$h_data);
				$data = "UPDATE $table SET $current WHERE $key = '$id'";
			} else { # insert
				my $current = $self->gen_insert(%$h_data);
				$data = "INSERT INTO $table $current";
			}	
			my $sth = $self->exec($data);
			if (defined($sth)) {
				$self->debug(0, "data($h_data) with id($id) looks OK ($sth)");
				$self->{'id'} = $id;
				$i_ok = $self->fetch($id); # reload
			} else {
				$i_ok = 0;
				$self->debug(0, "failed to store data($h_data) with id($id)");

			}
		}
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

1;
