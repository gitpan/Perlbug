# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net 
# $Id: Address.pm,v 1.13 2001/08/20 18:57:30 mstevens Exp $
#

=head1 NAME

Perlbug::Object::Address - address handler

=cut

package Perlbug::Object::Address;

use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.13 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 


=head1 DESCRIPTION

Perlbug address class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Address;

	my $o_addr = Perlbug::Object::Address->new();

	print $o_addr->selector;


=head1 METHODS

=over 4

=item new

Create new Address object:

	my $o_addr = Perlbug::Object::Address->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Address',
		'from'		=> [qw(bug group)],
		'to'		=> [],
	);

	bless($self, $class);
}


=item FORMAT_a

Default ascii format, inc. message body

	my ($top, $format, @args) = $o_msg->FORMAT_a(\%data);

=cut

sub FORMAT_a { # default where format or method missing!
	my $self = shift;
	my $x    = shift; # 
	my $obj_key_oid = ucfirst($self->attr('key')).' ID';
	$obj_key_oid .= (' ' x (12 - length($obj_key_oid)));
	my $pri  = $self->attr('primary_key');
	my @args = ( 
		$$x{$pri}, $$x{'bug_count'}, $$x{'created'}, $$x{'name'},
	);
	my $top = qq|
$obj_key_oid  Bugids  Created            |;
	my $format = qq|
@<<<<<<<<<<<  @<<<<<  @<<<<<<<<<<<<<<<<  
@*
|;
	return ($top, $format, @args);
}


=item FORMAT_A

Default ascii format, inc. message body

	my ($top, $format, @args) = $o_msg->FORMAT_a(\%data);

=cut

sub FORMAT_A { # default where format or method missing!
	my $self = shift;
	my $x    = shift; # 
	my $obj_key_oid = ucfirst($self->attr('key')).' ID';
	$obj_key_oid .= (' ' x (12 - length($obj_key_oid)));
	my $pri  = $self->attr('primary_key');
	my @args = ( 
		$$x{$pri}, $$x{'bug_count'}, $$x{'created'}, $$x{'name'},
		$$x{'bug_ids'},
	);
	my $top = qq|
$obj_key_oid  Bugids  Created            |;
	my $format = qq|
@<<<<<<<<<<<  @<<<<<  @<<<<<<<<<<<<<<<<  
@*
@*
|;
	return ($top, $format, @args);
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

