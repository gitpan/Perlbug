# (C) 2001 Richard Foley RFI perlbug@rfi.net
# 
# $Id: Email.pm,v 1.106 2001/12/01 15:24:42 richardf Exp $ 
# 


=head1 NAME

Perlbug::Interface::Email - Email  interface to perlbug database.

=cut

package Perlbug::Interface::Email;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.106 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

use Data::Dumper;
use File::Spec; 
use Mail::Address;
use Mail::Send;
use Mail::Header;
use Mail::Internet;
use Sys::Hostname;
use Perlbug::File;
use Perlbug::Base;
@ISA = qw(Perlbug::Base);


=head1 DESCRIPTION

Email interface to perlbug database.

=head1 SYNOPSIS

    use Perlbug::Interface::Email;

    use Mail::Internet;

    my $o_int = Mail::Internet->new(*STDIN); 

    my $o_email = Perlbug::Interface::Email->new;

    my $call = $o_email->switch($o_int);

    my $result = $o_email->$call($o_int); 

    print $result; # =1 (hopefully :-)


=head1 METHODS

=over 4

=item new

Create new Perlbug::Interface::Email object:

    my $o_email = Perlbug::Interface::Email->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	
	my $self = Perlbug::Base->new(@_);

	bless($self, $class);

	return $self;
}


=item parse_input

Given a mail (Mail::Internet) object, parses it into command hash, 

Checks the header for X-Perlbug loop and the address of the sender 
via B<check_user()>, calls B<input2args()>.  Replaces B<switch()>.

    my $h_cmds = $o_email->parse_input($Mail::Internet->new(\$STDIN)));

=cut

sub parse_input {
    my $self   = shift;
	my $o_int  = shift;
	my $h_cmds = {};

	my @cc = ();
	my @to = ();
	my ($from, $subject) = ('', '');
	my ($o_hdr, $header, $body) = $self->splice($o_int);

	if (ref($o_hdr)) {
		$from = $o_hdr->get('From') || '';
		chomp($from);
		$self->check_user($from || $Perlbug::User || 'generic'); # ?!
	}

	if (ref($o_hdr)) {
		my $domain = quotemeta($self->email('domain'));
		($subject, @to) = ($o_hdr->get('Subject'), $o_hdr->get('To'));
		@cc = $o_hdr->get('Cc'); @cc = () unless @cc; 
		chomp(@to, $subject, @cc);
		$self->debug(2, "domain($domain)? -> to(@to), cc(@cc), subject($subject)") if $Perlbug::DEBUG;
		if ($self->check_incoming($o_hdr)) {
			if (grep(/^(.+)\@$domain$/i, @to, @cc)) {                     # .*@bugs.perl.org
				$h_cmds = $self->parse_header($o_hdr, $body);
			} else {
				my $bugdb = quotemeta($self->email('bugdb'));
				if (grep(/^$bugdb$/, @to, @cc)) {
					if ($subject =~ /\-\w/o) {                            # bugdb@perl.org
						$h_cmds = $self->parse_line($subject);
					} else {
						$$h_cmds{'nocommand'} = $self->message('nocommand');
					}
				} else {                                                  # anything else
					my ($switch, $opts) = $self->switch($o_int);
					$$h_cmds{$switch} = $opts;
				}
			}
		}
	}
	$self->debug(3, 'midway: '.Dumper($h_cmds)) if $Perlbug::DEBUG;

	# $DB::single=2;
	if (scalar(keys %{$h_cmds})) {
		my $cc      = (scalar(@cc) >= 1) ? '' : join(', ', @cc);
		my $to      = (scalar(@to) >= 1) ? '' : join(', ', @to);
		my $msgid   = $o_hdr->get('Message-Id') || '';
		my $replyto = $o_hdr->get('Reply-To') 	|| '';
		chomp($cc, $msgid, $replyto);

		my %info = ( # should be in input2args - but why do it x times?
			'body'			=> $body, 
			'email_msgid'	=> $msgid,
			'header'		=> $header, 
			'sourceaddr'	=> $from,
			'subject'		=> $subject,
			'reply-to'		=> $replyto,
			'toaddr'		=> $to,
			'cc'			=> $cc,
		);

		# the various possible inputs have all been worked out
		# apply them to the appropriate command
		# $$h_cmds{$cmd} = $self->opts($blabla);

		COMMANDS:
		foreach my $cmd (keys %{$h_cmds}) {
			if ($cmd =~ /^([BGMNPTU])$/ && $self->current('renotify')) {
				delete $$h_cmds{$1};
				$cmd = 'E';
			}
			$$h_cmds{$cmd} = $self->input2args($cmd, $$h_cmds{$cmd}, \%info);
		}
	}

	$$h_cmds{'quiet'} = $self->message('quiet') unless keys %{$h_cmds} >= 1;
	$self->debug(1, "PI: ".Dumper($h_cmds)) if $Perlbug::DEBUG;

    return $h_cmds;
}


=item return_type

Wrap email message options

	my $wanted = $o_email->return_type($cmd);

=cut

sub return_type {
	my $self = shift;
	my $cmd  = shift || '';

	my $wanted = '';

	if ($cmd =~ /^(E|j|bounce|nocommand)$/o) {
		$wanted = 'HASH';
	} elsif ($cmd =~ /^quiet$/) {
		$wanted = 'SCALAR';
	} else {
		$wanted = $self->SUPER::return_type($cmd);
	}

	return $wanted;
}


=item input2args

Take given input, command and email object, and translate to appropriate format.

Handles B<opts(...)> in $str

	my $cmd_args = $o_email->input2args($cmd, $str, \%inf);

=cut

sub input2args {
	my $self  = shift;
	my $cmd   = shift;
	my $arg   = shift || '';
	my $h_inf = shift;
	
	my $ret = $self->SUPER::input2args($cmd, $arg);

	my $wanted = $self->return_type($cmd);

	# $DB::single=2;
	if ($wanted eq 'HASH') { # HASH
		$ret = $h_inf;
		($$ret{'opts'}) ||= $arg; # rjsf !? - losing data!
		if ($cmd eq 'G') {
			($$ret{'name'}) = $1 if ($$ret{'opts'} =~ /^(\w+)/o);
			($$ret{'description'}) = $1 if ($$ret{'body'} =~ /(.+)/mso);
		} 
	}

	return $ret;
}


=item process_commands

Process email given, return results via email when /bugdb/ in address.

	my @res = $o_email->process_commands($h_cmds, $o_int);

=cut

sub process_commands {
	my $self   = shift;
	my $h_cmds = shift;
	my $o_int  = shift; # ignored
	my @res    = ();
	
	my $domain = quotemeta($self->email('domain'));
	if (!(ref($h_cmds) eq 'HASH' && ref($o_int))) {
		$self->error("requires commands($h_cmds) and Int::Mail object($o_int)!");
	} else {
		@res = $self->SUPER::process_commands($h_cmds);
		if ($o_int->head->get('To') =~ /(^bugdb|$domain$)/o) {
			$DB::single=2;
			my $i_ok = $self->return_info(join("\n", @res)."\n", $o_int)
				unless $res[0] =~ /^quiet/; 
		}
	}

	return @res;
}


=item return_info

Takes data ($a_stuff), which may be a ref to the result array, and mails 
it to the From or Reply-To address, Cc:-ing it to any address given by the C<-e> flag.  

    my $i_ok = $o_email->return_info($a_stuff, $o_int);

=cut

sub return_info { # from bugdb type call
    my $self   = shift;
    my $stuff  = shift;
	my $o_int  = shift;

    my ($o_hdr, $head, $body) = $self->splice($o_int);

    my $data = (ref($stuff) eq 'ARRAY') ? join('', @{$stuff}) : $stuff;
    $data =~ s/^\s*\.\s*$//go;   # replace troublesome (in email) dots

    my ($title, $maintainer) = ($self->system('title'), $self->system('maintainer'));
	my $from = $o_hdr->get('From');
	my $subject = $o_hdr->get('Subject');
	my $reply = $o_hdr->get('Reply-To') || '';
	chomp($from, $subject, $reply);

    my $header = join('', $self->read('header'));
	$header =~ s/Perlbug::VERSION/ - v$Perlbug::VERSION/io;
    my $footer = join('', $self->read('footer'));

    my $o_reply = $self->get_header($o_hdr);
	$o_reply->replace('To', $self->from($reply, $from));
    $o_reply->replace('Subject', "$title response - $subject");
    $o_reply->delete('Cc');
	$o_reply->add('Cc', $self->current('cc')) if $self->current('cc');

    my $i_ok = $self->send_mail($o_reply, $header.$data.$footer); #

	return $i_ok; # 0|1
}



=item mailing

Switch mailing on(1) or off(0)

	my $i_onoff = $o_mail->mailing(1);

=cut

sub mailing {
	my $self = shift;
	my $arg  = shift;
	my $res  = my $orig = $self->current('mailing');

	if (defined $arg and $arg =~ /^([01])$/o) {
		$res = $self->current({'mailing', $1});
	}		

	$self->debug(1, "setting mailing($arg) orig($orig) => res($res)") if $Perlbug::DEBUG;

	return $res;
}


=item from

Sort out the wheat from the chaff, use the first valid ck822 address:

	my $from = $o_email->from($replyto, $from, @alternatives);

=cut

sub from {
	my $self  = shift;
	my @addrs = @_;

	map { chomp($_) } grep(/\w+/, @addrs) if @addrs;
	# chomp(@addrs);

	my $from = '';
	if (scalar(@addrs) >= 1) {
		my @fandt = ($self->get_vals('target'), $self->get_vals('forward'));
		my (@o_addrs) = Mail::Address->parse(@addrs);
		ADDR:
		foreach my $o_addr ( @o_addrs ) { # or format?
			my ($addr) = $o_addr->address;	
			my ($format) = $o_addr->format;	
			chomp($addr, $format);
			next ADDR unless $addr =~ /\w+/o;
			next ADDR if grep(/^$addr$/i, @fandt, $self->email('bugdb'), $self->email('bugtron'));
			next ADDR unless $self->ck822($addr);
			$from = $format;
			$self->debug(2, "from address($from)") if $Perlbug::DEBUG;
			last ADDR;
		}
	}
	return $from;
}


=item messageid_recognised  

Returns obj and ids for any given email Message-Id line

	my ($obj, $ids) = $self->messageid_recognised($messageid_line);

=cut

sub messageid_recognised {
	my $self   = shift;
	my $msg_id = shift;

	my $object = '';
	my @ids    = ();
	
	if ($msg_id !~ /(\<.+\>)/) {    # trim it
		$self->error("No MessageId($msg_id) given to check against");
	} else {
		my ($msgid) = $self->db->quote($1); # escape it
		$msgid =~ s/\'(.+)\'/$1/;  # unquote it
		# my $messageid = "%Message-Id: %$msgid%"; # with <...> brackets
		# my $getbymsgid = "UPPER(header) LIKE UPPER('$messageid')"; # doesn't do newlines!
		my $getbymsgid = "UPPER(email_msgid) LIKE UPPER('%$msgid%')";
		$self->debug(2, "looking up messageid($msg_id) -> ($msgid) -> ($getbymsgid)") if $Perlbug::DEBUG;
		OBJ:
		foreach my $obj (grep(!/(parent|child)/io, $self->objects('mail'))) {
			next OBJ unless $obj =~ /\w+/o;
			my $o_obj = $self->object($obj);
			$self->debug(3, "looking at obj($obj) with $o_obj") if $Perlbug::DEBUG;
			@ids = $o_obj->ids($getbymsgid);
        	if (scalar(@ids) >= 1) {
				$self->debug(1, "MessageId($msgid) belongs to obj($obj) ids(@ids)") if $Perlbug::DEBUG;	
				$object = $obj; # recognised
				last OBJ;
			}
		}				
	}

	return ($object, @ids);
}


=item check_incoming

Checks (incoming) email header against our X-Perlbug flags, also slurps up the Message-Id for future reference.

    my $i_ok = $o_email->check_incoming($o_hdr); # 

=cut

sub check_incoming { # incoming
    my $self  = shift;
    my $o_hdr = shift;

    my $i_ok  = 0;
    $self->debug(3, "check_incoming($o_hdr)") if $Perlbug::DEBUG;
    my $dodgy = $self->dodgy_addresses('from'); 
    if (!ref($o_hdr)) {
		$self->error("No hdr($o_hdr) given");
	} else {
    	my @cc      = $o_hdr->get('Cc') || '';
    	my @to      = $o_hdr->get('To') || '';
    	my $from    = $o_hdr->get('From') || '';
    	my $inreply = $o_hdr->get('In-Reply-To') || '';
		my $msgid   = $o_hdr->get('Message-Id') || '';
    	my $replyto = $o_hdr->get('Reply-To') || '';
    	my $subject = $o_hdr->get('Subject') || '';
        my $xperlbug= $o_hdr->get('X-Perlbug') || '';
		# ($to) = map { ($_->address) } Mail::Address->parse($to);
		chomp($xperlbug, @to, $from, $replyto, $inreply, $msgid, $subject, @cc);
        $self->{'attr'}{'message-id'} = $msgid;
    	$self->debug(0, qq|incoming: $0: 
			Cc(@cc) 
			From($from) 
			In-Reply-To($inreply)
			Message-Id($msgid) 
			Reply-To($replyto) 
			Subject($subject) 
			To(@to) 
			X-Perlbug($xperlbug)
		|) if $Perlbug::DEBUG;

		my $o_to    = Mail::Address->parse(@to);
		my $o_from  = Mail::Address->parse($from);
		my $o_reply = Mail::Address->parse($replyto);
		my $o_cc    = Mail::Address->parse(@cc);

		@to      = ref($o_to)   ? $o_to->address    : @to;
		$from    = ref($o_from) ? $o_from->address  : $from;
		$replyto = ref($o_reply)? $o_reply->address : $replyto;
		@cc      = ref($o_cc)   ? $o_cc->address    : @cc;

		$i_ok = 1;
        if ($xperlbug =~ /\w+/io) {
            $i_ok = 0;
            $self->error("X-Perlbug($xperlbug) found, not good!");
        }
        if ($from =~ /$dodgy/i) {
            $i_ok = 0;
            $self->error("From one of us ($from), not good"); 
        }
		if ($replyto =~ /$dodgy/i) {
            $i_ok = 0;
            $self->error("Reply-To one of us ($replyto), not good"); 
        }
    	# Have we seen messageid in db before? -> TRASH it
    	if ($i_ok == 1) {
			my ($obj, @ids) = $self->messageid_recognised($msgid) if $msgid;
			if ($obj =~ /\w+/o || scalar(@ids) >= 1) {
				$self->debug(0, "CLONE seen obj($obj) before ids(@ids), bale out ?-|");
				if ($self->current('renotify')) {
					$self->debug(0, "CLONE allowing through for renotification!") if $Perlbug::DEBUG;
					$obj = ''; @ids = ();
				} else {
					$i_ok = 0;
					$self->error("CLONE baling out! :-0");
				}
			}
		} 
		if ($i_ok == 1) {
			my $i_cnt = 0;
			my @addrs = (
				$self->email('bugdb'), $self->email('bugtron'), $self->email('domain'),
				$self->target, $self->forward
			);
			# my $addrs = join('|', map { quotemeta($_) } @addrs);
			TOCC:
			foreach my $tc (@to, @cc) {
				next TOCC unless $tc =~ /\w+\@\w+/;
				ADDR:	
				foreach my $addr (@addrs) {
					next ADDR unless $addr =~ /\w+/;
					my $check =  quotemeta($addr);
					if ($tc =~ /$check/i) {
						$i_cnt++;
					}
				}
			}
			if ($i_cnt == 0) {
				$i_ok = 0;
				$self->debug(0, "Not addressed($i_cnt) to us at all: to(@to) cc(@cc)!") if $Perlbug::DEBUG;
			}
		}
    } 

	$self->debug(0, "incoming processable => ok($i_ok)") if $Perlbug::DEBUG;

    return $i_ok;
}


=item check_user

Checks the address given (From usually) against the db_user table, sets user or admin access priviliges via the switches mechanism accordingly. 

Returns admin name

    my $admin = $o_email->check_user($o_int->('From')); # -> user_id || blank

=cut

sub check_user {
    my $self  = shift;
    my $given = ref($_[0]) ? $_[0]->get('From') : shift;

	my $o_usr = $self->object('user');
	my ($parsed) = $o_usr->parse_addrs([$given]);
	my ($o_addr) = Mail::Address->parse($given);
	my $host = $o_addr->host; $host =~ s/[^a-zA-Z]/%/g;
    $self->debug(3, "check_user($given), parsed($parsed), host($host)") if $Perlbug::DEBUG;
	my @uids  = $o_usr->ids("match_address LIKE '%$host%'"); # pro domain
	my @addrs = $o_usr->col('match_address');
    $self->debug(3, "ids(@uids)") if $Perlbug::DEBUG;

    USER:
    foreach my $uid (@uids) {
		next USER unless $uid =~ /\w+/o;
		$o_usr->read($uid);
		if ($o_usr->READ) {
			my $userid = $o_usr->data('userid');
       		my $match_address = $o_usr->data('match_address');
			if ($parsed =~ /^($match_address)$/i) { # an administrator
				$self->current({'admin', $userid});
			}
        } 
    }

    $self->debug(1, "parsed($parsed) => isadmin(".$self->isadmin.')') if $Perlbug::DEBUG;

	return $self->isadmin;
}


=item spec

Return email specific specification info

=cut

sub spec {
	my $self = shift;

	my ($dynamic) = $self->SUPER::spec; # Base
	# my $spec = $self->read('spec');

	my $spec .= qq|
	$dynamic
-----------------------------------------------------------------------
Mail sent to the following targets will register a new bug in the database 
and forward it onto the appropriate mailing list:

|;
	my @targets = $self->get_keys('target');
	foreach my $tgt (@targets) { # 
		next unless $tgt =~ /\w+/o;
        my $first  = sprintf('%-15s', ucfirst($tgt).':'); 
        my @notify = $self->target($tgt);
		my $notify = join(' or ', @notify);
        my $reply  = $self->forward($tgt);
        $spec .= qq|${first} ${notify} -> ($reply)\n|;
    }
	
	return $spec;
}


=item switches

Appends a couple of extra email specific switches to B<Perlbug::Base::switches()>

	my @switches = $o_email->switches();

=cut

sub switches {
	my $self = shift;
	
	my @switches = ($self->SUPER::switches(@_), grep(!/^[A-Z]$/, $self->message));

	return @switches;
}


=item get_header

Get new perlbug Mail::Header, filled with appropriate values, based on given header.

	my $o_hdr = $o_email->get_header();						   # completely clean

	my $o_hdr = $o_email->get_header($o_old_header, 'default');# default (coerced as from us)

	my $o_hdr = $o_email->get_header($o_old_header);           # as default 

	my $o_hdr = $o_email->get_header($o_old_header, 'ok'); 	   # maintain headers (nearly transparent)
	
	my $o_hdr = $o_email->get_header($o_old_header, 'remap');  # maintain headers (nearly transparent)

=cut

sub get_header {
	my $self   = shift;
	my $o_orig = shift || '';
	my $context= shift || 'default'; # ...|remap|ok
	my $o_hdr  = Mail::Header->new;

	if (ref($o_orig)) { # partially fresh
		$o_hdr = $o_orig->dup;
		foreach my $tag ($o_orig->tags) { # to, cc?
			my @lines = $o_orig->get($tag);
			# $DB::single=2 if $tag =~ /^to/i;
			my @res = $self->$context($tag, @lines); # default|remap|ok
			$o_hdr->replace($tag, @res) if scalar(@res) >= 1;
			$self->debug(2, "$context - tag($tag) lines(@lines) -> res(@res)") if $Perlbug::DEBUG;
		}
		my @xheaders = qw(Cc From Message-Id Perlbug In-Reply-To Reply-To Subject To);
		foreach my $xheader (@xheaders) {
			my $ref = ($xheader =~ /^Cc$/o) 
				? join(', ', $o_orig->get('Cc')) 
				: $o_orig->get($xheader) || '';
			$o_hdr->replace('X-Original-'.$xheader, $ref);
		}
	}

	if (ref($o_hdr)) {
		# $o_hdr->replace('Message-Id', "<$$".'_'.rand(time)."\@".$self->email('domain').'>') unless $msgid 
		$o_hdr->replace('X-Perlbug', "Perlbug(tron) v$Perlbug::VERSION"); # [ID ...]+
		$o_hdr->replace('X-Perlbug-Test', 'test') if $self->isatest;
		map { $o_hdr->add($_, $self->system('maintainer')) 
			unless $o_hdr->get($_) } qw(X-Errors-To Return-Path);
	}

	$self->debug(3, 'orig: '.Dumper($o_orig)."\nret: ".Dumper($o_hdr)) if $Perlbug::DEBUG;
		
	return $o_hdr; 		# Mail::Header
}


=item default

Operates on given tag, from bugdb@perl.org: we're sending this out from here.

Affects Message-Id(new), From(bugdb), Reply-To(maintainer) lines

Keeps Subject|To|Cc for later modification?

Filters anything else

    my @lines = $o_email->default($tag, @lines);

=cut

sub default {
    my $self  = shift;
    my $tag   = shift;
    my @lines = @_;

	chomp(@lines);
	my @res   = ();
    my $i_ok  = 1;
	if ($tag !~ /\w+/) {
		$i_ok = 0;
		$self->error("Invalid tag($tag) given for default($tag, @lines)");
	} else {
		if ($tag =~ /^Message-Id/io) {  		# 
            my $uid = "<$$".'_'.rand(time)."\@".$self->email('domain').'>'; 
            push(@res, $uid); 
        } elsif ($tag =~ /^From/io) {    	# 
            push(@res, $self->email('from')); 
        } elsif ($tag =~ /^Reply-To/io) {    # 
            push(@res, $self->system('maintainer')); 
		} elsif ($tag =~ /^(Subject|To|Cc|X\-Original\-)/io) { # OK, keep them
            push(@res, @lines);
        } else {                        	# filter as unwanted
            # push(@res, @lines);
        } 
		$self->debug(3, "tag($tag) defaulted to lines(@res)") if $Perlbug::DEBUG;
	}

	chomp(@res);

    return @res;
}


=item ok

    my @lines = $o_email->ok($tag, @lines);

=cut

sub ok {
    my $self = shift;
    my $tag  = shift;
    my @lines= @_;
	chomp(@lines);
	my @res = ();

	my %res = ();
	if ($tag !~ /\w+/) {
		$self->error("Invalid tag($tag) given for ok($tag, @lines)");
	} else {
		if ($tag !~ /^(To|Cc)$/io) { # reply-to?
			map { $res{$_}++ } @lines;
			$self->debug(3, "Tag NOT a To/Cc($tag): keeping original(@lines)") if $Perlbug::DEBUG;
		} else {
			my @targets = $self->get_vals('target');
			$self->debug(1, "remapping tag($tag) lines(@lines) with our targets(@targets)?") if $Perlbug::DEBUG;	
			LINE:
			foreach my $line (@lines) {
				next LINE unless $line =~ /\w+/o;
				my @o_addrs = Mail::Address->parse($line);
				foreach my $addr ( map { $_->address } @o_addrs) {
					if (grep(/$addr/i, @targets)) {	# one of ours
						my @forward = $self->forward('ok');        		# find or use generic
						map { $res{$_}++ } @forward ;  					# chunk dupes
						$self->debug(1, "ok applying tag($tag) line($line) addr($addr) -> fwds(@forward)") if $Perlbug::DEBUG;
					} else {											# keep
						$res{$line}++;
						$self->debug(1, "ok line($addr) NOT one of ours: keeping line($line)") if $Perlbug::DEBUG;	
					}
				}
			}
		}
	}

	chomp(@res = keys %res);

    return @res;
}


=item remap

Operating on a given tag, remaps (To|Cc) -> forwarding address, removes duplicates.

Attempt to remain moderately invisible by maintaining all other original headers.

    my @lines = $o_email->remap($tag, @lines); # _only_ if in target list!

=cut

sub remap {
    my $self = shift;
    my $tag  = shift;
    my @lines= @_;
	chomp(@lines);
	my @res = ();

	my %res = ();
	if ($tag !~ /^(To|Cc)$/io) { # reply-to?
		map { $res{$_}++ } @lines;
		$self->debug(3, "Tag NOT a To/Cc($tag): keeping original(@lines)") if $Perlbug::DEBUG;
	} else {
		my $o_bug   = $self->object('bug');
		my $default = quotemeta($self->email('domain')).'|'.quotemeta($self->email('bugdb'));
		my @targets = $self->get_vals('target');
		$self->debug(2, "remapping tag($tag) lines(@lines) with our targets(@targets)?") if $Perlbug::DEBUG;	
		LINE:
		foreach my $line (@lines) {
			next LINE unless $line =~ /\w+/o;
			# my ($addr) = $o_bug->parse_addrs([$line]);
			my @addrs  = $o_bug->parse_addrs([$line]); # multiple To: addrs!
			$DB::single=2;
			foreach my $addr (@addrs) {
				if ($addr =~ /$default/ or grep(/$addr/i, @targets)) {	# one of ours
					my @forward = $self->get_forward($addr);        # find or use generic
					map { $res{$_}++ } @forward ;  					# chunk dupes
					$self->debug(1, "remap applying tag($tag) line($line) addr($addr) -> @forward") if $Perlbug::DEBUG;						
				} else {											# keep
					$res{$addr}++;
					$self->debug(1, "remap line($addr) NOT one of ours -> keeping it") if $Perlbug::DEBUG;	
				}
			}
		}
	}

	chomp(@res = keys %res);

    return @res;
}


=item send_mail

Send a mail with protection.

    my $i_ok = $o_email->send_mail($o_hdr, $body);

=cut

sub send_mail {
    my $self  = shift;
    my $o_hdr = shift;	# prep'd Mail::Header
    my $body  = shift;	# 
	my $i_ok  = 0;

    $self->debug(2, "send_mail($o_hdr, body(".length($body)."))") if $Perlbug::DEBUG;
	my @to = ();
	my @cc = ();
=rjsf
	my $max = 250001; # 10001;
	if ($o_hdr->get('From') eq $self->email('from') and length($body) >= $max) {
		if (!($self->{'commands'}{'D'} == 1 || $self->{'commands'}{'L'} =~ /\w+/)) {
			$self->debug(1, "trimming body(".length($body).") to something practical($max)") if $Perlbug::DEBUG;
			$body = substr($body, 0, $max);
			$body .= "Your email exceeded maximum permitted value and has been truncated($max)\n";
		}
	}
=cut
	$o_hdr = $self->defense($o_hdr); 
	if (!(defined($o_hdr) && ref($o_hdr))) { 	# Mail::Header
		$self->error("requires a valid header($o_hdr) to send!");
	} else {
		# ($o_hdr, $body) = $self->tester($o_hdr, $body);
		@to = $o_hdr->get('To');
		@cc = $o_hdr->get('Cc') || ();
		chomp(@to, @cc);
		# $DB::single=2;
        $self->debug(1, "Mail to(@to), cc(@cc)") if $Perlbug::DEBUG;
		if ($self->isatest) { # -------------------- print
			my $o_send = Mail::Send->new;
			$self->debug(3, "Send($o_send)...") if $Perlbug::DEBUG;
			TAG:
	        foreach my $tag ($o_hdr->tags) {
				next TAG unless $tag =~ /\w+/o;
				my @lines = $o_hdr->get($tag) || ();
				foreach my $line (@lines) {
					chomp($line);
					$o_send->set($tag, $line);
				}
			}
			my $mailer = 'test';
			my $mailFH = $o_send->open($mailer) or $self->error("Couldn't open mailer($mailer): $!");
			$self->debug(3, "...fh($mailFH)...") if $Perlbug::DEBUG;
			if (defined($mailFH)) { # Mail::Mailer
				if (print $mailFH $body) {
					$i_ok = 1; # success
					$self->debug(3, "Body printed to mailfh($mailFH)") if $Perlbug::DEBUG;
				} else {
					$self->error("Can't send mail to mailfh($mailFH)");
				}
				$mailFH->close; # ? sends twice from tmtowtdi, once from pc026991, once from bluepc? 
				$self->debug(3, "Mail($mailFH) sent!(".length($body).") -> to(@to), cc(@cc)") if $Perlbug::DEBUG;
			} else {
				$self->error("Undefined mailfh($mailFH), can't mail data($body)");
			}
			$self->debug(3, "...done") if $Perlbug::DEBUG;
		} else { # live ---------------------------- send
			my $hdr = '';
			$self->debug(2, "live...") if $Perlbug::DEBUG;
        	TAG:
        	foreach my $tag (grep(/\w+/, $o_hdr->tags)) {       # each tag
                next TAG unless defined($tag) and $tag =~ /\w+/o;
                my @lines = $o_hdr->get($tag);
                chomp(@lines);
                next TAG unless scalar(@lines);
                foreach my $line (@lines) {
                	$hdr .= "$tag: $line\n";
                }
        	}
			$self->debug(3, "...mailing...") if $Perlbug::DEBUG;
			if (open(MAIL, "|/usr/sbin/sendmail -t")) {  		# :-( sigh...
				if (print MAIL "$hdr\n$body\n") {
					if (close MAIL) {
						$i_ok = 1; # success
						$self->debug(3, "Mail(MAIL) sent?(".length($body).") -> to(@to), cc(@cc)") if $Perlbug::DEBUG;
					} else {
						$self->error("Can't close sendmail");
					}
				} else {
					$self->error("Can't print to sendmail");
				} 
			} else {
				$self->error("Can't open sendmail")
			} 
			$self->debug(3, "...done($i_ok)") if $Perlbug::DEBUG;
		}
    }
	$self->debug(1, "sent(".length($body).") ok($i_ok) => to(@to), cc(@cc)") if $Perlbug::DEBUG; 
    return $i_ok;
}


=item addurls

Add urls to header object for given target and id

	my $o_hdr = $o_email->addurls($o_hdr, 'bug', $bugid);

=cut

sub addurls {
	my $self  = shift;
	my $o_hdr = shift;
	my $tgt   = shift;
	my $id    = shift || '';
	
	if (!(ref($o_hdr) && $tgt =~ /^\w+$/o && $id =~ /\w+/o)) {
		$self->error("requires header($o_hdr) target($tgt) and id($id)!");
	} else {
		my $url = $self->web('hard_wired_url');
		$o_hdr->add('X-Perlbug-Url-Bug', "$url?req=bug_id&${tgt}id=$id");
		if ($tgt eq 'bug') {
			my $perlbug = $self->web('cgi');
			$url =~ s/$perlbug/admin\/$perlbug/;
			$o_hdr->add('X-Perlbug-Admin-Url-Bug', "$url?req=bidmids&bidmids=$id");
		}
	}

	return $o_hdr;
}


=item defense

Set mail defaults for _all_ mail emanating from here, calls L<trim_to()>.

    my $o_hdr = $o_email->defense($o_hdr); 

=cut

sub defense {
    my $self  = shift;
    my $o_hdr = shift; # Mail::Header

	if (!ref($o_hdr)) {
		$self->error("requires a valid Mail::Header($o_hdr) to defend");
		undef $o_hdr;
	} else {
		my @cc = $o_hdr->get('Cc');
		foreach my $tag ($o_hdr->tags) {
			if ($tag =~ /^(To|Bcc|Cc|From|Reply-To|Return-Path)$/io) {
				my @lines = $o_hdr->get($tag) || ();
				$o_hdr->delete($tag); # if defined($o_hdr->get($tag));
				my (@o_addrs) = Mail::Address->parse(@lines);
				my @addrs = ();
				ADDR:
				foreach my $o_addr (@o_addrs) {
					my $addr = $o_addr->address;
					my $fmt  = $o_addr->format;
					push(@addrs, $fmt) if $self->ck822($addr);
				}
				chomp(@addrs);
				if ($tag eq 'To') {
					if (!(scalar(@addrs) >= 1)) {
						$self->debug(0, "!!! $tag(@lines) cleaned to (@addrs) ?!") if $Perlbug::DEBUG;
					}
				}
				$o_hdr->add($tag, join(', ', @addrs)) if scalar(@addrs) >= 1;
			}
		}
		$o_hdr = $self->trim_to($o_hdr);
		$o_hdr->cleanup if ref($o_hdr); # remove empty lines
	}

	return $o_hdr;		# Mail::Header
}


=item trim_to

Takes the header and returns it without any dodgy to, or cc addresses (or undef):

	my $o_hdr = $o_email->trim_to($o_hdr);

=cut

sub trim_to {
    my $self   = shift;
    my $o_hdr  = shift;		# Mail::Header

    if (!ref($o_hdr)) {
		$self->error("requires a valid Mail::Header($o_hdr) to trim");
		undef($o_hdr);
	} else {
		my $dodgy = $self->dodgy_addresses('to');
		my @to    = $o_hdr->get('To');
		my @orig  = $o_hdr->get('Cc');
		chomp(@to, @orig);
		my %cc = (); # trim dupes
		my $to = join('|', @to);
		%cc = map { lc($_) => ++$cc{lc($_)}} (grep(!/($to|$dodgy)/i, @orig));  
		my @cc = keys %cc;
		$o_hdr->delete('To');
		$o_hdr->delete('Cc');  
		$o_hdr->delete('Bcc'); 
		if (!(scalar(@to) >= 1)) {
			undef $o_hdr;
		    $self->error("no-one to send mail to (@to)!"); 
		} else {
			my $o_usr = $self->object('user');
			my ($xto, @xcc) = $o_usr->parse_addrs([(@to, @cc)]);
		    if (grep(/^($dodgy)$/i, $xto, @xcc)) { # final check
				undef($o_hdr);
				$self->error("Managed to find a duff address! in to(@to) cc(@cc)"); 
		    } else {
				$self->debug(1, "whoto looks ok: '@to, @cc'") if $Perlbug::DEBUG;
				$o_hdr->add('To', @to);
				$o_hdr->add('Cc', join(', ', @cc)) if scalar(@cc) >= 1; 
		    }
		} 
	}			

	return $o_hdr; 	# Mail::Header
}


=item get_forward

Operating on a single (or blank) address, returns a list of forwarding addresses.

    my $to = $o_email->get_forward('perlbug@perl.org'); # perl5-porters@perl.org

	my $to = $o_email->get_forward('perl-win32-porters@perl.org'); # perl-win32-porters@perl.org

    my $to = $o_email->get_forward();                   # perl5-porters@perl.org

    my $to = $o_email->get_forward('unknown@some.addr');# perl5-porters@perl.org

    my @to = $o_email->get_forward();                   # perl5-porters@perl.org perl-win32-porters@perl.org etc...

=cut

sub get_forward {
    my $self = shift;
    my $tgt  = shift; # perlbug@perl.com 

    my @dest = $self->forward('generic'); # default
	TYPE:
	foreach my $type ($self->get_keys('target')) { 
		next if $type eq 'generic';
		my @potential = $self->target($type); 
		if (grep(/^$tgt$/, @potential)) {
			@dest = $self->forward($type);
			last TYPE;
		} else {
			$self->debug(3, "$type not applicable(@potential)") if $Perlbug::DEBUG;
		}
	}

	$self->debug(2, "tgt($tgt) => dest(@dest)") if $Perlbug::DEBUG;

    return @dest;
}


=item header2admin

Given a Mail::Header object attempts to return a valid create admin command

	my $h_data = $o_email->header2admin($o_hdr);

=cut

sub header2admin {
	my $self  = shift;
    my $o_hdr = shift;

    my %data  = ();
	if (!ref($o_hdr)) {
		$self->error("registration requires a header object($o_hdr)");
	} else {    
		my $to 		= $o_hdr->get('To');
		my $from 	= $o_hdr->get('From');
    	my $subject = $o_hdr->get('Subject') || '';
    	my $reply   = $o_hdr->get('Reply-To') || '';
		chomp($to, $from, $subject, $reply);
		my $user = '';
		if ($to =~ /^(.+)\@.+/o) {
			$user = $1;
			$user =~ s/register//gio;
			$user =~ s/[^\w]+//go;
			$user =~ s/^_+(\w+)/$1/; 
			$user =~ s/(\w+)_+$/$1/; 
		}
		$self->debug(1, "Looking at registration request($user) from($from)") if $Perlbug::DEBUG;
		my ($o_from) = Mail::Address->parse($from);
		if (!ref($o_from)) {
			$self->error("Couldn't get an address object($o_from) from($from)");
		} else {
			my $address = $o_from->format;
			my $name 	= $o_from->name;
			chomp($address, $name); # probably uneccessary - paranoid now
			my $last  	= $name; $name =~ s/\s+/_/go;
			my $userid 	= $user || $o_from->user."_$$" || $last."_$$"; #
			my $pass 	= $userid; $pass =~ s/[aeiou]+/\*/gio;
			my $match 	= quotemeta($address);
			%data = (
				'userid' 		=> $userid,
				'name'   		=> $name,
				'password' 		=> $pass,
				'address'		=> $address,
				'match_address'	=> $match, 
			);
			$self->debug(1, "data: ".Dumper(\%data)) if $Perlbug::DEBUG;
		}
	}
    return \%data;
}


=item switch

Only handles (bugdb|perlbug)@perl.(com|org) and tracking addresses now.

B<parse_input()> now wraps this method and should be called instead.

This returns any of (B|M|bounce|nocommand|quiet) and parsable relations.

    my ($call, $opts) = $o_email->switch(Mail::Internet->new(\$STDIN); 

=cut

sub switch {
    my $self    = shift;
    my $o_int   = shift;

	my $switch  = 'quiet';  
	my $opts    = '';

    my $found   = 0;
	my $msg 	= 'zip';     
	my $bugdb   = $self->email('bugdb');
	if (!ref($o_int)) {
		$found++;
		$self->error("requires Mail::Internet($o_int) for decision"); 
	}

	my @to = $o_int->head->get('To') || '';

	if ($found == 0) {
		$self->{'attr'}{'bugid'} = '';
		my $o_bug = $self->object('bug');
		my $o_msg = $self->object('message');
		my ($o_hdr, $header, $body) = $self->splice($o_int) if ref($o_int);

		my @cc      = $o_int->head->get('Cc') || '';
    	my $from    = $o_int->head->get('From') || '';
    	my $subject = $o_int->head->get('Subject') || '';
    	my $inreply = $o_int->head->get('In-Reply-To') || '';
    	chomp($from, $subject, $inreply, @to, @cc);
		(@to = map { ($_->address) } Mail::Address->parse(@to));
		(@cc = map { ($_->address) } Mail::Address->parse(@cc)) if @cc;

		# Is there a bugid in the subject? -> REPLY
    	if ($found != 1) {
			my @subs = $o_bug->str2ids($subject);
			BID:
			foreach my $bid (@subs) {
				my @seen = $o_bug->ids("bugid = '$bid'");
				$self->debug(2, "Is this($bid) a reply to a bugid in the subject($subject)") if $Perlbug::DEBUG;
				if (scalar @seen >= 1) {
					$found++;
					$opts .= "$bid ";
					$switch = 'M'; 
					$msg = "REPLY $switch($found) from subject: ($bid) :-)";
					$self->debug(2, $msg) if $Perlbug::DEBUG; 
					last BID;
				} else {
					$self->debug(2, "Nope, bugid($bid) not found(@seen)") if $Perlbug::DEBUG;
				}
			}
		}

		# Is it a reply to an unknown/unrecognised bug (in the subject) in the db? -> REPLY
    	if ($found != 1 && $inreply =~ /\w+/o) {  
			my ($obj, @ids) = $self->messageid_recognised($inreply);
			if ($obj =~ /\w+/o || scalar(@ids) >= 1) {
				$found++;
				$switch = 'M';
				my $o_obj = $self->object($obj);
				$o_obj->read($ids[0]);
				my ($bid) = my @bids = ($o_obj->key =~ /bug/io ? ($ids[0]) : $o_obj->rel_ids('bug'));
				$opts .= "$bid ";
				$msg = "REPLY $switch($found): to previously unknown $obj(@ids) -> bugid($bid) ;-)";
			}
    	}        

		# Is it addressed to perlbug? -> NEW or BOUNCE
    	if ($found != 1) {  
        	my $match = $self->email('match');
			my @targets = $self->get_vals('target');
        	$self->debug(2, "Looking at addresses to(@to), cc(@cc) against targets(@targets)?") if $Perlbug::DEBUG;
        	ADDR:
			foreach my $line (@to, @cc) {
				next ADDR unless $line =~ /\w+/o;
				last ADDR if $found >= 1;
				my ($addr) = $o_bug->parse_addrs([$line]);
				if (grep(/$addr/i, @targets)) {	# one of ours
                	$found++;
		    		$self->debug(2, "Address($addr->$line) match :-), have we a match($match) in the body?") if $Perlbug::DEBUG;
            		if ($body =~ /$match/i) {    # new \bperl|perl\b
                		$switch = 'B';
						$msg = "NEW BUG $switch($found): Yup! perl($match) subject($subject) :-))";
						$opts = $self->message('B');
                		$self->debug(2, $msg) if $Perlbug::DEBUG;
            		} else {                            # spam?
                		$switch = 'bounce'; 
						$opts = $self->message('bounce');
                		$self->debug(2, "Nope, $switch($found): addressed to one of us, but with no match in body(".length($body).") :-||") if $Perlbug::DEBUG;
                		$msg = "Nope, $switch($found): addressed to one of us, but with no match in body(".length($body).") :-||";
            		}
        		} else {
            		$self->debug(2, "address($line) not relevant pass($found)") if $Perlbug::DEBUG;
        		}
			}
			$self->debug(2, "Addressed and bodied to us? ($found) <- (@to, @cc)") if $Perlbug::DEBUG; # unless $found == 1;
    	}
	}
	
	# Catch all -> TRASH it
    if ($found != 1) {  
        $switch = ($to[0] eq $self->email('bugdb')) ? 'nocommand' : 'quiet'; # maybe we missed something?
		$opts = $self->message('quiet');
		$msg = "IGNORE $switch($found): invalid perlbug data, potential p5p miscellanea or spam) :-|\n";
        $self->debug(2, $msg) if $Perlbug::DEBUG;
    }
    $self->debug(1, "Decision -> do_($switch, $opts) - $msg") if $Perlbug::DEBUG;

    return ($switch, $opts); # do_(bounce|[BMNPT]), '<bugid> patch close' 
}


=item assign_bugs

Assign to this admin, so many, of these unclaimed bugs.

N.B. the claimed bugs are shifted off the end of the referenced array!

    $i_ok = $o_email->assign_bugs($admin, 5, \@unclaimed);

=cut

sub assign_bugs {
    my $self    = shift;
    my $admin   = shift;
    my $num     = shift;
    my $a_unclaimed = shift;

    my $i_ok = 1;
    
	my $o_usr = $self->object('user');
    if (($admin =~ /\w+/o) && ($num =~ /^\d+$/o) && (ref($a_unclaimed) eq 'ARRAY') && (@{$a_unclaimed} >= 1)) {
        $self->debug(2, "assign_bugs($admin, $num, $a_unclaimed) args OK") if $Perlbug::DEBUG;
    } else {
        $i_ok = 0;
        $self->error("Duff args given to assign_bugs: admin($admin), num($num), a_unclaimed($a_unclaimed)");
    }
     
    # NOTICE
    my $notice = '';
    if ($i_ok == 1) {
        my ($bugdb, $maintainer, $home) = ($self->email('bugdb'), $self->system('maintainer'), $self->web('home'));
        $notice = qq|
    As an active perlbug admin, you have been assigned the following 
    (now claimed :-) bugs to categorise, and generally deal with.
	
	If you are too busy, please let '$maintainer' know, or de-ACTIVE-ate 
	yourself from the web front end at 
		
		$home
    
	For email help send an email to:
	
		To: $bugdb
		Subject: -h
	
        |;
    }
    
    # BIDS
    my @bids = ();
    my @res  = ();
    if ($i_ok == 1) {
        my %assign = ();
        my $user = $self->check_user($admin);          # setup admin as current user or not
        foreach my $it (1..$num) {          # of given bugs
            last if $it >= 5;               # Let's not frighten them all off straight away :-)
            my $bug = shift @{$a_unclaimed}; # rand $num @unclaimed
            $self->dok($admin, $bug);    # claim
            push(@res, $self->dob($bug));# feedback
            push(@bids, $bug);           # ref
            $self->debug(2, "Admin($admin), claimed bug($bug)") if $Perlbug::DEBUG;
        }
    }

    if ($i_ok == 1) {
        push(@res, $self->doo);
	}

    # SEND MAIL
    if ($i_ok == 1) {
		my $address = $o_usr->read($admin)->data('address');
		my $data = join('', @res);
        my $o_hdr = $self->get_header;
		$o_hdr->add('To' => $address);
        $o_hdr->add('Subject' => $self->system('title').' - admin sheet (@bids)');
        $i_ok = $self->send_mail($o_hdr, "$notice\nBUGIDs: (@bids)\n\n$data\n\n");
    }

    return $i_ok;
}   # done assign_bugs


=item parse_header

Scan a typical *@bugs.perl.org header - instead of parse_input($subject).

	my $h_cmd = $o_email->parse_header($o_hdr, $body); 
		
To: line can be any of:

	close_<bugid>_@bugs.perl.org  = bug admin request
		
	register@bugs.perl.org        = admin registration request

	admins@bugs.perl.org          = admin mail forward

Subject: line may look like:

	-h -o

	-H -d2 -l -A close 20000721.002 lib -r patch -e some@one.net 

Unrecognised commands will be passed to bugmongers (should possibly return help instead?)

=cut

sub parse_header {
	my $self  = shift;
	my $o_hdr = shift; 	# close_<bugid>_install | register | ...
	my $body  = shift;
	my %cmd   = ();

	my %flags = ();
	my $admin = $self->isadmin ? 'a' : 'v';
	foreach my $tgt (qw(group osname severity status)) {
		my $target = '^('.join('|', map { substr($_, 0, 4) } 
			grep(/\w+/, $self->object($tgt)->col('name'))).')';
		$flags{$target} = $admin;
	}
	my %commands = %{$self->email('commands')};
	my %map = ( # Configuration ?
		# '^admins'				=> 'v',
		# '^bug'				=> 'B',
		%commands, 
		%flags,
		$self->dodgy_addresses('test') => 'j',
	);
	$self->debug(3, "map: ".Dumper(\%map)) if $Perlbug::DEBUG;

	my @bugids = ();
	my ($to, $cc, $subject, $bugids) = ('', '', '', '');

	# $DB::single=2;
	# COMMANDS
	if (!ref($o_hdr)) {
		$self->error("requires a Mail::Header object($o_hdr)");
	} else {
		($to, $subject) = ($o_hdr->get('To'), $o_hdr->get('Subject'));
		my ($from, $msgid) = ($o_hdr->get('From'), $o_hdr->get('Message-Id'));
		my @cc = $o_hdr->get('Cc'); @cc = () unless @cc;
		chomp($to, $from, $subject, @cc, $msgid);
		$cc = join(' ', @cc);
		$self->debug(1, "to($to), subject($subject), from($from), cc(@cc), msgid($msgid)") if $Perlbug::DEBUG;
		my $domain = quotemeta($self->email('domain'));
		($to) = grep(/$domain/, $to, @cc); # use the first appropriate addr
		$to =~ s/\@$domain//;
		my $origin = $self->email('from'); $origin =~ s/^(.+)?\@.+$/$1/;

		map { $cmd{$map{$_}} = lc($to) if $to =~ /$_/i } keys %map; # n.b. sequence

		# special cases:
		if ($to =~ /^bugdb.*/io) {		# allow old style through 
			%cmd = %{$self->SUPER::parse_input($subject)};
		} elsif ($to =~ /^query/io) {
			$cmd{'q'} = $subject;
		}
		$self->debug(2, "mapped: ".Dumper(\%cmd)) if $Perlbug::DEBUG;
	}

	# BUGIDs
	if (ref($o_hdr)) {
		my $o_bug = $self->object('bug');
		$bugids = join(' ', @bugids = ($o_bug->str2ids($to), $o_bug->str2ids($subject)));
		my $keys  = join('', keys %cmd);
		if ($keys =~ /B/o) {
			my $match = $self->email('match');
			if ($body !~ /$match/) {
				$self->debug(1, "no match($match) in body($body)!") if $Perlbug::DEBUG;
				delete $cmd{'B'};
			$cmd{'bounce'} = $self->message('nomatch');
			}
		} elsif ($keys =~ /([MNPT])/o) {
			my $key = $1;
			if (scalar(@bugids) >= 1) {
				# add them if they're not there yet
				foreach my $b (@bugids) {
					$cmd{$key} .= " $b" unless $cmd{$key} =~ /$b/;
				}	
			} else {
				$self->debug(1, "no bugids($bugids - @bugids) in To($to), Cc($cc) or Subject($subject)!") if $Perlbug::DEBUG;
				delete $cmd{$key};
				$cmd{'bounce'} = $self->message('nobugids');
			} 
		}
	}

	# $DB::single=2;
	# CHECK
	if (!(scalar(keys %cmd) >= 1)) {
		$self->debug(1, "no commands found in to($to) => 'H' ".Dumper(\%cmd)) if $Perlbug::DEBUG;
		$cmd{'H'} = $self->message('nocommand');
	}
	$self->debug(1, "PH: ".Dumper(\%cmd)) if $Perlbug::DEBUG;

	return \%cmd;
}


=item in_master_list

Checks given address against ok-to-be-administrator email address list

	my $i_ok = $o_obj->in_master_list($address, [$list]);

=cut

sub in_master_list {
	my $self = shift;
	my $addr = shift;
	my @list = @_;

	my $i_ok = 0;
	my $o_usr = $self->object('user');
	my ($address) = $o_usr->parse_addrs([$addr]);
	if ($address !~ /\w+/) {
		$self->debug(0, "address($addr) not parseable($address)") if $Perlbug::DEBUG;
	} else {
		my $list = '';
		if (!(@list >= 1)) {	
			$list = $self->directory('config').$self->system('separator').$self->email('master_list');
			my $o_log = Perlbug::File->new($list);
			@list = $o_log->read($list);
		}
		my $found = grep(/^$address$/i, @list);
   		$i_ok = ($found >= 1) ? 1 : 0;
		$self->debug(1, "found($found) addr($addr)->address($address) in $list list(".@list.")") if $Perlbug::DEBUG;
	}

	return $i_ok;
}


=item reminder

Send out reminders to relevant parties for given bugid

	my $i_ok = $o_email->reminder($bid, @addresses);

=cut

sub reminder {
    my $self    = shift;
    my $bid     = shift;
	my @addrs   = @_;
	my $ret     = 0;

    if (!(scalar(@addrs) >= 1)) {
        $self->debug(0, "Duff addrs(@addrs) given to reminder") if $Perlbug::DEBUG; 
    } else {
        my $o_bug = $self->object('bug')->read($bid);
		if (!($o_bug->READ)) {
			$self->debug(0, "Duff bid($bid) for reminder!") if $Perlbug::DEBUG;
		} else { 
			my $o_usr = $self->object('user');
			my $o_grp = $self->object('group');
			my ($title, $bugdb, $maintainer, $home) = 
				($self->system('title'), $self->email('bugdb'), $self->system('maintainer'), $self->web('hard_wired_url'));
			my ($statusid) = $o_bug->rel_ids('status');
			my ($status) = $o_bug->object('status')->id2name([$statusid]);

			my ($gid) = my @gids = $o_bug->rel_ids('group');
			my ($group) = join(', ', $o_grp->id2name(\@gids));
			 
			# NOTICE
			my $bugreport = $o_bug->format;
			my $notice = qq|
		This is a $title status($status) reminder for an outstanding 
		bug, a report for which is appended at the base of this email.

		If the the status of this bug is in any way incorrect, please
		inform an administrator of the $title system.

		Further data relating to this bug($bid) may be found at:

			$home/perlbug.cgi?req=bidmids&bidmids=$bid

		The group($group) of administrators responsible for this bug is:

			$home/perlbug.cgi?req=group_id&group_id=$gids[0]
		
		For email help send an email to:
		
			To: $bugdb
			Subject: -H

		Bug report (current status) follows:
		$bugreport
			|;
			my $o_hdr = $self->get_header;
			$o_hdr->add('To' => $maintainer);
			$o_hdr->add('Cc' => join(', ', @addrs)) if @addrs;
			$o_hdr->add('Subject' => $self->system('title')." - reminder of bug($bid) status");
			$ret = $self->send_mail($o_hdr, "$notice");
		}
	}

    return $ret;
}


# -----------------------------------------------------------------------------
# do.()'s
# -----------------------------------------------------------------------------

=item doB

Deal with a new bug

	my $bugid = $o_email->doB($h_args);

=cut

sub doB {
    my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};

	$self->debug(1, "NEW BUG: ".Dumper($h_args)) if $Perlbug::DEBUG;

	my $o_bug = $self->object('bug');
	my $bugid = $self->SUPER::doB($h_args);

	if ($bugid) {
		$o_bug->read($bugid); 
		my $h_data = $self->scan($args{'body'});

		my @addrs  = $o_bug->parse_addrs([$args{'to'}]); # multiple To: addrs
		push(@addrs, $o_bug->parse_addrs([$args{'cc'}])) if $args{'cc'};

		if (ref($h_data) ne 'HASH') {
			my $err = 'SCAN failure';
		} else {
			if ($args{'subject'} =~ /^\s*OK:/io) {
				$$h_data{'status'}{'names'}{'ok'}++;
				$$h_data{'group'}{'names'}{'install'}++;
			}
			if ($args{'subject'} =~ /^\s*Not OK:/io) {
				$$h_data{'status'}{'names'}{'notok'}++;
				$$h_data{'group'}{'names'}{'install'}++;
			}
			if ($args{'to'} =~ /dailybuild/io) {
				$$h_data{'group'}{'names'}{'dailybuild'}++;
			}
			my $i_rel = $o_bug->relate($h_data);
		}
	}

    return $bugid;
}


=item doD

Mail me a copy of the latest database dump, with 8-figure time filter

	my $i_ok = $o_email->doD([($date, $addr)]);

=cut

sub doD {
	my $self   = shift;
	my $a_args = shift;
	my ($date, $target) = @{$a_args};

	my $i_ok = 1;
	my $file = $self->directory('arch').'/'.$self->database('latest');

	if ($date !~ /^\s*(\d+)\s*$/) { # incremental
		$self->debug(2, "Full database dump requested($date)") if $Perlbug::DEBUG;
	} else {	
		$date = $1;
		$file = File::Spec->canonpath($self->directory('arch')."/Perlbug.sql.${date}.gz");
		$i_ok = $self->SUPER::doD($date);
		if ($i_ok != 1) {
			$self->error("Database dump($file) request($date) failed to complete($i_ok)!");
		}
	} 
	if ($i_ok == 1) {
		my $title   = $self->system('title');
		if ($target!~ /\w+/) {
			$i_ok = 0;
		} else {
			my $size = -e $file;
			my $cmd  = "uuencode $file $file | mail -s '$title db dump' $target"; # yek! :-/
			$self->debug(2, "doD cmd($cmd)") if $Perlbug::DEBUG;
			$i_ok = !system($cmd);
			if ($i_ok == 1) {
				my $hinweis = qq|$title database($size) dump(-D $date) mailed($i_ok) to '$target'

Incremental updates may be retrieved using the following format:

	-D                  \# everything 
	-D 2000             \# everything since 1st Jan 2000
	-D 20001120         \# everything since 20th Nov 2000
	-D 20001120153527   \# everything since 27 seconds after 3.35pm on 20th Nov 2000

N.B.: If you\'ve loaded the database before 2.26, the structure has changed, you may want to trash it and start all over again.  Alternatively ./scripts/fixit -> mig can help with the migration.

|;
				# $self->result($hinweis);
			} else {
				$self->error("doD cmd($cmd) failed($i_ok) $!");
			} 
		}
	}
	$self->debug(2, "doD i_ok($i_ok)") if $Perlbug::DEBUG;

	return $i_ok;
}


=item doE

Send an email renotification(->p5p) about this data, as if the email was newly recieved.

	my $i_ok = $o_obj->doE(\%input);

=cut

sub doE {
	my $self   = shift;
	my $h_args = shift;
	my %args   = %{$h_args};
	my $i_res  = 0;

	$self->debug(1, "Re-NOTIFY: ".Dumper($h_args)) if $Perlbug::DEBUG;
	
	my $msgid = $args{'email_msgid'};
	if ($msgid) {
		my ($obj, @ids) = $self->messageid_recognised($msgid);
		$i_res += $self->notify($obj, @ids);
	}

	return $i_res;
}


=item doh

Wraps help message

	my $help = $o_email->doh;

=cut

sub doh {
	my $self   = shift;
	my $h_args = shift;
	my @args   = (ref($h_args) eq 'HASH') ? %{$h_args} : ();

	my $res = $self->SUPER::doh({
		'D' => 'Database dump retrieval by email, with optional date filter (20001225)', 
		'H' => 'Heavier Help ()',
		'j' => 'just test a response ()', 
		# 'p' => 'propose changes to the following (<bugids>)',
	});

	return $res;
}


=item doH

Returns more detailed help.

	my $help = $o_email->doH;

=cut

sub doH {
    my $self   = shift;
	my $h_args = shift;
	my @args   = (ref($h_args) eq 'HASH') ? %{$h_args} : ();

    my $HELP = $self->help; 
    $HELP .= join('', $self->read('mailhelp'));

	return $HELP;
}


=item doj 

Just test for a response

	my @res = $o_email->doj(@args); 

=cut 
	
sub doj {
	my $self   = shift;
	my $h_args = shift;
	my %mail   = %{$h_args};
	my $i_ok   = 1;

	my $title   = $self->system('title');
	my $version = $self->version;
	my $domain  = $self->email('domain');

	my $body = qq|	
	Help available from 'help\@$domain'	

    Testing response from $title $version - your email below:

$mail{'header'}

$mail{'body'}
	|;
	
    my $header = join('', $self->read('header'));
	$header =~ s/Perlbug::VERSION/ - v$Perlbug::VERSION/io;
    my $footer = join('', $self->read('footer'));
	my $o_reply = $self->get_header($mail{'header'});
	$o_reply->replace('To', $self->from($mail{'replyto'}, $mail{'from'}));
	$o_reply->replace('Subject', "$title test response - $mail{'subject'}");
	$i_ok = $self->send_mail($o_reply, $header.$body.$footer); 

	return $i_ok;
}


=item dobounce

Deal with a bounced mail

	my $bouncedbugid = $o_email->dobounce($h_args);

=cut

sub dobounce {
    my $self   = shift;
	my $h_ref  = shift;
	my %mail   = %{$h_ref};
	my $bugid  = '';

	my $o_bug   = $self->object('bug');
    my $rebound = $self->from($mail{'from'});
    $self->debug(1, "BOUNCE: subject($mail{'subject'}) into db for posterity...") if $Perlbug::DEBUG;

	$o_bug->create({
		'bugid'		=> $o_bug->new_id,
		'subject'	=> '',
		'sourceaddr'=> '',
		'toaddr'	=> '',
		'header'	=> '',
		'body'		=> '',
		'email_msgid'=> '',
		%mail
	});

	if (!($o_bug->CREATED)) {
		$self->error("failed to create new bounce bug");	
	} else {
		$bugid = $o_bug->oid;
		# register bounced mails as new onhold notabug low priority bugs
		$self->{'attr'}{'bugid'} = $bugid;
		$o_bug->relation('status')->_assign(['closed']);
		$o_bug->relation('severity')->_assign(['none']);
		$o_bug->relation('group')->_assign(['bounce']);
		$o_bug->relation('address')->_assign([$mail{'to'}, $mail{'cc'}]);
		my ($title, $bugtron, $hint) = ($self->system('title'), $self->email('bugtron'), $self->email('hint'));
        my $body = qq|
    This email address is for reporting $title bugs via $bugtron.
    
    Please address your mail appropriately and include appropriate data 
    as per the distributed documentation.  Original mail appended below. 
    
    $hint
    -----------------------------------------------

$mail{'body'}
        |;

		my $header = $o_bug->data('header');
		my $o_hdr  = $self->setup_int($header)->head;
		my $o_reply = $self->get_header($o_hdr);
		$o_reply->replace('To', $self->from($mail{'replyto'}, $mail{'from'}));
		$o_reply->replace('Subject', "Bounce - $mail{'subject'}");
		my $i_ok = $self->send_mail($o_reply, $body);
    }

    return $bugid;
}



=item donocommand

Deal with a mail with no commands found

	my $reply = $o_email->donocommand($h_args);

=cut

sub donocommand {
    my $self   = shift;
	my $h_ref  = shift;
	my $reason = 'not-sorted';
	my %mail   = %{$h_ref};
	my $i_ok   = 1;

	my ($title, $bugtron, $bugdb, $domain) = (
		$self->system('title'), $self->email('bugtron'), $self->email('bugdb'), $self->email('domain')
	);

	my $reply = qq|
    This email address is for administrating $title bugs via $bugtron.

    There appeared to be no commands given, in the mail shown below.

    For instructions on how to use the email interface send an email:
	
		To: $bugdb
		Subject: -h

    Or 

		To: help\@$domain
	
    --------------------------------------------------------------------

    Your original email follows:

$mail{'header'}

$mail{'body'}
    |;

	return $reply;

	my $o_reply = $self->get_header($mail{'header'});
	$o_reply->replace('To', $self->from($mail{'replyto'}, $mail{'from'}));
	$o_reply->replace('Subject', "No commands found - $mail{'subject'}");
	$i_ok = $self->send_mail($o_reply, $reply);

    return $i_ok;
}


=item doquiet

Drop out quietly, no entry in database, silent dump into black hole;

	my $i_ok = $o_email->doquiet($h_args);

=cut

sub doquiet {
    my $self = shift;
	my @args = @_; 

	$self->debug(1, "QUIET (".join(', ', @_).") logged(pass through), not in db:\n") if $Perlbug::DEBUG;

	return 'quiet ok';
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 1999 2000 2001

=cut

# 
1;


