# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Version.pm,v 1.14 2002/01/11 13:51:05 richardf Exp $
#

=head1 NAME

Perlbug::Object::Version - version handler 

=cut

package Perlbug::Object::Version;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.14 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
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

=over 4

=item new

Create new Version object:

	my $o_version = Perlbug::Object::Version->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'			=> 'Version',
		'from'			=> [qw(bug patch test)],
		'match_name'	=> '([\d+\.]+\d+)',
		'prejudicial'	=> 1,
		'to'			=> [],
		@_,
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

