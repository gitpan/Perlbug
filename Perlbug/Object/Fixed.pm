# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Fixed.pm,v 1.8 2001/08/20 18:57:31 mstevens Exp $
#

=head1 NAME

Perlbug::Object::Fixed - Fixed in Version handler 

=cut

package Perlbug::Object::Fixed;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;


=head1 DESCRIPTION

Perlbug B<Fixed> in B<Version> class handler

For inherited methods, see L<Perlbug::Object::Version>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object::Version;
@ISA = qw(Perlbug::Object::Version); 


=head1 SYNOPSIS

	use Perlbug::Object::Fixed;

	my $o_Fixed = Perlbug::Object::Fixed->new();

	print $o_Fixed ->read('3')->format('a');


=head1 METHODS

=over 4

=item new

Create new Fixed object:

	my $o_Fixed = Perlbug::Object::Fixed->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object::Version->new( $o_base, 
		'hint'		=> 'Fixed',
		# 'from'		=> [qw(bug patch test)],
		@_,
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

