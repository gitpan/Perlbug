# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Category.pm,v 1.5 2001/02/18 12:54:18 perlbug Exp $
#

=head1 NAME

Perlbug::Object::Category - bug category handler

=cut

package Perlbug::Object::Category;

use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.5 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 

=head1 DESCRIPTION

Perlbug bug category class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/..";
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 


=head1 SYNOPSIS

	use Perlbug::Object::Category;

	my $o_Category = Perlbug::Object::Status->new();

	print $o_Category->selector;


=head1 METHODS

=item new

Create new Category object:

	my $o_Category = Perlbug::Object::Category->new();

=cut

sub new {
	my $class  = shift;
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Category',
		'from'		=> [qw(bug)],
		'to'		=> [],
	);


	# warn "rjsf Category: ".Dumper($self);

	bless($self, $class);
}


=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

