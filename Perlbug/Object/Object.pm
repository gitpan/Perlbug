# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Object.pm,v 1.6 2001/08/20 18:57:31 mstevens Exp $
#

=head1 NAME

Perlbug::Object::Object - application Object type 

=cut

package Perlbug::Object::Object;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.6 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;


=head1 DESCRIPTION

Perlbug Object class, types and application of objects in application.

id(14), name(bug), thing(object|attribute|function), description

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Object;

	my $o_thing = Perlbug::Object::Object->new();

	print $o_thing->read('3')->format('a');


=head1 METHODS

=over 4

=item new

Create new Object object:

	my $o_thing = Perlbug::Object::Object->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base,
		'name'		=> 'Object',
		'from'		=> [qw()],
		'to'		=> [qw()],
	);

	bless($self, $class);
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

