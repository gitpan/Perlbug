# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Version.pm,v 1.10 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Version - version handler 

=cut

package Perlbug::Object::Version;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.10 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Version_DEBUG'} || $Perlbug::Object::Version::DEBUG || '';
$|=1;


=head1 DESCRIPTION

Perlbug version class handler

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Version;

	my $o_version = Perlbug::Object::Version->new();

	print $o_version ->read('3')->format('a');


=head1 METHODS

=item new

Create new Version object:

	my $o_version = Perlbug::Object::Version->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Version',
		'from'		=> [qw(bug patch test)],
		'to'		=> [],
		'type'		=> 'prejudicial',
		@_,
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

