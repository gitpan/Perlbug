# Perlbug format handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Format.pm,v 1.72 2002/01/25 16:12:58 richardf Exp $
#
# TODO
# formats in db
# 

=head1 NAME

Perlbug::Format - Format class

=cut

package Perlbug::Format;
use strict;
use vars qw($VERSION); 
$VERSION = do { my @r = (q$Revision: 1.72 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

use Carp;
use Data::Dumper;
use HTML::Entities;
# use Perlbug::Base;
# use Perlbug::Object;

my $o_Perlbug_Base = undef;
my $i_CNT = 0;
my $i_MAX = 1;
my $i_TOP = 1;

=head1 DESCRIPTION

Supplies formatting methods for object data, according to the currently supported format types:

    a ascii short - minimal listings default for mail interface

    A ASCII long  - maximal block style listings

	d debug short - a|h with object attributes (unsupported)

	D debug long  - A|H with object attributes (unsupported)

    h html short  - minimal listings default for web interface

    H HTML long   - maximal block style listings

    i id short    - minimal id style listings

	I id HTML     - like i, but with html links 

	l lean list   - ascii but purely for parsing minimal data

	L lean HTML   - like l, but with html links 

	x xml short   - placeholder

	X XML short   - placeholder

User rights determine what data is seen and how it will be presented pro option

Ascii:

	guest:
		user: $userid

	admin:
		user: $userid
		pass: $passwd

Html:

	<pre>
	guest:
		user: $userid

	admin:
		user: <input type=text value="$userid"> 
		pass: <input type=text value="$passwd"> 
		<submit name=change>
	</pre>

=head1 SYNOPSIS

	use Perlbug::Format;

	my $o_fmt = Perlbug::Format->new();

	print $o_fmt->object('patch')->read('123')->format('l');

=head1 METHODS

=over 4

=item new

Create new Format object:

	my $o_fmt = Perlbug::Format->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	$o_Perlbug_Base = (ref($_[0])) ? shift : Perlbug::Base->new();

	my $self = Perlbug::Object->new($o_Perlbug_Base, 
		'name'		=> 'Format',
	);

	bless($self, $class);
}

=back

=head1 FORMATTING

All objects may provide their own formatting methods, these are offered as B<catchalls>

=over 4

=item FORMAT

Wrapper for format -> FORMAT

	my $formatted_str = $o_fmt->FORMAT('a'); # ([aAhHlL])...

This uses the internal object structure 'data'.

Note that you can also give these data hashes directly as in the following example:

	my $formatted_str = $o_fmt->FORMAT('a', { 'this' => 'data' }, { 'ext: over' => 'here :-)' }); 

=cut

sub FORMAT {
	my $self = shift;
	my $fmt  = shift || $self->base->current('format');
	my $h_data = shift || $self->_oref('data');
	my $h_rel  = shift || $self->_oref('relation'); # :-\

	my ($format, $str, $target, $top) = ('', '', '', '');
	my @args = ();
	my $max  = 1000;

	if (ref($h_data) ne 'HASH' or ref($h_rel) ne 'HASH') {
		$self->error("non-valid required args: data_href($h_data) and relations_href($h_rel)!");		
	} else {
		my $h_data = $self->format_fields({%{$h_data}, %{$h_rel}}, $fmt);
		$target = 'FORMAT_'.$fmt;
		# $self->debug(1, "attempting to $self->$target($h_data)") if $Perlbug::DEBUG;
		($top, $format, @args) = $self->$target($h_data);
		# $self->debug(1, "top($top), format($format), args(@args)") if $Perlbug::DEBUG;
		$^W = 0;
		if ($fmt =~ /[aAil]/o) {
			$= = 1000;	# lines per page
			# my $max = $data =~ tr/\n/\n/; # $max += 128;  # 
			$^A = ""; 							# set
			formline($format, @args);			# 1
		} else {
			$^A = $format;
		}
		$^W = 1;
		$str = (($i_TOP == 1) ? $top.$^A : $^A); # get
		if ($self->base->current('context') eq 'http' && $fmt !~ /[hHIL]/) {
			$str = encode_entities($str);
			$str = '<pre>'.$str.'</pre>';
		}
		$self->debug(3, "str($str)") if $Perlbug::DEBUG;
		$self->cnt(1);
		$^A = ""; 								# reset
	}

	return $str;
}

=item format_fields

Format individual entries for output, handles all available objects

Certain keywords to be careful of here: keys for objects and for relations(ids, count, names)

    my $h_data = $o_fmt->format_fields($h_data, [$fmt, [$i_max]]);

=cut

sub format_fields {
    my $self = shift;
    my $h_ref= shift;
    my $fmt  = shift || 'a';
	my $i_max= shift || 10;
	my $h_ret= {};

    if (ref($h_ref) ne 'HASH') {
		$self->error("requires a hash ref($h_ref)");
	} else {
		$self->debug(2, "normalising...") if $Perlbug::DEBUG;
		my $n_ref = $self->normalize($h_ref);
		if ($fmt !~ /[hHIL]/) { 	# ascii 
			$self->debug(2, "asciifying...") if $Perlbug::DEBUG;
			$h_ret = $self->asciify($n_ref); 
		} else { 					# html 
			$self->debug(2, "htmlifying...") if $Perlbug::DEBUG;
			$h_ret = $self->htmlify($n_ref); 
			$$h_ret{'select'} = '&nbsp;' unless $$h_ret{'select'};
			foreach my $k (sort keys %{$h_ret}) {
				if ($k =~ /body|entry|header|subject/io) { # ?!
					$$h_ret{$k} = encode_entities($$h_ret{$k}) unless $$h_ret{$k} =~ /^\s*\&nbsp;\s*$/io;
					$$h_ret{$k} = '<pre>'.$$h_ret{$k}.'</pre>' unless $k eq 'subject';
				}
			}
		}
	}	

	$self->debug(3, "rjsf: fmt($fmt): ".Dumper($h_ret)) if $Perlbug::DEBUG;
			
    return $h_ret;
}

=item normalize 

Returns data all on a single level

	$h_bug = {
		'bugid'	=> '19870502.007',
		'user'	=> {
			'count'	=> 1,
			'ids'	=> [qw(richardf)],
	}

Becomes: 
	$h_bug = {
		'bugid'	=> '19870502.007',
		'user_count'	=> 1,
		'user_ids'		=> [qw(richardf)],
		'user_names'	=> ['Richard Foley'],
	}

	my \%data = $o_fmt->normalize(\%data);

=cut

sub normalize {
	my $self 	= shift;
	my $h_data 	= shift;
	my %ret 	= ();

	if (ref($h_data) ne 'HASH') {
		$self->error("requires hashed data ref($h_data)!");
	} else {
		my %args = %{$h_data};  
		HASH:
		foreach my $key (sort keys %args) {
			if (ref($args{$key}) ne 'HASH') { 
				$ret{$key} = $args{$key}; 					#
			} else {
				my %data = %{$args{$key}};
				foreach my $hkey (sort keys %data) {
					$ret{"${key}_$hkey"} = $data{$hkey}; 	#
				}
			}
		}
	}
	$self->debug(3, "$h_data => ".Dumper(\%ret)) if $Perlbug::DEBUG;

	return \%ret;
}

=item asciify 

Returns args generically wrapped for ascii presentation 

	my \%data = $o_fmt->asciify(\%data);

=cut

sub asciify {
	my $self 	= shift;
	my $h_data 	= shift;
	my %ret 	= ();

	if (ref($h_data) ne 'HASH') {
		$self->error("requires hashed data ref($h_data)!");
	} else {
		my %args = %{$h_data}; # 
		HASH:
		foreach my $key (sort keys %args) {
			if (ref($args{$key}) ne 'ARRAY') { # 
				$ret{$key} = $args{$key} || '0';
			} else {
				if (!(scalar(@{$args{$key}}) >= 1)) {
					$ret{$key} = ''; 
				} else {
					$ret{$key} = join(', ', @{$args{$key}});
				}
			}		
		}
	}
	$self->debug(3, "$h_data => ".Dumper(\%ret)) if $Perlbug::DEBUG;

	return \%ret;
}

=item htmlify

Returns args generically wrapped with html tags - way too convoluted.

	my \%data = $o_fmt->htmlify(\%data);

=cut

sub htmlify { # rjsf - hopelessly long
	my $self 	= shift;
	my $h_data 	= shift;
	my %ret 	= ();

	if (ref($h_data) ne 'HASH') {
		$self->error("requires hashed data ref($h_data)!");
	} else {
		my %args = %{$h_data};
		# print $self->base->html_dump($h_data);
		foreach my $key (sort keys %args) { 
			$ret{$key} = '';
			my $val = $args{$key} || '';
			if (ref($val) eq 'ARRAY') { 				# MULTI
				my @args = @{$val};
				$self->debug(3, "\tmulti(@args)") if $Perlbug::DEBUG;
				if (!(scalar(@args) >= 1)) {				# zip 
					$ret{$key} = '&nbsp;';
				} else { 
					if ($key !~ /^([a-z]+)_(ids|names)$/) { # should normally be... 
						$ret{$key} = join(' &nbsp; ', sort @args);				
					} else {								# rellies: 
						my ($obj, $word) = ($1, $2);
						my $o_obj = ($obj =~ /(arent|hildren)/io) ? $self->object('bug') : $self->object($obj);
						my $ident = ($word eq 'names') ? $o_obj->identifier : "${obj}_id";	
						if ($key ne 'user_names') {			# all: $o_obj->read($_)->data($ident)
							my $stat_subj = (grep(/^$obj$/, $self->base->objects('mail')))
								? $args{'subject'}
								: ''; 
							$ret{$key} = join(', ', ($word eq 'names') 
								? map { $self->href("${obj}_id", [$o_obj->name2id([$_])], $_, $stat_subj) } @args
								: map { $self->href("${obj}_id", [$_], $_, $stat_subj) } @args
							);  		
						} else { 	 						# userid(email)
							my @usrs = ();
							foreach my $arg (sort @args) { 		# status lines
								my $stat_name = $arg;
								my ($uid)  = $o_obj->name2id([$arg]);
								my ($name) = $self->href("${obj}_id", [$uid], $arg, $stat_name);
								my ($addr) = $o_obj->read($uid)->data('address');
								my $rec    = qq|$name<a href="mailto:$addr">($addr)</a>|;
								push(@usrs, $rec);
							}
							$ret{$key} = join(', <br>', @usrs);
						}
					}
				}
			} else { 										# SINGLE
				$self->debug(3, "\tsingle($val)") if $Perlbug::DEBUG;
				if ($key =~ /^([a-z]+)id$/io) {				# primary
					my $obj = $1;					
					my ($hdrs, $status) = ('', '');
					if (grep(/^$obj$/, $self->base->objects('mail'))) {
						($hdrs) = $self->href("${obj}_header", [$val], 'headers<br>', "Email headers"); 
						$hdrs   = '' unless $hdrs;
						$status = $args{'subject'}; 
					}	
					$ret{$key} = join('&nbsp;', $self->href("${obj}_id", [$val], $val, $status, [], qq|return go('${obj}_id&${obj}_id=$val')|, 'H'), $hdrs);
					$self->debug(2, "obj($obj) val($val) -> ret($ret{$key})") if $Perlbug::DEBUG;
					# print "obj($obj) key($key) val($val) -> ret($ret{$key})<hr>";
				} elsif ($key =~ /^([a-z]+)_count$/o) {		# int
					my $obj = $1;
					my $pointer = "${obj}_ids";
					my @ids = (ref($args{$pointer}) eq 'ARRAY') ? @{$args{$pointer}} : ();
					my $ids = (scalar(@ids) >= 1) ? join("&${obj}_id=", sort @ids) : '';
					my $i_ids = scalar(@ids);
					my $stat_hdrs = "$i_ids ${obj}'s";
					# print "obj($obj) key($key) val($val) -> ids($ids) i_ids($i_ids) stat($stat_hdrs)<hr>\n";
					($ret{$key}) = $self->href("${obj}_id", [$ids], $i_ids, $stat_hdrs);
				} elsif ($key =~ /^(source|to)addr$/o) {		# addr	
					my ($addr) = $self->parse_addrs([$val]);
					$addr = '' unless $addr;
					($ret{$key}) = ($addr =~ /\w/o) ? qq|<a href="mailto:$addr">$addr</a>| : '';
				} else {									# name etc...
					# my $obj = $o_obj->key || 'x';
					$ret{$key} = ($key eq 'name' && $val =~ /\w+\@\w+/o) # email?
						? qq|<a href="mailto:$val">$val</a>|
						: "$val " # join(' ', $self->href("${obj}_id", [$val], $val))
					;
				} 
				$ret{$key} = ' ' unless defined($ret{$key}) && $ret{$key} =~ /\w/o; 
			} 
			$self->debug(2, "\tkey($key) -> ret($ret{$key})") if $Perlbug::DEBUG;
		}
	}

	$self->debug(3, "$h_data => <pre>\n".Dumper(\%ret)."</pre>\n") if $Perlbug::DEBUG;

	return \%ret;
}

=item parse_addrs

Parse email address given into RFC-822 compatible format, also removes duplicates.

With optional address(only) or format(whole string) requested, defaults to address.

	my @parsed = $o_fmt->parse_addrs(\@original_addrs, 'address|format');	

=cut

sub parse_addrs {
	my $self = shift;
	my $a_addrs = shift;
	my $type    = shift || 'address'; # format

	my @addrs = (ref($a_addrs) eq 'ARRAY') ? @{$a_addrs} : ($a_addrs); 
	my %parsed  = ();

	if (scalar @addrs >= 1) {
		foreach my $addr (@addrs) {
			my @o_addrs = Mail::Address->parse($addr);
			foreach my $o_addr (@o_addrs) {
				if (ref($o_addr)) {
					my ($addr) = $o_addr->$type();
					$parsed{$addr}++;
				}	
			}	
		}
	}

	$self->debug(3, "a_addrs($a_addrs), type($type) -> parsed(".join(', ', keys %parsed).")") if $Perlbug::DEBUG;
	return keys %parsed;
}

=item href

Return list of perlbug.cgi?req=key_id&... hyperlinks to given list). 

Maintains format, rng etc.

    my @links = $o_fmt->href(
		'bug_id', 
		\@bids, 
		'visible element of link', 
		[subject hint], 
		[\@boldids], 
		$js,
		$fmt
	);

Or 

    my @links = $o_fmt->href(
		'query&status=open', 
		[], 
		'open bugs', 
		'Click to see open bugs', 
	);

=cut

sub href { # 
    my $self    = shift;
    my $key     = shift;
    my $a_items = shift;
    my $visible = shift || '';
    my $subject = shift || '';
	my $a_bold  = shift || '';
	my $js      = shift || ''; # "return go('$key')";
	my $fmt     = shift || $self->base->current('format');

	my @links = ();

    if (ref($a_items) ne 'ARRAY') {
		$self->error("requires array of items($a_items)");
	} else {
		my $cgi = $self->base->cgi;
		my $url = $self->base->myurl;
		my $target = ($self->base->isframed) ? 'perlbug' : '_top';
		my $rid = $self->base->{'_range'};
		my $range = ($rid =~ /\w+/o) ? "&range=$rid" : '';
		my $trim = (ref($cgi) && $cgi->can('trim') && $cgi->param('trim') =~ /^(\d+)$/o) ? $1 : 25;
		$trim = "&trim=$trim";
		# my $commands = "&commands=read";
		my $commands = '';

		$subject =~ s/'/\\\'/gos; 	# javascript fixes...
		$subject =~ s/"/\\\'/gos;	# 
		$subject =~ s/\n+/ /gos;	# 
		my $status = ($subject =~ /\w+/o) ? qq|onMouseOver="status='$subject'; return true;"| : '';

		if ($key =~ /^\w+=\w+/o || scalar(@{$a_items}) == 0 ) { # requesting own ...
			my ($format) = ($key =~ /format/o) ? '' : '&format='.($fmt || 'H'); #
			my $link = qq|<a href="$url?req=${key}${format}${trim}${commands}${range}" target="$target" $status; onClick="$js">$visible</a>|;
			push (@links, $link);
			$self->debug(3, "singular($link)") if $Perlbug::DEBUG;
		} else {
			# $commands = "&commands=write";
			$commands = ''; 
			my $format = '&format='.($fmt || 'H');
			ITEM:
			foreach my $val (@{$a_items}) {
				next ITEM unless defined($val) and $val =~ /\w+/o;
				my $vis = ($visible =~ /\w+/o) ? $visible : $val;
				my $link = qq|<a href="$url?req=$key&$key=${val}${format}${trim}${commands}${range}" target="$target" $status; onClick="$js">$vis</a>|;
				push (@links, $link);
				$self->debug(3, "status($status), cgi($url), key($key), val($val), format($format), trim($trim), status($status), vis($vis) -> link($link)") if $Perlbug::DEBUG;
			}
		}
	}
	$self->debug(3, "key($key)") if $Perlbug::DEBUG;

	return wantarray ? @links : $links[0];
}


=item mailto

Return mailto: for a particular ticket

    my $mailto = $o_fmt->mailto($h_tkt); 

=cut

sub mailto { 
    my $self   = shift;
    my $h_tkt  = shift;    

    $self->debug(3, "mailto($h_tkt)") if $Perlbug::DEBUG;
    return undef unless ref($h_tkt) eq 'HASH';
    my %tkt = %{$h_tkt};
    my $subject = $tkt{'subject'} || '';
    if ($subject =~ /\w+/o) {
        # $subject = "\@subject=$subject"; 
    } 
    # Is this safe enough?
    my $reply = ($tkt{'osname'} =~ /^(\w+)$/o) ? $tkt{'osname'} : 'generic'; 
    my $list = $self->forward($reply);
    my $mailto = qq|<a href="mailto:$list">reply</a>|;

    return $mailto;
}

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut

1;

