# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Message.pm,v 1.18 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Message - Message class

=cut

package Perlbug::Object::Message;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.18 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Message_DEBUG'} || $Perlbug::Object::Message::DEBUG || '';
$|=1;

=head1 DESCRIPTION

Perlbug bug class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Message;

	my $o_msg = Perlbug::Object::Message->new();

	print $o_msg->read('123')->format('a');


=head1 METHODS

=item new

Create new Message object:

	my $o_msg = Perlbug::Object::Message->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Message',
		'from'		=> [qw(bug)],
		'to'		=> [qw()],  #
	);
	
	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;

