# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Status.pm,v 1.8 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Status - bug status handler

=cut

package Perlbug::Object::Status;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Status_DEBUG'} || $Perlbug::Object::Status::DEBUG || '';
$|=1;


=head1 DESCRIPTION

Perlbug bug status class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Status;

	my $o_Status = Perlbug::Object::Status->new();

	print $o_Status->selector;


=head1 METHODS

=item new

Create new Status object:

	my $o_Status = Perlbug::Object::status->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Status',
		'from'		=> [qw(bug)],
		'to'		=> [],
		'type'		=> 'prejudicial',
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

