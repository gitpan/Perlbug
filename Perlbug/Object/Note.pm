# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Note.pm,v 1.16 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Note - Note class

=cut

package Perlbug::Object::Note;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.16 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Note_DEBUG'} || $Perlbug::Object::Note::DEBUG || '';
$|=1;


=head1 DESCRIPTION

Perlbug note class.

For inherited methods, see L<Perlbug::Object::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object);


=head1 SYNOPSIS

	use Perlbug::Object::Note;

	my $o_note = Perlbug::Object::Note->new();

	print $o_note->read('503')->format('a');


=head1 METHODS

=item new

Create new Note object:

	my $o_note = Perlbug::Object::Note->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'note',
		'from'		=> [qw(bug)],
		'to'		=> [qw()],
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;
