# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Test.pm,v 1.17 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Test - Test class

=cut

package Perlbug::Object::Test;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.17 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Test_DEBUG'} || $Perlbug::Object::Test::DEBUG || '';
$|=1;

=head1 DESCRIPTION

Perlbug test class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Test;

	my $o_test = Perlbug::Object::Test->new();

	print $o_test->read('1003')->format('a');


=head1 METHODS

=item new

Create new Test object:

	my $o_test = Perlbug::Object::Test->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base,
		'name'		=> 'Test',
		'from'		=> [qw(bug)],
		'to'		=> [qw(version)],
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;

