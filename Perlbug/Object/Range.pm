# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Range.pm,v 1.11 2002/01/14 10:14:48 richardf Exp $
#

=head1 NAME

Perlbug::Object::Range - Range class

=cut

package Perlbug::Object::Range;
use strict;
use vars qw(@ISA $VERSION);
$VERSION = do { my @r = (q$Revision: 1.11 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
@ISA = qw(Perlbug::Object); 
$|=1;

=head1 DESCRIPTION

Perlbug Range class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use Perlbug::Base;
use Perlbug::Object;


=head1 SYNOPSIS

	use Perlbug::Object::Range;

	my $o_rng = Perlbug::Object::Range->new();

	print $o_rng->read('123');


=head1 METHODS

=over 4

=item new

Create new Range object:

	my $o_rng = Perlbug::Object::Range->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Range',
		'from'		=> [qw()],
		'to'		=> [qw(bug)],
		'track'		=> 0,
	);

	bless($self, $class);
}

=item rangeify

Return a string representing the shortened (ranged) version of the given list

	my $str = $o_rng->rangeify(\@list); # qw(1 3 4 6 123) -> '1,3-6,123'

=cut

sub rangeify {
	my $self   = shift;
	my $a_data = shift;
	my $range  = '';

	if (ref($a_data) ne 'ARRAY') {
		$self->error("require an array ref($a_data) to rangeify");
	} else {
		my %rng = ();
		RANGE:
		foreach my $i (sort { $a <=> $b } @{$a_data}) {
			next RANGE unless $i =~ /^[\w\.*]+$/io;
			$rng{$i} = $i;
			RNG:
			foreach my $key (sort { $a <=> $b } keys %rng) {
				if ($rng{$key} == $i - 1) {
					$rng{$key} = $i;
					delete $rng{$i};
					last RNG;
				}
			}
		}
		$range = join(',', sort { $a <=> $b } map { $_.'-'.$rng{$_} } keys %rng);
	}
	$self->debug(3, "given(".@{$a_data}.") -> range($range)") if $Perlbug::DEBUG;

	return $range;
}

=item derangeify

Return a list from the shortened (ranged) string from the db

	my @list = $o_rng->derangeify($string); # '1,3-6,123' -> [(1 3 4 6 123)]

=cut

sub derangeify {
	my $self  = shift;
	my $range = shift;
	my @range = ();

	if ($range !~ /\w+/) {
		$self->debug(1, "nothing to derangeify($range)") if $Perlbug::DEBUG;
	} else {
		RANGE:
		foreach my $i (split(',\s*', $range)) {
			next RANGE unless $i =~ /^[\w\.*]+\-[\w\.*]+$/io;
			my ($start, $finish) = split('-', $i);
			push(@range, $start..$finish);
		}
	}
	$self->debug(3, "given($range) -> range(@range)") if $Perlbug::DEBUG;

	return \@range;
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut


# 
1;

