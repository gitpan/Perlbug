# Perlbug bug parent handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Parent.pm,v 1.11 2001/08/20 18:57:31 mstevens Exp $
#

=head1 NAME

Perlbug::Object::Parent - Bug class

=cut

package Perlbug::Object::Parent;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.11 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;


=head1 DESCRIPTION

Perlbug bug parent class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use HTML::Entities;
use Perlbug::Base;
use Perlbug::Object::Bug;
@ISA = qw(Perlbug::Object::Bug); 

my %fmt = ();


=head1 SYNOPSIS

	use Perlbug::Object::Parent;

	print Perlbug::Object::Parent->new()->read('19990127.003')->format('a');


=head1 METHODS

=over 4

=item new

Create new Parent object:

	my $o_pa = Perlbug::Object::Parent->new();

Object references are returned with most methods, so you can 'chain' the calls:

	print $o_pa ->read('198700502.007')->format('h'); 

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object::Bug->new( $o_base, 
		'hint'		=> 'Parent',
	);
	bless($self, $class);

	return $self;
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut


# 
1;

