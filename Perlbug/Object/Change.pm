# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Change.pm,v 1.11 2001/08/20 18:57:31 mstevens Exp $
#

=head1 NAME

Perlbug::Object::Change - change id class handler

=cut

package Perlbug::Object::Change;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.11 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

=head1 DESCRIPTION

Perlbug change id class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Change;

	my $o_Change = Perlbug::Object::Flag->new();

	print $o_Change->read('444')->format('a');


=head1 METHODS

=over 4

=item new

Create new Change object:

	my $o_Change = Perlbug::Object::Flag->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Change',
		'from'		=> [qw(bug patch)],
		'to'		=> [],
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

