# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Osname.pm,v 1.8 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Osname - osname handler 

=cut

package Perlbug::Object::Osname;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Osname_DEBUG'} || $Perlbug::Object::Osname::DEBUG || '';
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

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

