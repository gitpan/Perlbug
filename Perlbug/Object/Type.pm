# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Type.pm,v 1.4 2001/03/23 14:36:16 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Thing - Thing class

=cut

package Perlbug::Object::Thing;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.4 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

=head1 DESCRIPTION

Perlbug Thing class.

id(14), name(bug), thing(object|attribute|function), description

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Thing;

	my $o_thing = Perlbug::Object::Thing->new();

	print $o_thing->read('3')->format('a');


=head1 METHODS

=item new

Create new Thing object:

	my $o_thing = Perlbug::Object::Thing->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base,
		'name'		=> 'Thing',
		'from'		=> [qw()],
		'to'		=> [qw()],
	);

	# warn "rjsf Thing: ".Dumper($self);

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

