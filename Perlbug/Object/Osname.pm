# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Osname.pm,v 1.10 2001/08/20 18:57:31 mstevens Exp $
#

=head1 NAME

Perlbug::Object::Osname - osname handler 

=cut

package Perlbug::Object::Osname;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.10 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

=head1 DESCRIPTION

Perlbug bug osname handler class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Osname;

	my $o_Osname = Perlbug::Osname->new();

	print $o_Osname->selector


=head1 METHODS

=over 4

=item new

Create new Osname object:

	my $o_Osname = Perlbug::Object->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Osname',
		'from'		=> [qw(bug)],
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

