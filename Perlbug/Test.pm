# $Id: Test.pm,v 1.4 2000/08/10 10:49:38 perlbug Exp $ 

=head1 NAME

Perlbug::Test - Perlbug test module placeholder

=cut

package Perlbug::Test;
BEGIN { $|=1; }
use Data::Dumper;
use Exporter;
use Test;
use File::Spec; 
use lib File::Spec->updir;
use strict;
use vars qw($VERSION);
$VERSION = 1.05


=head1 DESCRIPTION

x

=head1 SYNOPSIS

    y
	

=head1 METHODS

=over 4

=item new

Create new Perlbug::Test object:

    my $o_test = Perlbug::Test->new();				# generic

	my $o_email_test = Perlbug::Test->new('Email'); # guess :-)

=cut

sub new {
    my $class = shift;
	my $self  = {};
    bless($self, $class);
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;
