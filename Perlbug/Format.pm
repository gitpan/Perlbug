# Perlbug format handler
# (C) 1999 Richard Foley RFI perlbug@rfi.net
# $Id: Format.pm,v 1.71 2002/01/14 10:14:48 richardf Exp $
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
$VERSION = do { my @r = (q$Revision: 1.71 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
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

__END__

# 
# FROM HERE IS NOW REDUNDANT - SEE Perlbug::Object::Template
# ===================================
# 


=item xpopup

Returns appropriate (cached) popup with optional default value inserted.

    my $popup = $o_fmt->popup('status', $unique_id, $default);

	$tkt{'group'}      = $self->popup('group', 	$tkt{'group'}, $id.'_group');
	$tkt{'osname'}     = $self->popup('osname', 	$id.'_osname',    $tkt{'osname'});
	$tkt{'select'}     = $cgi->checkbox(-'name'=>'bugid', -'checked' => '', -'value'=> $id);
	$tkt{'severity'}   = $self->popup('severity', 	$id.'_severity',   $tkt{'severity'});
	$tkt{'status'}     = $self->popup('status', 	$id.'_status',     $tkt{'status'});

=cut

sub xpopup {
    my $self 	= shift;
    my $flag 	= shift;
	my $uqid	= shift;
	my $default = shift || '';
	my $onchange= shift || '';

	my $ok 		= 1;
    $self->debug(3, "popup: typeofflag($flag), uniqueid($uqid), default($default)") if $Perlbug::DEBUG;
	if (($flag !~ /^\w+$/) || ($uqid !~ /\w+/)) {
		$ok = 0;
		$self->error("popup($flag, $uqid, [$default]) given invalid args!");
	}
	my $cgi   = $self->cgi();
	my %flags = $self->base->all_flags;
	my @flags = keys %flags;
    if (!grep(/^$flag$/, @flags)) {
		$ok = 0;
		$self->error("popup-flag($flag) not found amongst available flag types: '@flags'");
    }
    my $popup = '';
	if ($ok == 1) {
		$self->{'popup'}{$flag} = ''; # for now
		my @options = ('', sort($self->base->flags($flag)));
		$popup = $cgi->popup_menu( 
			-'name' => $uqid, 
			-'values' => \@options, 
			-'default' => $default
		);
    	$self->{'popup'}{$flag} = $popup;   # store the current version (without name, and without selection
	}

    return $self->{'popup'}{$flag};     # return it
}

=item FORMAT_ascii

Default format, and args, for any object

	my ($top, $format, @args) = $o_fmt->FORMAT_ascii(\%data);

=cut

sub FORMAT_ascii { # defaults to 80 chars where format or method missing!
	my $self = shift;
	my $data = shift; # h

	my $key  = ucfirst($self->attr('key'));
	my @args = ( values %{$data}, 'a'..'z', );
	my ($top, $pre, $post) = ('', $$data{'_pre'}, $$data{'_post'});
	my $format = qq|
$key @{[ref($self)]} format:
------------------------------------------------------------------------------- 
|.(('@'.("<" x 76)."\n") x scalar(@args)).qq|
|; # @* will go off the end (good for messages :) ...

	return ($top, $format, @args);
}


=item FORMAT_html

Default html format, and args, for any object

	my ($format, @args) = $o_fmt->FORMAT_html(\%data);

=cut

sub FORMAT_html { # default where format or method missing!
	my $self = shift;
	my $href = shift; # h

	my $key  = ucfirst($self->attr('key'));
	my @args = map { "$_<br>" } (values %{$href}, 'a'..'z');
	my $top = '';
	my $format = qq|
<hr>
<h3>$key @{[ref($self)]} format:</h3>
<br>
|.(('@*'."\n") x scalar(@args)).qq|
|; # @* will go off the end (good for messages :) ...

	return ($top, $format, @args);
}


=item max

Wrapper for i_MAX access

	my $i_max = $o_fmt->max;

=cut

sub max {
	my $self = shift;

	$i_MAX   = shift || $i_MAX;

	return $i_MAX;
}


=item cnt 

Wrapper for i_CNT access

	my $i_counted = $o_fmt->cnt;

=cut

sub cnt {
	my $self = shift;
	$i_CNT  += shift || 0;

	if ($i_CNT >= $i_MAX) {
		$i_CNT = 0;
		$i_TOP = 1;
	} else {
		$i_TOP = 0;
	}

	return $i_CNT;
}


=back

=head1 FORMATTING_STYLES

The following formatting styles are supported, b<a> is the default

These methods here may be used directly against any basic table, each object is expected to provide more relevant formatting where required.

For supported types (/[ahilx]/i) see B<DESCRIPTION>

=over 4

=cut


=item FORMAT_i

ID ascii format, no header or body.

	my ($top, $format, @args) = $o_fmt->FORMAT_i(\%data);

=cut


sub FORMAT_i { # 
	my $self = shift;

	my $x    = shift; # 
	my $pri  = $self->attr('primary_key');
	my @args = ( $$x{$pri} );
	my $top = '';
	my $format = qq|@<<<<<<<<<<<\n|; 

	return ($top, $format, @args);
}


=item FORMAT_I

ID HTML format, no header or body.

	my ($top, $format, @args) = $o_fmt->FORMAT_I(\%data);

=cut


sub FORMAT_I { # 
	my $self = shift;

	my $x    = shift; # 
	my $pri  = $self->attr('primary_key');
	my @args = ();
	my $top = '';
	my $format = qq|$$x{$pri}<br>\n|; 

	return ($top, $format, @args);
}


=item FORMAT_l

Default Lean (list) ascii format, no header or body.

	my ($top, $format, @args) = $o_fmt->FORMAT_l(\%data);

=cut


sub FORMAT_l { # 
	my $self = shift;

	my $x    = shift; # 
	my $obj_key_oid = ucfirst($self->attr('key')).' ID';
	$obj_key_oid .= (' ' x (12 - length($obj_key_oid)));
	my $pri  = $self->attr('primary_key');
	my @args = ( 
		$$x{$pri}, $$x{'name'}, $$x{'bug_count'}, $$x{'created'}, $$x{'subject'},
	);
	my $top = qq|
$obj_key_oid  Name           Bugids  Created            Subject|;
	my $format = qq|
@<<<<<<<<<<<  @<<<<<<<<<<<<< @<<<<<  @<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<
|;

	return ($top, $format, @args);
}


=item FORMAT_a

Default ascii format, inc. message body

	my ($top, $format, @args) = $o_fmt->FORMAT_a(\%data);

=cut

sub FORMAT_a { # default where format or method missing!
	my $self = shift;
	my $x    = shift; # 

	my $obj_key_oid = ucfirst($self->attr('key')).' ID';
	$obj_key_oid .= (' ' x (12 - length($obj_key_oid)));
	my $pri  = $self->attr('primary_key');
	my @args = ( 
		$$x{$pri}, $$x{'name'}, $$x{'created'}, $$x{'ts'}, $$x{'subject'},
	);
	my $top = qq|
$obj_key_oid    Name           Created                  Modified|;
	my $format = qq|
@<<<<<<<<<<<    @<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<
Subject: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
|;
	foreach my $key (keys %{$x}) {
		if ($key =~ /^([a-z]+)_ids$/o) {
			push(@args, $$x{"${1}_count"}, $$x{$key});
			$format .= sprintf('%-16s', $key.': ').'@<<<<<< @'.('<' x 55)."...\n";
		}
	}
	push(@args, $$x{'body'});	
	$format .= "\n\@\*\n";

	return ($top, $format, @args);
}


=item FORMAT_A

Default ASCII format inc. message header and body

	my ($top, $format, @args) = $o_fmt->FORMAT_A(\%data);

=cut

sub FORMAT_A { # default where format or method missing!
	my $self = shift;

	my $x    = shift; # 
	my $obj_key_oid = ucfirst($self->attr('key')).' ID';
	$obj_key_oid .= (' ' x (12 - length($obj_key_oid)));
	my $pri  = $self->attr('primary_key');
	my @args = ( 
		$$x{$pri}, $$x{'name'}, $$x{'bug_count'}, $$x{'created'}, $$x{'subject'},
		$$x{'header'}, $$x{'body'}, $$x{'bug_ids'}
	);
	my $top = qq|
$obj_key_oid  Name           Bugids  Createdx            Subject|;
	my $format = qq|
-------------------------------------------------------------------------------
@<<<<<<<<<<<  @<<<<<<<<<<<<< @<<<<<  @<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<
@*

@*

@*
|;

	return ($top, $format, @args);
}


=item FORMAT_L

Default Lean html format 

	my ($top, $format, @args) = $o_fmt->FORMAT_L(\%data);

=cut

sub FORMAT_L { # List(html)
	my $self = shift;

	my $x    = shift; # 
	my $key  = ucfirst($self->attr('key'));
	my $pri  = $self->attr('primary_key');
	my $top = qq|
</table><table border=1 width=100%>
<tr>
	<td width=25%><b>$key ID</b></td><td><b>Bug ID</b></td>
	<td><b>Source address</b></td><td><b>Created</b></td><td><b>Subject</b></td>
</tr>
|;
	my $format = qq|
<tr><td>$$x{'select'} $$x{'name'} &nbsp; $$x{$pri} </td>
<td>$$x{'bug_count'}</td>
<td>$$x{'sourceaddr'}</td>
<td>$$x{'created'}</td>
<td>$$x{'subject'}</td>
</tr>
</table>
|;

	return ($top, $format, ());
}


=item FORMAT_h

Default html format 

	my ($top, $format, @args) = $o_fmt->FORMAT_h(\%data);

=cut

sub FORMAT_h { # html
	my $self = shift;
	my $x    = shift; # 

	my $key  = ucfirst($self->attr('key'));
	my $pri  = $self->attr('primary_key');

	$^W = 0;

	my $top = qq|<table border=1 width=100%>
<tr>
	<td width=25%><b>$key ID &nbsp; $$x{'name'}</b></td>
	<td><b>Bug IDs</b></td>
	<td><b>Name</b></td>
	<td><b>Created</b></td>
	<td><b>Modified</b></td>
</tr>|;
	my $format = qq|<tr>
	<td>$$x{$pri} &nbsp;</td>
	<td>$$x{'bug_ids'} &nbsp;</td>
	<td>$$x{'name'} &nbsp;</td>
	<td>$$x{'created'} &nbsp;</td>
	<td>$$x{'modified'} &nbsp;</td>
</tr>
<tr>
	<td><b>Subject:</b></td>
	<td colspan=5>$$x{'subject'} &nbsp;</td>
</tr>
</table>
<table border=1 width=100%><tr><td colspan=4><b>Message body:</b></td></tr><tr><td colspan=4>
$$x{'body'} &nbsp;
</td></tr></table>|;

	return ($top, $format, ());
}


=item FORMAT_H

Default format in block html format. 

	my ($top, $format, @args) = $o_fmt->FORMAT_H(\%data);

=cut

sub FORMAT_H { # HTML
	my $self = shift;
	my $x    = shift; # 

	my $key  = ucfirst($self->attr('key'));
	my $pri  = $self->attr('primary_key');
	my $top = qq|
<table border=1 width=100%>
<tr>
	<td width=25%><b>$key ID</b></td>
	<td><b>Bug IDs</b></td>
	<td><b>Name</b></td>
	<td><b>Created</b></td>
	<td><b>Modified</b></td>
	<td><b>&nbsp;</b></td>
</tr>
|;
	my $format = qq|
<tr>
	<td>$$x{$pri} &nbsp; $$x{'name'}</td>
	<td>$$x{'bug_ids'} &nbsp;</td>
	<td>$$x{'name'} &nbsp;</td>
	<td>$$x{'created'} &nbsp;</td>
	<td>$$x{'modified'} &nbsp;</td>
	<td>&nbsp;</td>
</tr>
<tr>
	<td><b>Subject:</b></td>
	<td colspan=7>$$x{'subject'} &nbsp;</td>
</tr>
</table>
<table border=1 width=100%>
<tr><td colspan=4><b>Message body:</b></td></tr>
<tr><td colspan=4> $$x{'body'} &nbsp; </td></tr>
</table>|;

	return ($top, $format, ());
}


=item FORMAT_x

Default XML format, currently just wraps L<FORMAT_a()>

	my ($top, $format, @args) = $o_fmt->FORMAT_x(\%data);

=cut

sub FORMAT_x { # default where format or method missing!
	my $self = shift;
	my $x    = shift; # 
	
	my ($top, $format, @args) = $self->FORMAT_a; # default behaviour

	return ($top, $format, @args);
}


=item FORMAT_X

Default XML format, currently just wraps L<FORMAT_a()>

	my ($top, $format, @args) = $o_fmt->FORMAT_X(\%data);

=cut

sub FORMAT_X { # default where format or method missing!
	my $self = shift;
	my $x    = shift; # 
	
	my ($top, $format, @args) = $self->FORMAT_A; # default behaviour

	return ($top, $format, @args);
}


=pod

=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut


# 
1;

