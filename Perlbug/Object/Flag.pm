# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Flag.pm,v 1.12 2001/03/05 09:16:25 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Flag - Flag class

=cut

package Perlbug::Object::Flag;
$VERSION = do { my @r = (q$Revision: 1.12 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 

=head1 DESCRIPTION

Perlbug bug class.

For inherited methods, see L<Perlbug::Object>

=cut

use File::Spec; 
use lib (File::Spec->updir);
use Perlbug::Base;
use Perlbug::Object;
use Data::Dumper;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Flag;

	my $o_flag = Perlbug::Object::Flag->new();

	print $o_flag->read('category')->format('a');


=head1 METHODS

=item new

Create new Flag object:

	my $o_flag = Perlbug::Object::Flag->new();

=cut

sub new {
	my $class  = shift;
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Flag',
		'float'		=> [],
		'from'		=> [],
		'to'		=> [],
	);


	# warn "rjsf Flag: ".Dumper($self);

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;

