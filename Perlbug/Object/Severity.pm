# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Severity.pm,v 1.8 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Severity - bug severity handler 

=cut

package Perlbug::Object::Severity;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Severity_DEBUG'} || $Perlbug::Object::Severity::DEBUG || '';
$|=1;


=head1 DESCRIPTION

Perlbug bug severity class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Severity;

	my $o_Severity = Perlbug::Object::Severity->new();

	print $o_Severity->selector


=head1 METHODS

=item new

Create new Severity object:

	my $o_Severity = Perlbug::Object::Severity->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Severity',
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

