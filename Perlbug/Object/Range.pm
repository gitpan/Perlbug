# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Range.pm,v 1.8 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Range - Range class

=cut

package Perlbug::Object::Range;
use strict;
use vars qw(@ISA $VERSION);
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
@ISA = qw(Perlbug::Object); 
my $DEBUG = $ENV{'Perlbug_Object_Range_DEBUG'} || $Perlbug::Object::Range::DEBUG || '';
$|=1;

=head1 DESCRIPTION

Perlbug Range class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;


=head1 SYNOPSIS

	use Perlbug::Object::Range;

	my $o_rng = Perlbug::Object::Range->new();

	print $o_rng->read('123');


=head1 METHODS

=item new

Create new Range object:

	my $o_rng = Perlbug::Object::Range->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Range',
		'from'		=> [qw()],
		'to'		=> [qw(bug)],
		'track'		=> 0,
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

