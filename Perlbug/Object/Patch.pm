# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Patch.pm,v 1.16 2001/08/20 18:57:31 mstevens Exp $
#

=head1 NAME

Perlbug::Object::Patch - Patch class

=cut

package Perlbug::Object::Patch;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.16 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;


=head1 DESCRIPTION

Perlbug patch class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Patch;

	my $o_patch = Perlbug::Object::Patch->new($o_perlbug);

	print $o_patch->read('19990127.003')->format('a');


=head1 METHODS

=over 4

=item new

Create new Patch object:

	my $o_patch = Perlbug::Object::Patch->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base,
		'name'		=> 'Patch',
		'from'		=> [qw(bug)],
		'to'		=> [qw(change version)],
	);

	bless($self, $class);
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;

