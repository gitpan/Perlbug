# Perlbug bug record handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Test.pm,v 1.21 2002/01/11 13:51:05 richardf Exp $
#

=head1 NAME

Perlbug::Object::Test - Test class

=cut

package Perlbug::Object::Test;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.21 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
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

	bless($self, $class);
}

=item webupdate

Update group via web interface

	my $oid = $o_grp->webupdate(\%cgidata, $gid);

=cut

sub webupdate {
	my $self   = shift;
	my $h_data = shift;
	my $oid    = shift;
    my $cgi    = $self->base->cgi();

	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires data hash ref($h_data) to update object data via the web!");
	} else {
		if (!($self->ok_ids([$oid]))) {
			$self->error("No groupid($oid) for webupdate!".Dumper($h_data));
		} else {
			$self->read($oid);
			if ($self->READ) {
				my $desc = $cgi->param($oid.'_description') || '';
				my $name = $cgi->param($oid.'_name') || '';
				my $opts = $cgi->param($oid.'_opts') || $cgi->param('opts') || '';
				$self->update({
					'name'			=> $name,
					'description' 	=> $desc,
				});
				my $pars = join(' ', $opts, $self->rel_ids('bug'));
				my %cmds = $self->base->parse_str($pars);
				$self->relate(\%cmds);
			}
		}
	}	
	
	return $oid;
}



=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut


# 
1;

