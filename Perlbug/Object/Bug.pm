# $Id: Bug.pm,v 1.44 2002/01/25 16:12:59 richardf Exp $
#

=head1 NAME

Perlbug::Object::Bug - Bug class

=cut

package Perlbug::Object::Bug;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.44 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

my %fmt = ();

=head1 DESCRIPTION

Perlbug bug class.

For inherited methods, see L<Perlbug::Object>

=cut

use Data::Dumper;
use HTML::Entities;
use Perlbug::Base;
use Perlbug::Object;
@ISA = qw(Perlbug::Object); 

=head1 SYNOPSIS

	use Perlbug::Object::Bug;

	print Perlbug::Object::Bug->new()->read('19990127.003')->format('a');

=head1 METHODS

=over 4

=item new

Create new Bug object:

	my $o_bug = Perlbug::Object::Bug->new();

Object references are returned with most methods, so you can 'chain' the calls:

	print $o_bug->read('198700502.007')->format('h'); 

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_base = (ref($_[0])) ? shift : Perlbug::Base->new;

	my $self = Perlbug::Object->new( $o_base, 
		'name'		=> 'Bug',
		'match_oid'	=> '(\d{8}\.\d{3})',
		'match_name'=> '(\d{8}\.\d{3})',
		'from'		=> [qw(group project range user)],
		'to'		=> [qw(
			address change child fixed message note osname parent patch severity status test version
		)],
	);

	bless($self, $class);
}

=item new_id

Generate new_id for perlbug bug

	my $new_id = $o_bug->new_id;

=cut

sub new_id {
    my $self  = shift;

    my $today  = $self->base->get_date();
	my $newid  = "$today.001";
	my @extant = ($self->base->get_list("SELECT max(bugid) FROM pb_bug"), $self->base->extant);
	my ($max)  = sort { $b <=> $a } @extant;
	if ($max =~ /^(\d{8})\.(\d{3})$/o) {
		my $num = ($1 eq $today) ? $2 + 1 : 1;
		$newid = $today.'.'.sprintf("%03d", $num);
		if (grep(/^$newid$/, @extant)) {
			$newid = $today.'.'.sprintf("%03d", $num + 1);
		} # parent/child fix
		if ($num >= 999) {
			$self->error("Ran out of bug ids today ($today) at: '$newid'");
		}
	}
	$self->debug(1, "today($today), extant(@extant) max($max) => newid($newid)") if $Perlbug::DEBUG;
	$self->base->extant($newid);

    return $newid;
}

=item get_id

Determine if the string contains a valid bug ID.

    my ($ok, $tid) = $obj->get_id($str);

=cut

sub get_id {
    my $self = shift;
    my $str = shift;
    my ($ok, $id) = (0, '');
    # /^\[[ID]*\s*(\d{8}\.\d{3})\s*\]$/ -> brackets ...?
    if ($str =~ /(\d{8}\.\d{3})/o) { # no \b while _ is a letter?
        $id = $1;
        $ok = 1;
    }
    $self->debug(3, "str($str) -> $ok ($id)") if $Perlbug::DEBUG;
    return ($ok, $id);
}

=item htmlify 

html formatter for individual bug entries for placement

    my $h_bug = $o_bug->htmlify($h_bug);

See also L<Perlbug::Object::htmlify()>

=cut

sub htmlify {
    my $self = shift;
    my $h_bug= shift;
	my $req  = shift || 'admin';
	return undef unless ref($h_bug) eq 'HASH';
    # $self->debug(3, $self->base->dump($h_bug)) if $Perlbug::DEBUG;
    my $cgi = $self->base->cgi();
    my $url = $self->base->myurl;
    my %bug = %{$h_bug};
    my $bid = $bug{'bugid'}; # save for bid usage
	# print $self->base->html_dump($h_bug);

	# messages
    my @mids = (ref($bug{'message_ids'}) eq 'ARRAY') ? @{$bug{'message_ids'}} : ($bug{'message_ids'});
	$bug{'message_ids'} = \@mids;
	my $allmsgs = 'no msgs';
	if (scalar(@mids) >= 1) {
		my $cnt = @mids;
		my $msgs = (@mids == 1) ? "($cnt msg)" : "($cnt msgs)";
		my $stat_msgs = "$cnt messages for bug($bid)";
		($allmsgs) = $self->href('bidmid', [$bid], $msgs, $stat_msgs);
	}

	%bug = %{$self->SUPER::htmlify($h_bug)};	
	$bug{'bugid'}     =~ s/format=h/format=H/;
    $bug{'bugid'}    .= " &nbsp; $allmsgs";
	my $stat_hist = "History for bug($bid)";
    ($bug{'history'}) = $self->href('hist', [$bid], 'History', $stat_hist);
	$bug{'newstuff'}  = '';

	foreach my $item (qw(children parent)) {
		$item = $item.'_ids';
		my @items = (ref($$h_bug{$item}) eq 'ARRAY') ? @{$$h_bug{$item}} : ($$h_bug{$item});
		if (scalar @items>= 1) {
			my $stat_item = $item."(".@items.") for bug($bid)";
			($bug{$item}) = join(', ', $self->href('bug_id', \@items, $item, $stat_item));
		} else {
			$bug{$item} = '&nbsp;';
		}
	}
		
	# admin?
	$bug{'select'} = '&nbsp;' unless $bug{'select'}; 
    if ($self->base->isadmin && $self->base->current('format') ne 'L' && $req ne 'noadmin') { # LEAN for browsing...
	    $self->debug(3, "Admin of bug($bid) called.") if $Perlbug::DEBUG;
		my @groups     = @{$$h_bug{'group_ids'}}    if $$h_bug{'group_ids'};
		my @osnames    = @{$$h_bug{'osname_ids'}}   if $$h_bug{'osname_ids'};
		my ($severity) = @{$$h_bug{'severity_ids'}} if $$h_bug{'severity_ids'};
		my ($status)   = @{$$h_bug{'status_ids'}}   if $$h_bug{'status_ids'};
		my @users      = @{$$h_bug{'user_ids'}}     if $$h_bug{'user_ids'};
		my ($fixed)    = $self->object('fixed')->id2name($$h_bug{'fixed_ids'})     if $$h_bug{'fixed_ids'};
		my ($version)  = $self->object('version')->id2name($$h_bug{'version_ids'}) if $$h_bug{'version_ids'};
		# print "<hr>c($group) o($osname) sev($severity) stat($status) u($user) ver($version)<hr>";
		$bug{'help'} = q|Enter an <b>existing</b> id in the <b>ID</b> row <i>above</i>, to assign a new relation to this bug.<hr>|;
		$bug{'help'}.= q|Enter new <b>data</b> in the row <i>below</i> to create a new note, patch or test.  With a new patch, consider entering a <b>changeID</b> at the same time!|;
		$bug{'address_names'} = $self->object('address')->text_field($bid.'_address', '', -'size' => 55).$bug{'address_ids'};
		$bug{'note_names'}   	= $self->object('note')->text_field($bid.'_note', '').$bug{'note_ids'};
		$bug{'group_names'}  	= $self->object('group')->choice($bid.'_group', @groups); 
		$bug{'change_names'}  = $self->object('change')->text_field($bid.'_change', '').$bug{'change_names'};
		$bug{'child_ids'}   = $self->object('child')->text_field($bid.'_child', '').$bug{'child_ids'};
        $bug{'fixed_names'} = $self->object('fixed')->text_field($bid.'_fixed', $fixed);
		# new stuff is only for format::H
		$bug{'new_note'}     = $cgi->textarea(-'name'  => $bid.'_new_note',  -'value' => '', -'rows' => 3, -'cols' => 20, -'override' => 1, 'onChange' => 'pick(this)');
		$bug{'new_patch'}    = $cgi->textarea(-'name'  => $bid.'_new_patch', -'value' => '', -'rows' => 3, -'cols' => 20, -'override' => 1, 'onChange' => 'pick(this)');
		$bug{'new_test'}     = $cgi->textarea(-'name'  => $bid.'_new_test',  -'value' => '', -'rows' => 3, -'cols' => 20, -'override' => 1, 'onChange' => 'pick(this)');
		# end newstuff
		$bug{'note_ids'}  = $self->object('note')->text_field($bid.'_note', '').$bug{'note_ids'};
		$bug{'osname_names'}  = $self->object('osname')->choice($bid.'_osname', @osnames);
		$bug{'parent_ids'}  = $self->object('parent')->text_field($bid.'_parent', '').$bug{'parent_ids'};
		$bug{'patch_ids'}   = $self->object('patch')->text_field($bid.'_patch', '').$bug{'patch_ids'};
		$bug{'test_ids'}    = $self->object('test')->text_field($bid.'_test', '').$bug{'test_ids'};
		$bug{'severity_names'}= $self->object('severity')->choice($bid.'_severity', $severity);
        $bug{'status_names'}  = $self->object('status')->choice($bid.'_status', $status);
    	$bug{'select'}      = $cgi->checkbox(-'name'=>'bugid', -'checked' => '', -'value'=> $bid, -'label' => '', -'override' => 1);
        # $bug{'user_ids'}  = $self->object('user')->choice($bid.'_user', @users);
        $bug{'version_names'} = $self->object('version')->text_field($bid.'_version', $version);
	}
	# print '<pre>h_bug: '.encode_entities(Dumper($h_bug)).'</pre>'; 
	# print '<pre>bug: '.encode_entities(Dumper(\%bug)).'</pre>'; 
	return \%bug;
}

=item webupdate

Update bug via web interface

	my $oid = $o_bug->webupdate(\%cgidata, $gid);

=cut

sub webupdate {
	my $self   = shift;
	my $h_data = shift;
	my $oid    = shift;
    my $cgi    = $self->base->cgi();

	if (!(ref($h_data) eq 'HASH')) {
		$self->error("requires data hash ref($h_data) to update Bug data via the web!");
	} else {
		if (!($self->ok_ids([$oid]))) {
			$self->error("No bugid($oid) for webupdate!".Dumper($h_data));
		} else {
			my $orig_fmt = $self->base->current('format');
			$self->read($oid);
			if ($self->READ) {
				$self->base->current({'context', 'text'}); # notify_cc
				$self->base->current({'format',  'a'});

				my $i_read = $self->read($oid)->READ;
				my $orig = $self->format('a');	
				$self->base->dok([$oid]);

				my $opts = $cgi->param($oid.'_opts') || $cgi->param('_opts') || '';
				my $pars = join(' ', $opts);
				my %update = $self->base->parse_str($pars);

				REL: # space separated(str2ids), store/assign(friendly/prejudicial)
				foreach my $rel ($self->rels) { 			# rels
					my @extant = $self->rel_ids($rel);
					push(@{$update{$rel}{'ids'}}, @extant) if scalar(@extant) >= 1;
					my @update = ($rel =~ /(change|patch|note|test|parent|child)/io) 
						? split(/\s+/, $cgi->param($oid.'_'.$rel))  # space seperated
						: $cgi->param($oid."_$rel");				# plain
					my $type = ($rel =~ /(address|change|fixed|version)/) 
						? 'names' : 'ids';
					push(@{$update{$rel}{$type}}, @update) if scalar(@update) >= 1;
					my %data = (
						'rel'		=> $rel, 
						'type'		=> $type,
						'update'	=> \@update,
						'extant'	=> \@extant,
					);
					$self->debug(1, Dumper(\%data)) if $Perlbug::DEBUG;
				}				
				my $i_rel = $self->relate(\%update);

				my $req = $cgi->param('req') || '';
				if ($self->base->current('mailing') == 1) {
					my $ix = $self->base->notify_cc($oid, $orig) unless $req eq 'nocc'; 
				}

				foreach my $targ (qw(note patch test)) { 	# new
					my $call = 'do'.uc(substr($targ, 0, 1));
					my $i_newid  = $self->base->$call({
						'opts'	=> "req($req): $oid", 
						'body'	=> $cgi->param($oid.'_new_'.$targ),
					}) if $cgi->param($oid.'_new_'.$targ);
				}
				my $ref = "<p>Bug ($oid) updated $Mysql::db_errstr<p>";
				$self->debug(2, $ref) if $Perlbug::DEBUG;

				$self->base->current({'context', 'html'});
				$self->base->current({'format', $orig_fmt});
			}
		}
	}
	
	return $oid;
}

=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000

=cut

# 
1;

