# Perlbug javascript routines
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: Utility.pm,v 1.1 2001/12/01 15:24:42 richardf Exp $
#   

=head1 NAME

Perlbug::Utility - Object handler for Utility methods

=cut

package Perlbug::Utility;
use Data::Dumper;
use HTML::Entities;
use strict;
use vars qw(@ISA $VERSION);
$VERSION  = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$| = 1; 

use CGI;


=head1 DESCRIPTION

Utility wrapper for Perlbug modules usage

=cut


=head1 SYNOPSIS

	use Perlbug::Utility;

	print Perlbug::Utility->new()->dump;

=cut


=head1 METHODS

=over 4

=item new

Create new Perlbug::Utility object.

	my $o_ute = Perlbug::Utility->new;

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 

	bless({}, $class);
}


=item dump

Wraps Dumper() and dumps given args

	print $o_ute->dump($h_data);

=cut

sub dump {
	my $self = shift;
	my @args = @_;
	my $res  = "rjsf dump: \n";

	my $i_cnt = 0;
	foreach my $arg (@args) {
		$res .= "\t$i_cnt($arg): ".Dumper(\$arg);
		$i_cnt++;
	}
	$res .= "\n";

	return $res;
}


=item html_dump

Encodes and dumps given args

	print $o_ute->html_dump($h_data);

=cut

sub html_dump {
	my $self = shift;
	my @args = @_;
	my $res  = "<table>\n<tr><td>rjsf html_dump: </td></tr>\n";

	my $i_cnt = 0;
	foreach my $arg (@args) {
		$res .= qq|<tr><td>$i_cnt($arg): <pre>|.Dumper($arg).qq|&nbsp;</pre></td></tr>\n|;	
		$i_cnt++;
	}
	$res .= "</table>\n";

	return $res;
}


=cut

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2001

=cut

1
