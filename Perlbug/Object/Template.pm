# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Template.pm,v 1.5 2001/04/21 20:48:48 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Template - Template class

=cut

package Perlbug::Object::Template;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.5 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Object_Template_DEBUG'} || $Perlbug::Object::Template::DEBUG || '';
$|=1;


=head1 DESCRIPTION

Perlbug Template class.

Each B<User> may B<Template> each B<Object>

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Template;

	my $o_template = Perlbug::Object::Template->new();

	print $o_template->read('1003')->format('a');


=head1 METHODS

=item new

Create new Template object:

	my $o_template = Perlbug::Object::Template->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base,
		'name'		=> 'Template',
		'from'		=> [qw()],
		'to'		=> [qw()],
	);

	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

