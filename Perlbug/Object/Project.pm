# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Project.pm,v 1.5 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Project - Project class

=cut

package Perlbug::Object::Project;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.5 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Project_DEBUG'} || $Perlbug::Object::Project::DEBUG || '';
$|=1;

=head1 DESCRIPTION

Perlbug Project class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Project;

	my $o_proj = Perlbug::Object::Project->new();

	print $o_proj->read('1003')->format('a');


=head1 METHODS

=item new

Create new Project object:

	my $o_proj = Perlbug::Object::Project->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base,
		'name'		=> 'Project',
		'from'		=> [qw()],
		'to'		=> [qw(bug)],
		'type'		=> 'prejudicial',
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 
	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;

