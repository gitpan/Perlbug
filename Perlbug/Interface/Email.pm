# 
# $Id: Email.pm,v 1.91 2001/04/26 13:19:48 perlbug Exp $ 
# 

=head1 NAME

Perlbug::Interface::Email - Email interface to perlbug database.

=cut

package Perlbug::Interface::Email;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.91 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
my $DEBUG = $ENV{'Perlbug_Interface_Email_DEBUG'} || $Perlbug::Interface::Email::DEBUG || '';
$|=1;

use Data::Dumper;
use File::Spec; 
use Mail::Address;
use Mail::Send;
use Mail::Header;
use Mail::Internet;
use Sys::Hostname;
use Perlbug::File;
use Perlbug::Interface::Cmd;
@ISA = qw(Perlbug::Interface::Cmd Perlbug::Base);
my $o_HEADER = 'non_existent_header_object';
my $o_MAIL = 'non_existent_mail_object';


=head1 DESCRIPTION

Email interface to perlbug database.

=head1 SYNOPSIS

    use Perlbug::Interface::Email;

    use Mail::Internet;

    my $o_mail = Mail::Internet->new(*STDIN); 

    my $o_perlbug = Perlbug::Interface::Email->new($o_mail);    

    my $call = $o_perlbug->switch;

    my $result = $o_perlbug->$call($o_mail); 

    print $result; # =1 (hopefully :-)


=head1 METHODS

=over 4

=item new

Create new Perlbug::Interface::Email object:

    my $pb = Perlbug::Interface::Email->new($o_mail); # Mail::Internet

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
	my $o_mail = shift || '';

	my $self = Perlbug::Interface::Cmd->new();
	$DEBUG = $Perlbug::DEBUG || $DEBUG; 

	# $self->system('cachable', 0); # rjsf
    # my $matches = $self->directory('config').'/Matches';
    # my ($ok, $prefs) = $self->get_config_data($matches);
	$self = { %{$self}, # de-bless!?
		'attr' => { # rjsf !!!
			'cc'		=> '',       # 
			'commands'	=> {},       # commands hash  
			'address'	=> '',
			'mailing'	=> 1,        # presumably - not if historical?
			'bugid'	=> 'NULL',   # 
			'messageid'	=> 'NULL',   # 
		},
	};
	bless($self, $class);
	$self->_original_mail($o_mail);
	return $self;
}


sub clean_cache {
	my $self = shift;

	$self->SUPER::clean_cache('sql', 'force');

    return $self;
}


=item _original_mail

Maintain original

=cut

sub _original_mail { # Mail::Internet
	my $self = shift;
	my $o_mail = shift;

	if (ref($o_mail)) {
		$o_MAIL = $o_mail;
		my $o_dup = $o_mail->head->dup;
		$self->_original_header($o_dup);
	}
	return $o_MAIL; # Mail::Internet
}

sub _original_header { # Mail::Header
	my $self = shift;
	my $o_hdr = shift || '';

	$o_HEADER = $o_hdr if ref($o_hdr);
	return $o_HEADER; # Mail::HEADER
}

=item original

Returns original field/s from header

=cut

sub original { # get lines
	my $self = shift;
	my $tag = shift || '';

	my $o_hdr = $self->_original_header;
	my @data = ();
	if (ref($o_hdr) and $tag =~ /\w+/) {
		@data = $o_hdr->get($tag);
		chomp(@data);
	};
	return @data; # line/s
}

sub _duff_mail { # just for tests...
	my $self = shift;
	my $date		= localtime(time);

	my $hostname	= hostname;
	my $o_hdr = Mail::Header->new;
	$o_hdr->add('To', $self->system('maintainer'));
	$o_hdr->add('From', $self->email('from'));
	$o_hdr->add('Message-Id', 'duff_'.$$.'_'.rand(time).'@'.$hostname);
	$o_hdr->add('Subject', 'Perlbug internal message');
	my @body = (
		"Test message from Perlbug installation test run at '$hostname'",
		$date, '',
	);
	my $o_mail = Mail::Internet->new('Header' => $o_hdr, 'Body' => \@body);
	return $o_mail; # Mail::Internet
}


=item mailing

Switch mailing on/off, and sets isatest(1)

=cut

sub mailing { # 1|0
	my $self = shift;
	my $flag = shift;

	if (defined $flag and $flag =~ /^([01])$/) {
		$self->{'attr'}{'mailing'} = $1;
		$self->debug(2, "mailing set to '$1'") if $DEBUG;
		if ($self->{'attr'}{'mailing'} != 1) {
			my ($isatest) = ($self->current('isatest') == 2) ? 2 : 1;
			($isatest) = $self->current({'isatest', $isatest});
			$self->debug(1, "mailing test($isatest)") if $DEBUG;
		}
	}		
	return $self->{'attr'}{'mailing'};
}


=item splice

Returns the original mail spliced up into useful bits, set from L<parse_mail> or L<switch>, or given as arg.

    my ($o_hdr, $header, $body) = $self->splice; # or splice($o_mail);

=cut

sub splice { # splice o_mail into useful bits
    my $self = shift;
	my $mail = shift || $self->_mail;

	unless (ref($mail)) {	
		$self->error("Can't splice mail($mail) object!")
	}
    $mail->remove_sig if ref($mail);
    my @data = (
        $mail->head,
        join('', @{$mail->head->header}),
        join('', @{$mail->body}),
    );
	return @data;
}


=item parse_mail

Given a mail (Mail::Internet) object, parses it into command hash, 
also checks the header for X-Perlbug loop and the address of the sender via L<check_user>.

    my ($h_commands, $body) = $pb->parse_mail($o_mail);

=cut

sub parse_mail { # bugdb@perl.org|*@bugs.perl.org -> includes check_user
    my $self = shift;
	my $o_mail = shift || $self->_mail;

	my $h_cmds = {};
    my ($o_hdr, $header, $body) = $self->splice($o_mail);
    if ($self->check_incoming($o_hdr)) {
		my $commands = '-h'; # :-) 
        my $user  = $self->check_user($o_hdr->get('From')); # sets admin
        my $debug = ($self->isadmin eq $self->system('bugmaster')) 
			? "user($user), debug(".$self->current('debug')."), version($Perlbug::VERSION), ref($$, $0) $o_hdr\n" 
			: '';
        $self->debug(0, $debug) if $DEBUG;
        ($commands, $body) = $self->scan_header($o_hdr, $body);
		$h_cmds = $self->parse_commands($commands, $body); # -a <bugids...> close install
	}
	$self->{'attr'}{'commands'} = $h_cmds if ref($h_cmds) eq 'HASH';
    return ($h_cmds, $body);
}


=item from

Sort out the wheat from the chaff, use the first valid ck822 address:

	my $from = $self->from($replyto, $from, @alternatives);

=cut

sub from { # set from given 
	my $self  = shift;
	my @addrs = @_;
	chomp(@addrs);

	my $from = '';
	my $i_ok = 1;
	if (scalar(@addrs) >= 1) {
		my @fandt = ($self->get_vals('target'), $self->get_vals('forward'));
		my (@o_addrs) = Mail::Address->parse(@addrs);
		ADDR:
		foreach my $o_addr ( @o_addrs ) { # or format?
			my ($addr) = $o_addr->address;	
			my ($format) = $o_addr->format;	
			chomp($addr, $format);
			next ADDR unless $addr =~ /\w+/;
			next ADDR if grep(/^$addr$/i, @fandt, $self->email('bugdb'), $self->email('bugtron'));
			next ADDR unless $self->ck822($addr);
			$from = $format;
			$self->debug(2, "from address($from)") if $DEBUG;
			last ADDR;
		}
	}
	return $from;
}


=item check_incoming

Checks (incoming) email header against our X-Perlbug flags, also slurps up the Message-Id for future reference.

    my $i_ok = $o_perlbug->check_incoming($o_hdr); # 

=cut

sub check_incoming { # incoming
    my $self  = shift;
    my $o_hdr = shift;

    my $i_ok  = 1;
    $self->debug(3, "check_incoming($o_hdr)") if $DEBUG;
    my $dodgy = $self->dodgy_addresses('from'); 
	my $tests = $self->dodgy_addresses('test');
    if (!ref($o_hdr)) {
		$i_ok = 0;
		$self->error("No hdr($o_hdr) given");
	} else {
        $self->{'attr'}{'message-id'} = $o_hdr->get('Message-Id'); # ref
        my $perlbug = $o_hdr->get('X-Perlbug') || '';
		my $o_to  = Mail::Address->parse($o_hdr->get('to') || '');
		my $o_from  = Mail::Address->parse($o_hdr->get('From') || '');
		my $o_reply = Mail::Address->parse($o_hdr->get('Reply-To') || '');
		my $to      = ref($o_to)   ? $o_to->address    : $o_hdr->get('To') || '';
		my $from    = ref($o_from) ? $o_from->address  : $o_hdr->get('From') || '';
		my $reply   = ref($o_reply)? $o_reply->address : $o_hdr->get('Reply-To') || '';
		chomp($perlbug, $to, $from, $reply);
        if ($from =~ /$dodgy/i) {
            $i_ok = 0;
            $self->debug(0, "From one of us ($from), not good"); 
        }
		if ($reply =~ /$dodgy/i) {
            $i_ok = 0;
            $self->debug(0, "Reply-To one of us ($reply), not good"); 
        }
        if ($perlbug =~ /\w+/i) {
            $i_ok = 0;
            $self->debug(0, "X-Perlbug($perlbug) found, not good!"); 
        }
		if ($to =~ /$tests/i) {
			$self->isatest(1);
			$self->debug(0, "X-Test mail -> setting test flag") if $DEBUG;
		}
    } 
    return $i_ok;
}


=item check_user

Checks the address given (From usually) against the db_user table, sets user or admin access priviliges via the switches mechanism accordingly. 

Returns admin name

    my $admin = $pb->check_user($mail->('From')); # -> user_id || blank

=cut

sub check_user { # from address against database
    my $self = shift;
    my $given = shift;

    $self->debug(3, "check_user($given)") if $DEBUG;

	my $o_usr = $self->object('user');
	my ($address) = $o_usr->parse_addrs([$given]);
	my @uids = $o_usr->ids;
	my @addrs= $o_usr->col('match_address');
    USER:
    foreach my $uid (@uids) {
		$o_usr->read($uid);
		if ($o_usr->READ) {
			my $userid = $o_usr->data('userid');
       		my $match_address = $o_usr->data('match_address');
			if ($address =~ /$match_address/i) { # an administrator
				$self->current({'admin', $userid});
				$self->debug(1, "Setting admin($userid) switches") if $DEBUG;
				my $switches = $self->system('user_switches').$self->system('admin_switches');
				$self->current({'switches', $switches});
				last USER;
			}
        } 
    }
	$self->current({'switches', $self->system('user_switches')}) unless $self->isadmin;
	return $self->isadmin;
}


=item return_info

Takes data ($a_stuff), which may be a ref to the result array, and mails 
it to the From or Reply-To address, Cc:-ing it to any address given by the C<-e> flag.  

    my $i_ok = $pb->return_info($o_mail, $a_stuff);

=cut

sub return_info { # -> from bugdb send_mail
    my $self  = shift;
	my $mail  = shift || $self->_mail;
    my $stuff = shift;

    my $data = (ref($stuff) eq 'ARRAY') ? join('', @{$stuff}) : $stuff;
    $self->debug(3, 'return_info: length('.length($data).')') if $DEBUG;
    my ($o_hdr, $head, $body) = $self->splice($mail);
    $data =~ s/^\s*\.\s*$//g;   # replace troublesome (in email) dots
    my ($title, $maintainer) = ($self->system('title'), $self->system('maintainer'));
	my $from = $o_hdr->get('From');
	my $subject = $o_hdr->get('Subject');
	my $reply = $o_hdr->get('Reply-To');
	chomp($from, $subject, $reply);
    my $header = join('', $self->read('header'));
	$header =~ s/Perlbug::VERSION/ - v$Perlbug::VERSION/i;
    my $footer = join('', $self->read('footer'));
    my $o_reply = $self->get_header($o_hdr);
	$o_reply->replace('To', $self->from($reply, $from));
    $o_reply->replace('Subject', "$title response: $subject");
    $o_reply->delete('Cc');
	$o_reply->add('Cc', $self->{'attr'}{'cc'}) if defined($self->{'attr'}{'cc'} and $self->{'attr'}{'cc'} =~ /\w+/);
    my $i_ok = $self->send_mail($o_reply, $header.$data.$footer); #
	return $i_ok; # 0|1
}            


=item _mail

Get and set the incoming mail object (Mail::Internet)

Returned (used) via L<splice()>

=cut

sub _mail { # 
	my $self = shift;
	my $o_mail = shift || $self->_original_mail;

	return $o_mail; # Mail::Internet
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
		next unless $tgt =~ /\w+/;
        my $first  = sprintf('%-15s', ucfirst($tgt).':'); 
        my @notify = $self->target($tgt);
		my $notify = join(' or ', @notify);
        my $reply  = $self->forward($tgt);
        $spec .= qq|${first} ${notify} -> ($reply)\n|;
    }
	
	return $spec;
}


=item doj

Just tracks a message by wrapping a reply call, no Note, forward, notify or anything else

	my $i_ok = $o_email->doj($o_int);

=cut

sub doj { # just track it
	my $self = shift;
    my $mail = shift || $self->_mail;

    my ($o_hdr, $header, $body) = $self->splice($mail);

	my $to   = $o_hdr->get('To');
	my $subj = $o_hdr->get('Subject');
	
	my $o_bug = $self->object('bug');
	my @bids = $o_bug->str2ids($to);
	foreach my $bid (@bids) {
		$self->{'attr'}{'bugid'} = $bid;   # yek
		my $res = $self->do_reply($mail);
	}

	my $res = "Message recieved against(@bids)";

	return $res;
}


=item doh

Wraps help message

=cut

sub doh { # help wrapper and modifier
	my $self = shift;

	my $res = $self->SUPER::doh(
		'D' => 'Database dump retrieval by email, with optional date filter (20001225)', 
		'e' => 'email a copy to me too (emaila.copy@to.me.too.com)',
		'H' => 'Heavier Help ()',
		'j' => 'track()',
		# 'p' => 'propose changes to the following (<bugids>)',
	);

	return $res;
}


=item doH

Returns more detailed help.

=cut

sub doH { # help wrapper (verbose)
    my $self = shift;

    my $HELP = $self->help;
	$HELP .= $self->read('mailhelp');

	return $HELP;
}


=item get_header

Get new perlbug Mail::Header, filled with appropriate values, based on given header.

	my $o_hdr = $o_email->get_header();						   # completely clean

	my $o_hdr = $o_email->get_header($o_old_header);           # plain (coerced as from us)
	
	my $o_hdr = $o_email->get_header($o_old_header, 'remap');  # maintain headers (nearly transparent)

=cut

sub get_header {
	my $self   = shift;
	my $o_orig = shift || '';
	my $context= shift || 'default'; # ...|remap|ok

	my $i_ok   = 1;
	my $o_hdr  = Mail::Header->new;
	if (ref($o_orig)) { # partially fresh
		foreach my $tag ($o_orig->tags) { 
			my @lines = $o_orig->get($tag);
			my @res = $self->$context($tag, @lines); # default|remap|ok
			$self->debug(2, "tag($tag) lines(@lines) -> context($context) -> res(@res)") if $DEBUG;
			$o_hdr->add($tag, @res) if scalar(@res) >= 1;
		}
	}

	undef $o_hdr unless $i_ok == 1; 
	return $o_hdr; 		# Mail::Header
}


=item default

Operates on given tag, from bugdb@perl.org: we're sending this out from here.

Affects Message-Id(new), From(bugdb), Reply-To(maintainer) lines

Keeps Subject|To|Cc for later modification?

Filters anything else

    my @lines = $self->default($tag, @lines);

=cut

sub default { # modify given tag, line
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
		if ($tag =~ /^Message-Id/i) {  		# 
            my $uid = "<$$".'_'.rand(time)."\@".$self->email('domain').'>'; 
            push(@res, $uid); 
        } elsif ($tag =~ /^From/i) {    	# 
            push(@res, $self->email('from')); 
        } elsif ($tag =~ /^Reply-To/i) {    # 
            push(@res, $self->system('maintainer')); 
		} elsif ($tag =~ /^(Subject|To|Cc|X\-Original\-)/i) { # OK, keep them
            push(@res, @lines);
        } else {                        	# filter as unwanted
            # push(@res, @lines);
        } 
		$self->debug(3, "tag($tag) defaulted to lines(@res)") if $DEBUG;
	}
	chomp(@res);
    return @res;
}


=item ok

    my @lines = $self->ok($tag, @lines);

=cut

sub ok { # modify given tag, line
    my $self = shift;
    my $tag  = shift;

    my @lines= @_;
	chomp(@lines);

	my %res = ();
	if ($tag !~ /\w+/) {
		$self->error("Invalid tag($tag) given for ok($tag, @lines)");
	} else {
		if ($tag !~ /^(To|Cc)$/i) { # reply-to?
			map { $res{$_}++ } @lines;
			$self->debug(4, "Tag NOT a To/Cc($tag): keeping original(@lines)") if $DEBUG;
		} else {
			my @targets = $self->get_vals('target');
			$self->debug(0, "remapping tag($tag) lines(@lines) with our targets(@targets)?") if $DEBUG;	
			LINE:
			foreach my $line (@lines) {
				next LINE unless $line =~ /\w+/;
				my @o_addrs = Mail::Address->parse($line);
				foreach my $addr ( map { $_->address } @o_addrs) {
					if (grep(/$addr/i, @targets)) {	# one of ours
						my @forward = $self->forward('ok');        		# find or use generic
						map { $res{$_}++ } @forward ;  					# chunk dupes
						$self->debug(1, "applying ok tag($tag) line($line) addr($addr) -> fwds(@forward)") if $DEBUG;
					} else {											# keep
						$res{$line}++;
						$self->debug(1, "line($addr) NOT one of ours: keeping line($line)") if $DEBUG;	
					}
				}
			}
		}
	}
	my @res = keys %res;
	chomp(@res);
    return @res;
}


=item remap

Operating on a given tag, remaps (To|Cc) -> forwarding address, removes duplicates.

Attempt to remain moderately invisible by maintaining all other original headers.

    my @lines = $self->remap($tag, @lines); # _only_ if in target list!

=cut

sub remap { # modify given tag, line
    my $self = shift;
    my $tag  = shift;

    my @lines= @_;
	chomp(@lines);

	my %res = ();
	if ($tag !~ /^(To|Cc)$/i) { # reply-to?
		map { $res{$_}++ } @lines;
		$self->debug(4, "Tag NOT a To/Cc($tag): keeping original(@lines)") if $DEBUG;
	} else {
		my $o_bug = $self->object('bug');
		my @targets = $self->get_vals('target');
		$self->debug(2, "remapping tag($tag) lines(@lines) with our targets(@targets)?") if $DEBUG;	
		LINE:
		foreach my $line (@lines) {
			next LINE unless $line =~ /\w+/;
			my ($addr) = $o_bug->parse_addrs([$line]);
			if (grep(/$addr/i, @targets)) {	# one of ours
				my @forward = $self->get_forward($addr);        # find or use generic
				map { $res{$_}++ } @forward ;  					# chunk dupes
				$self->debug(1, "applying tag($tag) line($line) addr($addr) -> @forward") if $DEBUG;						
			} else {											# keep
				$res{$line}++;
				$self->debug(1, "line($addr) NOT one of ours: keeping line($line)") if $DEBUG;	
			}
		}
	}

	chomp(my @res = keys %res);
    return @res;
}


=item send_mail

Send a mail with protection.

    my $ok = $email->send_mail($o_hdr, $body);

=cut

sub send_mail { # sends mail :-) 
    my $self  = shift;
    my $o_hdr = shift;	# prep'd Mail::Header
    my $body  = shift;	# 

    $self->debug(2, "send_mail($o_hdr, body(".length($body)."))") if $DEBUG;
	my @to = ();
	my @cc = ();
	my $max = 250001; # 10001;
	if ($o_hdr->get('From') eq $self->email('from') and length($body) >= $max) {
		if (!($self->{'commands'}{'D'} == 1 || $self->{'commands'}{'L'} =~ /\w+/)) {
			$self->debug(0, "trimming body(".length($body).") to something practical($max)") if $DEBUG;
			$body = substr($body, 0, $max);
			$body .= "Your email exceeded maximum permitted value and has been truncated($max)\n";
		}
	}
	my $i_ok  = 1;
	$o_hdr = $self->defense($o_hdr); 
	if (!ref($o_hdr)) { 	# Mail::Header
		$i_ok = 0;
		$self->error("requires a valid header($o_hdr) to send!");
	} else {
		($o_hdr, my $data) = $self->tester($o_hdr);
		$body = $data.$body;
		@to = $o_hdr->get('To');
		@cc = $o_hdr->get('Cc') || ();
		chomp(@to, @cc);
        $self->debug(1, "Mail to(@to), cc(@cc)") if $DEBUG;
		if ($self->isatest) { # ------------------------------
			my $o_send = Mail::Send->new;
			$self->debug(1, "Send($o_send)...") if $DEBUG;
			TAG:
	        foreach my $tag ($o_hdr->tags) {
				next TAG unless $tag =~ /\w+/;
				my @lines = $o_hdr->get($tag) || ();
				foreach my $line (@lines) {
					chomp($line);
					$o_send->set($tag, $line);
				}
			}
			my $mailer = ($self->isatest != 0) 
				? 'test'
				: $self->email('mailer'); # or mail or test  
   		 	my $mailFH = $o_send->open($mailer) or $self->error("Couldn't open mailer($mailer): $!");
			$self->debug(1, "...fh($mailFH)...") if $DEBUG;
        	if (defined($mailFH)) { # Mail::Mailer
            	if (print $mailFH $body) {
					$self->debug(3, "Body printed to mailfh($mailFH)") if $DEBUG;
				} else {
					$i_ok = 0;
					$self->error("Can't send mail to mailfh($mailFH)");
            	}
				$mailFH->close; # ? sends twice from tmtowtdi, once from pc026991, once from bluepc? 
				$self->debug(0, "Mail($mailFH) sent!(".length($body).") -> to(@to), cc(@cc)") if $DEBUG;
        	} else {
            	$i_ok = 0;
            	$self->error("Undefined mailfh($mailFH), can't mail data($body)");
        	}
			$self->debug(1, "...done") if $DEBUG;
		} else { # live --------------------------------------------------------
			my $hdr = '';
			$self->debug(1, "live...") if $DEBUG;
        	TAG:
        	foreach my $tag (grep(/\w+/, $o_hdr->tags)) {       # each tag
                next TAG unless defined($tag) and $tag =~ /\w+/;
                my @lines = $o_hdr->get($tag);
                chomp(@lines);
                next TAG unless scalar(@lines);
                foreach my $line (@lines) {
                	$hdr .= "$tag: $line\n";
                }
        	}
			$self->debug(1, "...mailing...") if $DEBUG;
			if (open(MAIL, "|/usr/lib/sendmail -t")) {  		# :-( sigh...
        		if (print MAIL "$hdr\n$body\n") {
					if (close MAIL) {
						$self->debug(0, "Mail(MAIL) sent?(".length($body).") -> to(@to), cc(@cc)") if $DEBUG;
					} else {
						$i_ok = 0;
						$self->error("Can't close sendmail");
					}
				} else {
					$i_ok = 0;
					$self->error("Can't print to sendmail");
				} 
        	} else {
				$i_ok = 0;
				$self->error("Can't open sendmail")
			} # ----------------------------------------------------------------
			$self->debug(1, "...done($i_ok)") if $DEBUG;
		}
    }
	$self->debug(0, "sent(".length($body).") ok($i_ok) -> to(@to), cc(@cc)"); 
    return $i_ok;
}


=item tester

If test mail, turn header to maintainer and return header data for insertion

=cut

sub tester {
    my $self  = shift;
    my $o_hdr = shift; # Mail::Header

    my $data  = '';
	my $i_ok  = 1; 		
	if (!ref($o_hdr)) {
    	$i_ok = 0;
		$self->error("requires a valid Mail::Header($o_hdr) to test");
	} else {
		if ($self->isatest) {
			my $from = $self->email('from');
			$self->debug(1, "Test: dumping to maintainer...") if $DEBUG;
			$data = join('', @{$o_hdr->header}) || 'no header data',
			$o_hdr->delete('Cc');
			$o_hdr->delete('Bcc');
			$o_hdr->replace('To', $self->system('maintainer'));
			$o_hdr->replace('From', $from);
			$o_hdr->replace('Reply-To', $self->system('maintainer'));
			$o_hdr->replace('Subject', $self->system('title')." test mail: ");
			$o_hdr->replace('X-Perlbug-Test', 'test');
			my $sep = ('-' x 78)."\n";
			$data = "Header:\n${sep}${data}${sep}";
		}
	}
	undef $o_hdr unless $i_ok == 1;
	return ($o_hdr, $data); 	# Mail::Header and dump
}


=item defense

Set mail defaults for _all_ mail emanating from here, calls L<clean_header()> -> L<trim_to()>.

    my $o_hdr = $self->defense($o_hdr); 

=cut

sub defense { # against duff outgoing headers
    my $self  = shift;
    my $o_hdr = shift; # Mail::Header

	my $dodgy = $self->dodgy_addresses('to');
	if (!ref($o_hdr)) {
		$self->error("requires a valid Mail::Header($o_hdr) to defend");
		undef $o_hdr;
	} else {
		$o_hdr = $self->clean_header($o_hdr);	# (inc trim_to)
		if (ref($o_hdr)) {
			my $cc = join(', ', $self->original('Cc'));
        	$o_hdr->add('Bcc', $self->system('maintainer')) if $self->current('debug') =~ /3/; 
			$o_hdr->add('X-Original-Cc', $cc) if $cc =~ /\w+/;
			$o_hdr->add('X-Original-From', $self->original('From', 'Reply-To'));
			$o_hdr->add('X-Original-Message-Id', $self->original('Message-Id'));
			$o_hdr->add('X-Original-Perlbug', $self->original('X-Perlbug'));
			$o_hdr->add('X-Original-Subject', $self->original('Subject'));
			$o_hdr->add('X-Original-To', $self->original('To'));
			#
			$o_hdr->replace('From', $self->email('from')) unless defined($o_hdr->get('From'));
			$o_hdr->replace('Message-Id', "<$$".'_'.rand(time)."\@".$self->email('domain').'>') unless defined($o_hdr->get('Message-Id'));
			$o_hdr->replace('Return-Path', $self->system('maintainer')); 
				# unless defined($o_hdr->get('Return-Path')); 
			$o_hdr->replace('X-Errors-To', $self->system('maintainer')) unless defined($o_hdr->get('X-Errors-To')); 
			$o_hdr->replace('X-Perlbug', "Perlbug(tron) v$Perlbug::VERSION"); # [ID ...]+
			$o_hdr->replace('X-Perlbug-Test', 'test') if $self->isatest;
			my $msgid = $o_hdr->get('Message-Id') || '';
			chomp($msgid);
			if (defined($self->{'_defense'}{$msgid}) and $self->{'_defense'}{$msgid} >= 1) {
				$self->error("found duplicate Message-Id($msgid)!");
				undef $o_hdr;
			} 
    		$self->{'_defense'}{$msgid}++;
		}
	}
	return $o_hdr; 	# Mail::Header
}


=item clean_header

Clean header of non-compliant 822 address lines using Mail::Address::parse()

	my $o_hdr = $o_mail->clean_header($o_hdr);

=cut

sub clean_header { # of invalid addresses
	my $self  = shift;
	my $o_hdr = shift;	# Mail::Header

	my $i_ok = 1;
	if (!ref($o_hdr)) {
		$i_ok = 0;
		$self->error("requires a valid Mail::Header($o_hdr) to clean");
	} else {
		my @cc = $o_hdr->get('Cc');
		foreach my $tag ($o_hdr->tags) {
			if ($tag =~ /^(To|Bcc|Cc|From|Reply-To|Return-Path)$/i) {
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
						$self->debug(0, "!!! $tag(@lines) cleaned to (@addrs) ?!") if $DEBUG;
					}
				}
				$o_hdr->add($tag, join(', ', @addrs)) if scalar(@addrs) >= 1;
			}
		}
		$o_hdr = $self->trim_to($o_hdr);
		$o_hdr->cleanup if ref($o_hdr); # remove empty lines
	}
	undef $o_hdr unless $i_ok == 1;
	return $o_hdr;		# Mail::Header
}


=item trim_to

Takes the header and returns it without any dodgy to, or cc addresses (or undef):

	my $o_hdr = $o_obj->trim_to($o_hdr);

=cut

sub trim_to { # Mail::Header -> Mail::Header
    my $self   = shift;
    my $o_hdr  = shift;		# Mail::Header

    my $i_ok   = 1;
    if (!ref($o_hdr)) {
    	$i_ok = 0;
		$self->error("requires a valid Mail::Header($o_hdr) to trim");
	} else {
		my $dodgy = $self->dodgy_addresses('to');
		my $to = $o_hdr->get('To');
		my @orig = $o_hdr->get('Cc');
		chomp($to, @orig);
		my %cc = (); # trim dupes
		%cc = map { lc($_) => ++$cc{lc($_)}} (grep(!/($to|$dodgy)/i, @orig));  
		my @cc = keys %cc;
		$o_hdr->delete('To');
		$o_hdr->delete('Cc');  
		$o_hdr->delete('Bcc'); 
		if ($to !~ /\w+/) {
		    $i_ok = 0;
		    $self->debug(0, "no-one to send mail to ($to)!") if $DEBUG;
		} else {
			my $o_usr = $self->object('user');
			my ($xto, @xcc) = $o_usr->parse_addrs([($to, @cc)]);
		    if (grep(/^($dodgy)$/i, $xto, @xcc)) { # final check
				$i_ok = 0;
				$self->debug(0, "Managed to find a duff address: '$to, @cc'!") if $DEBUG; 
		    } else {
				$self->debug(2, "whoto looks ok: '$to, @cc'") if $DEBUG;
				$o_hdr->add('To', $to);
				$o_hdr->add('Cc', join(', ', @cc)) if scalar(@cc) >= 1; 
		    }
		} 
	}			
	undef $o_hdr unless $i_ok == 1;
	return $o_hdr; 	# Mail::Header
}


=item get_forward

Operating on a single (or blank) address, returns a list of forwarding addresses.

    my $to = $perlbug->get_forward('perlbug@perl.org'); # perl5-porters@perl.org

	my $to = $perlbug->get_forward('perl-win32-porters@perl.org'); # perl-win32-porters@perl.org
    
    my $to = $perlbug->get_forward();                   # perl5-porters@perl.org

    my $to = $perlbug->get_forward('unknown@some.addr');# perl5-porters@perl.org
                    
    my @to = $perlbug->get_forward();                   # perl5-porters@perl.org perl-win32-porters@perl.org etc...

=cut

sub get_forward { # forward to mailing lists
    my $self = shift;
    my $tgt  = shift; # perlbug@perl.com 

    my @dest = $self->forward('generic'); # default
	TYPE:
	foreach my $type ($self->get_keys('target')) { 
		next if $type eq 'generic';
		my @potential = $self->target($type); 
		if (grep(/^$tgt$/, @potential)) {
			@dest = $self->forward($type);
			$self->debug(1, "found tgt($tgt) -> $type -> fwd(@dest)") if $DEBUG;
			last TYPE;
		} else {
			$self->debug(3, "$type not applicable(@potential)") if $DEBUG;
		}
	}
    return @dest;
}


=item switch

Returns appropriate method name to call to handle this mail.

This enables you to bypass the suggested method with your own call (be it on your own head :-):

    my $call = $pb->switch(Mail::Internet->new(\$STDIN);     

=cut

sub switch { # decision mechanism for tron recieved mails
    my $self    = shift;
    my $mail    = shift || $self->_mail;           # Mail::Internet->new(*STDIN);

    my $found   = 0;
	my $switch  = 'quiet';  
	my $msg 	= 'zip';     
	if (!ref($mail)) {
		$found++;
		$self->error("requires Mail::Internet($mail) for decision"); 
	}

    # which address group?
	my $o_bug = $self->object('bug');
	my $o_msg = $self->object('message');

	# -----------------------------------------------------------------------------
    # X-Header
	my ($o_hdr, $header, $body) = $self->splice($mail) if ref($mail);
	if ($found == 0) {
		$self->{'attr'}{'bugid'} = '';
    	my $to      = $mail->head->get('To') || '';
    	my @cc      = $mail->head->get('Cc') || '';
    	my $from    = $mail->head->get('From') || '';
    	my $subject = $mail->head->get('Subject') || '';
    	my $replyto = $mail->head->get('Reply-To') || '';
    	my $inreply = $mail->head->get('In-Reply-To') || '';
    	my $perlbug = $mail->head->get('X-Perlbug') || '';
    	my $messageid = $mail->head->get('Message-Id') || '';
    	chomp($from, $subject,  $messageid, $replyto, $inreply, $to, @cc);
		($to) = map { ($_->address) } Mail::Address->parse($to);
		(@cc  = map { ($_->address) } Mail::Address->parse(@cc)) if @cc;
    	$self->debug(0, qq|$0: 
			Cc(@cc) 
			From($from) 
			In-Reply-To($inreply)
			Message-Id($messageid) 
			Reply-To($replyto) 
			Subject($subject) 
			To($to) 
			X-Perlbug($perlbug)
		|);
    	my $target = ''; # to/cc...
		my @addresses = ();
		my $i_ok = $self->check_incoming($o_hdr);
		if ($i_ok == 0) {
      		$switch = 'quiet'; $found++;
			$msg = "X-Header found something duff! =:-[]";
      		$self->debug(1, $msg) if $DEBUG;
    	}
		
    	# Have we seen messageid in db before? -> TRASH it
    	if ($found != 1) {
			my ($obj, @ids) = $self->messageid_recognised($messageid) if $messageid;
			if ($obj =~ /\w+/ || scalar(@ids) >= 1) {
				$found++;
				$switch = 'quiet';
				$msg 	= "CLONE $switch($found) seen obj($obj) before ids(@ids), bale out! :-((";
			}
    	}

		# which to/cc are we using?
    	if ($found != 1) {
			my $domain = $self->email('domain');
			ADDR:
			foreach my $addr ($to, @cc) { # 
				next ADDR unless $addr =~ /\w+/;
				if ($addr =~ /^(.+)\@$domain/i) { # *@bugs.perl.org
					$target = $1;
					if ($target =~ /^(note|patch|test)/i) { # rjsf: many more...
						$found++;
						$switch = 'assignment';
					}
					$self->debug(1, "using addr($addr) -> target($target)") if $DEBUG;
					last ADDR;
				} 
			}
		}

		# Is there a bugid in the subject? -> REPLY
    	if ($found != 1) {   
			my @subs = $o_bug->str2ids($subject);
        	# if (my @subs = ($subject =~ /\b(\d{8}\.\d{3})\b/)) {    
			BID:
			foreach my $bid (@subs) {
				my @seen = $o_bug->ids("bugid = '$bid'");
				$self->debug(2, "Is this($bid) a reply to a bugid in the subject($subject)") if $DEBUG;
				if (scalar @seen >= 1) {
					$found++;
					$self->{'attr'}{'bugid'} = $bid;
					$switch = 'reply'; 
					$msg = "REPLY $switch($found) from subject: ($bid) :-)";
					$self->debug(1, $msg) if $DEBUG; 
					last BID;
				} else {
					$self->debug(2, "Nope, bugid($bid) not found(@seen)") if $DEBUG;
				}
			}
			# } else {
			#	$self->debug(2, "Subject/bugid not relevant($subject), ignoring it ($found)") if $DEBUG;
			#}
		}
		
		# Is it a reply to an unknown/unrecognised bug (in the subject) in the db? -> REPLY
    	if ($found != 1) {  
			my ($obj, @ids) = $self->messageid_recognised($inreply) if $inreply;
			if ($obj =~ /\w+/ || scalar(@ids) >= 1) {
				$found++;
				$switch = 'reply';
				my $o_obj = $self->object($obj);
				$o_obj->read($ids[0]);
				my ($bid) = my @bids = ($o_obj->key =~ /bug/i ? ($ids[0]) : $o_obj->rel_ids('bug'));
				$self->{'attr'}{'bugid'} = $bid;
				$msg = "REPLY $switch($found): to previously unknown $obj(@ids) -> bugid($bid) ;-)";
			}
    	}        
		
		# Is it addressed to perlbug? -> NEW or BOUNCE
    	if ($found != 1) {  
        	my $match = $self->email('match');
			my @targets = $self->get_vals('target');
        	$self->debug(2, "Looking at addresses to($to), cc(@cc) against targets(@targets)?") if $DEBUG;
        	ADDR:
			foreach my $line ($to, @cc) {
				next ADDR unless $line =~ /\w+/;
				last ADDR if $found >= 1;
				my ($addr) = $o_bug->parse_addrs([$line]);
				if (grep(/$addr/i, @targets)) {	# one of ours
		    		$self->debug(2, "Address($addr->$line) match :-), have we a match($match) in the body?") if $DEBUG;
            		if ($body =~ /$match/i) {    # new \bperl|perl\b
                		$found++;
                		$switch = 'new';
						$msg = "NEW BUG $switch($found): Yup! perl($match) subject($subject) :-))";
                		$self->debug(1, $msg) if $DEBUG;
            		} else {                            # spam?
                		$found++;
                		$switch = 'bounce'; 
                		$self->debug(1, "Nope, $switch($found): addressed to one of us, but with no match in body(".length($body).") :-||") if $DEBUG;
            		}
        		} else {
            		$self->debug(2, "address($line) not relevant pass($found)") if $DEBUG;
        		}
			}
			$self->debug(2, "Addressed and bodied to us? ($found) <- ($to, @cc)") if $DEBUG; # unless $found == 1;
    	}
	}
	
	# Catch all -> TRASH it
    if ($found != 1) {  
        $switch = 'quiet';
		$msg = "IGNORE $switch($found): invalid perlbug data, potential p5p miscellanea or spam) :-|";
        $self->debug(1, $msg) if $DEBUG;
    }
    $self->debug(0, "Decision -> do_$switch($found) $msg");

    return ('do_'.$switch, $msg); # do_(new|reply|quiet|bounce) (do_$res, $reason) (look in the logs)
}


=item do_new

Deal with a new bug

=cut

sub do_new { # bug
    my $self = shift;
    my $mail = shift || $self->_mail;

    my ($o_hdr, $header, $body) = $self->splice($mail);
    $self->{'attr'}{'bugid'} = '';
    my ($ok, $err, $msg, $bid, $mid) = (1, '', '', '', '');
    my $from      = $o_hdr->get('From');
    my $subject   = $o_hdr->get('Subject');
    my $to        = $o_hdr->get('To');
    my @cc        = $o_hdr->get('Cc');
    my $reply     = $o_hdr->get('Reply-To') || '';
	my $msgid 	  = $o_hdr->get('Message-Id') || '';
    chomp($from, $subject, $to, $reply, $msgid);
	my $origsubj  = $subject;
	$self->debug(1, "NEW BUG: from($from), subject($subject), to($to), message($msgid)") if $DEBUG;
    $self->{'attr'}{'messageid'} = $msgid;
	my ($title, $bugtron, $maint) = ($self->system('title'), $self->email('bugtron'), $self->system('maintainer'));
    # Open a new bug in the database
	my $o_bug = $self->object('bug');
    if ($ok == 1) { # init
		$bid = $o_bug->oid($o_bug->new_id);
		$o_bug->create({
			$o_bug->attr('primary_key'), => $bid,
			'subject'	=> $subject,
			'sourceaddr'=> $from,
			'toaddr'	=> $to,
			'header'	=> $header,
			'body'		=> $body,
			'email_msgid'	=> $msgid,
		});
		if ($o_bug->CREATED) {
			$o_bug->relation('address')->_assign([$to, @cc]);
		} else {
			$ok = 0;
			$self->error("failed to create new bug");	
		}
        # ($ok, $bid, $mid) = $self->insert_bug($subject, $from, $to, $header, $body);
    }
	my $h_data = {};
    if ($ok == 1) { # relations
        $self->{'attr'}{'bugid'} = $bid;
        $subject = "[ID $bid] $subject"; 
        $o_hdr->replace('Subject', $subject);
        $h_data = $self->scan($body);
        if (ref($h_data) ne 'HASH') {
            $ok = 0;
            $err = 'SCAN failure';
		} else {
            if ($origsubj =~ /^\s*OK:/i) {
				$$h_data{'status'}{'ok'}++;
				$$h_data{'group'}{'install'}++;
			}
            if ($origsubj =~ /^\s*Not OK:/i) {
				$$h_data{'status'}{'notok'}++;
				$$h_data{'group'}{'install'}++;
			}
			if ($to =~ /dailybuild/i) {
				$$h_data{'group'}{'dailybuild'}++;
			}
			if ($$h_data{'category'}) {
				# push(@{$$h_data{'group'}}, @{$$h_data{'category'}}); 
			 	$$h_data{'group'} = (ref($$h_data{'group'})) 
					? { %{$$h_data{'group'}}, %{$$h_data{'category'}} } 
					: { %{$$h_data{'category'}} }; 
				delete $$h_data{'category'};
			}
			# $ok = $self->bug_set($bid, $h_tkt); # inc. tracking
			# $o_obj->set($h_data); # rels, attrs...
			KEY:
			foreach my $key (keys %{$h_data}) {
				next KEY unless ref($$h_data{$key}) eq 'HASH';
				my @vals = keys %{$$h_data{$key}};
				$o_bug->relation($key)->_assign(\@vals) if scalar(@vals) >= 1;
			}
        }
    }
	if ($ok == 1) {
		$o_bug->relation('address')->_assign([$to, @cc]);
	}
	my $url = $self->web('hard_wired_url');
	$o_hdr->add('X-Perlbug-Url-Bug', "$url?req=bug_id&bug_id=$bid");
	my $perlbug = $self->web('cgi');
	$url =~ s/$perlbug/admin\/$perlbug/;
	$o_hdr->add('X-Perlbug-Admin-Url-Bug', "$url?req=bidmids&bidmids=$bid");

	my $isadaily = 0;
	if ($$h_data{'group'}) {
		$isadaily++ if grep(/^dailybuild$/, values %{$$h_data{'group'}});
	}
    if ($ok == 1 && $self->mailing && $isadaily == 0) { # NOTIFY	
		my $type = ($origsubj =~ /^\s*OK/i) ? 'ok' : 'remap';
		my $o_reply = $self->get_header($o_hdr, $type);	# p5p
		my @ccs =  $self->bugid_2_addresses($bid, 'new');	# groups, etc
		$o_reply->replace('Cc', join(', ', @ccs));
		$ok = $self->send_mail($o_reply, $body); # auto
        $err = ($ok == 1) ? "Notified" : "Failed to notify master and groups";             
    }
    if ($ok == 1) {
		if ($body =~ /(ack=no)/is) { # DON'T send a response back to the source 
			$self->debug(0, "NOT($1) sending form response.") if $DEBUG;
		} else {
			$self->debug(2, "Sending form response.") if $DEBUG;
			my $o_response = $self->get_header($o_hdr);
			$o_response->replace('Subject', "Ack: $subject");
			$o_response->replace('To', $self->from($reply, $from)); 
			$o_response->add('X-Perlbug-Admin-Url-Bug', "$url?req=bug_id&bug_id=$bid");
			$o_response->add('X-Perlbug-Url-Bug', "$url?req=bug_id&bug_id=$bid");
			my $response = join('', $self->read('response'));
			my $footer   = join('', $self->read('footer'));
			$response =~ s/Bug\sID/Bug ID ($bid)/;
			$response =~ s/(Original\ssubject:)/$1 $origsubj/;
			$ok = $self->send_mail($o_response, $response.$footer);
		}
    }
    return $ok;
}


=item do_reply

Deal with a reply to an existing bug - no acknowledgement, no forward (quiet)

=cut

sub do_reply { # to existing bug
    my $self = shift;
    my $mail = shift || $self->_mail;

    my $bid  = $self->{'attr'}{'bugid'}; # yek
    my ($ok, $msg, $mid) = (1, '', '');
	my $o_bug = $self->object('bug');
    if (!(ref($mail) and $o_bug->ok_ids([$bid]))) {
		$ok = 0;
		$self->error("requires a Mail::Internet($mail) and a bid($bid)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($mail);
    	my $from 	= $o_hdr->get('From');
    	my $subject = $o_hdr->get('Subject');
    	my $reply   = $o_hdr->get('Reply-To');
    	my $to      = $o_hdr->get('To');
    	my $msgid   = $o_hdr->get('Message-Id');
		my @cc 		= $o_hdr->get('Cc');
		chomp($from, $subject, $reply, $to, @cc);
    	$self->debug(1, "REPLY: subject($subject), bid($bid), from($from), reply($reply), to($to)") if $DEBUG;
    	# Add it to the database
		my $o_bug = $self->object('bug')->read($bid);
		my $o_msg = $self->object('message');
		$o_msg->create({
			'messageid'	=> $o_msg->new_id,
			'sourceaddr'=> $from,
            'subject'   => $subject,
            'toaddr'    => $to,
			'header'	=> $header,
            'body'   	=> $body,
			'email_msgid'	=> $msgid,
    	});
		$mid = $o_msg->oid if $o_msg->CREATED;
		$o_bug->relation('message')->assign([$mid]);
		$o_bug->relation('address')->assign([$to, @cc]);
	}
    return $mid;
}


=item header2admin

Given a Mail::Header object attempts to return a valid create admin command

	my $data = $o_email->header2admin($o_hdr);

=cut

sub header2admin {
	my $self = shift;
    my $o_hdr = shift;

    my $data  = '';
	if (!ref($o_hdr)) {
		$self->error("registration requires a header object($o_hdr)");
	} else {    
		my $to 		= $o_hdr->get('To');
		my $from 	= $o_hdr->get('From');
    	my $subject = $o_hdr->get('Subject') || '';
    	my $reply   = $o_hdr->get('Reply-To') || '';
		chomp($to, $from, $subject, $reply);
		my $user = '';
		if ($to =~ /^(.+)\@.+/) {
			$user = $1;
			$user =~ s/register//gi;
			$user =~ s/[^\w]+//g;
			$user =~ s/^_+(\w+)/$1/; 
			$user =~ s/(\w+)_+$/$1/; 
		}
		$self->debug(1, "Looking at registration request($user) from($from)") if $DEBUG;
		my ($o_from) = Mail::Address->parse($from);
		if (!ref($o_from)) {
			$self->error("Couldn't get an address object($o_from) from($from)");
		} else {
			my $address = $o_from->format;
			my $name 	= $o_from->name;
			chomp($address, $name); # probably uneccessary - paranoid now
			my $last  	= $name; $name =~ s/\s+/_/g;
			my $userid 	= $user || $o_from->user."_$$" || $last."_$$"; #
			my $pass 	= $userid; $pass =~ s/[aeiou]+/\*/gi;
			my $match 	= quotemeta($address);
			$data = "userid=$userid:\nname=$name:\npassword=$pass:\naddress=$address:\nmatch_address=$match\n"; 
			$self->debug(1, "data($data)") if $DEBUG;
		}
	}
    return $data;
}


=item doe

Email address to 'Cc:' to

	-e me.too@some.where.org

=cut

sub doe {   # email to cc:
    my $self = shift;

    my ($args) = @_;
    my $email = (ref($args) eq 'ARRAY') ? join ', ', @{$args} : $args;
    $self->{'attr'}{'cc'} = $email if ($email =~ /\w+\@\w+/); #&& (grep(//, $email)... =~ /^[-\@\w.]+$/)); 
    $self->debug(2, "Cc emails registered: ".$self->{'attr'}{'cc'}) if $DEBUG;

	return $self->{'attr'}{'cc'};
}


=item do_assignment 

Assignment of mail (note|patch|test) to existing bug, wraps parse_mail() and process_commands() 

	my $ok = $o_email->do_assignment($o_mail_internet);

=cut

sub do_assignment {
    my $self = shift;

    my $o_int = shift;
	my $i_ok = 1;

	my ($h_cmds, $body) = $self->parse_mail();

	my @res = $self->process_commands($h_cmds, $body);
	

	return $i_ok;
}


=item doy

New password

=cut

sub doy {  # new pass 
    my $self = shift;
    my $args = shift;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : ($args);

	my $i_ok = 0;
    my $userid = $self->isadmin;
	($i_ok) = $self->SUPER::doy(["$userid @args"]);
	my $res = "new password(@args) request($i_ok)";

	return $res;
}


=item dov

Volunteer proposed bug modifications

	propose_close_<bugid>@bugs.perl.org
	
	my $i_ok = $o_obj->dov('bid close patch');

=cut

sub dov { # volunteer propose new bug status/mods
	my $self = shift;
	my $args = shift;
	my $o_mail = shift || $self->_mail;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;


	my $i_ok = 1;
	if (!ref($o_mail)) {
		$i_ok = 0;
		$self->error("bug proposal requires a Mail::Internet object($o_mail)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		my ($subject, $from, $replyto) = ($o_hdr->get('Subject'), $o_hdr->get('From'), $o_hdr->get('Reply-To'));
		chomp($subject, $from, $replyto);
		my $admin   = $self->system('maintainer');
		my @admins  = $self->active_admin_addresses;
		$self->debug(2, "perlbug proposal: @args") if $DEBUG;
		my $o_prop = $self->get_header($o_hdr);
		$o_prop->replace('To', $admin);
		# $o_prop->replace('Cc', join(', ', @admins));
		$o_prop->replace('From', $self->from($replyto, $from));
		$o_prop->replace('Subject', $self->system('title')." proposal: $subject");
		$i_ok = $self->send_mail($o_prop, $body);
	}
	my $res = "Proposal request($i_ok)";

	return $res;
}


=item doV

Volunteer a new administrator

	register_MYUSERID@bugs.perl.org

=cut

sub doV { # Propose new admin
	my $self = shift;
	my $args = shift;

    my $o_mail = $self->_mail; # hopefully 

	my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	my $request = "New admin request -i[nitiate] (\n@args\n)\n";
	my $i_ok = 1;
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->error("admin volunteer requires a mail object($o_mail)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		my $o_prop = $self->get_header($o_hdr);
		my $subject = $o_hdr->get('Subject');
		chomp($subject);
		my $admin = $self->system('maintainer');
		$o_prop->replace('To', $admin);
		$o_prop->delete('Cc');
		$o_prop->replace('Subject', $self->system('title')." admin volunteer: ");
		$o_prop->replace('Reply-To', $admin);
		$i_ok = $self->send_mail($o_prop, $request);
	}
	my $res = "Admin volunteer request($i_ok)";

	return $res;
}


=item doa

admin a bug

	close_<bugid>_patch_macos@bugs.perl.org

=cut

sub doa { # admin a bug
	my $self = shift;
	my $args = shift;
    my $o_mail = $self->_mail; # hopefully 

	my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	@args = map { split(/[\s_]+/, $_) } @args;
	my @bids = ();
	my $i_cnt= 0;
	my $res  = '';
	if (!ref($o_mail)) {
		$self->error("admin requires a mail object($o_mail)");
	} else {
		$res = $self->SUPER::doa($args, $o_mail);
	}

	return $res;
}


=item doP

Recieve a patch

	patch_<version>*_<changeid>*_<bugid>*@bugs.perl.org

=cut

sub doP { # recieve a patch
	my $self = shift;
	my $args = shift;
	my $o_mail = $self->_mail; 

	my $i_ok = 1;
	my @bids = (); 
	my $res = '';
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->error("requires a mail object($o_mail) for patching");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		chomp(my $to = $o_hdr->get('To'));
		chomp(my $from = $o_hdr->get('From'));
		chomp(my $subject = $o_hdr->get('Subject'));
		$res = $self->SUPER::doP($args, $body, $header, $subject, $from, $to);
		
		# notify everyone - otherwise they won't know it's arrived?
		if ($res =~ /assigned/) {
			my $o_ack = $self->get_header($o_hdr);
			my $admin = $self->system('maintainer');
			my $bugdb = $self->email('bugdb');
			my @admins = $self->active_admin_addresses;
			$o_ack->replace('To', $admin);
			# $o_ack->replace('Cc', join(', ', @admins)) unless grep(/nocc/i, $subject);
			$o_ack->replace('Subject', $self->system('title')." patch($res) recieved");
			$o_ack->replace('Reply-To', $bugdb);
			$i_ok = $self->send_mail($o_ack, $body);
		}
	}

	return $res;
}


=item doT

Recieve a test

	test_<bugid>@bugs.perl.org

=cut

sub doT { # recieve a test
	my $self = shift;
	my $args = shift;
    my $o_mail = $self->_mail; 

	my $i_ok = 1;
	my $res = '';
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->error("requires a mail object($o_mail) for testing");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		chomp(my $to = $o_hdr->get('To'));
		chomp(my $from = $o_hdr->get('From'));
		chomp(my $subject = $o_hdr->get('Subject'));
		$res = $self->SUPER::doT($args, $body, $header, $subject, $from, $to);
		
		# notify everyone - otherwise they won't know it's arrived?
		if ($res =~ /assigned/) {
			my $o_ack = $self->get_header($o_hdr);
			my $admin = $self->system('maintainer');
			my $bugdb = $self->email('bugdb');
			my @admins = $self->active_admin_addresses;
			$o_ack->replace('To', $admin);
			# $o_ack->replace('Cc', join(', ', @admins)) unless grep(/nocc/i, $subject);
			$o_ack->replace('Subject', $self->system('title')." test($res) recieved($i_ok)");
			$o_ack->replace('Reply-To', $bugdb);
			$i_ok = $self->send_mail($o_ack, $body);
		}
	}

	return $res;
}


=item doN

Recieve a note

	note_<bugid>*@bugs.perl.org

=cut

sub doN { # recieve a note
	my $self = shift;
	my $args = shift;
	my @args = @_; # have to ignore these
	my $o_mail = $self->_mail; 

	my @bids = (); 
	my $res  = '';
	if (!ref($o_mail)) {
		$self->error("requires a mail object($o_mail) for note");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		chomp(my $to = $o_hdr->get('To'));
		chomp(my $from = $o_hdr->get('From'));
		chomp(my $subject = $o_hdr->get('Subject'));
		$res = $self->SUPER::doN($args, $body, $header, $subject, $from, $to);
	}

	return $res;
}


=item dow

Forward (weiterleiten) mail onto all active administrators

	admin(s)@bugs.perl.org

	my $i_ok = $o_obj->dow($body);

=cut

sub dow { # weiterleiten -> all active admins
	my $self = shift;
	my $cmd    = shift;
	my $o_mail = shift || $self->_mail;

	my $i_ok = 1;
	if (!ref($o_mail)) {
		$i_ok = 0;
		$self->error("forwarding requires a Mail::Internet object($o_mail)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);	# <- get it from here
		my $from = $o_hdr->get('Reply-To') || $o_hdr->get('From');
		my @admins = $self->active_admin_addresses;
		my $maintainer = $self->system('maintainer');
		chomp($from, $maintainer);
		my $o_forward = $self->get_header($o_hdr);
		$o_forward->replace('To', $maintainer);
 		# $o_forward->replace('Cc', join(', ', @admins));
		$o_forward->replace('Reply-To', $from);
		$o_forward->add('Subject', $self->system('title').": ".$o_hdr->get('Subject'));
		$i_ok = $self->send_mail($o_forward, "Forwarded message:\n$body");
	}

	return ($i_ok);
}


=item do_quiet

Drop out quietly, no entry in database, silent dump into black hole.

=cut

sub do_quiet { # log this mail and do nothing else
    my $self = shift;
    my $mail = shift || $self->_mail;

    my ($o_hdr, $header, $body) = $self->splice($mail);
    my $i_ok = 1;
    # silent pass through
    if (1) {
        $self->debug(1, "QUIET ($mail, @_) logged(pass through), not in db:\n") if $DEBUG;
    }

    return $i_ok;
}


=item do_bounce

Deal with a bounced mail

=cut

sub do_bounce { # and place in db
    my $self    = shift;
    my $mail    = shift || $self->_mail;

    my ($reason)= @_;
    my ($o_hdr, $header, $body) = $self->splice($mail);
    chomp(my $from    = $o_hdr->get('From'));
    chomp(my $replyto = $o_hdr->get('Reply-To'));
    chomp(my $subject = $o_hdr->get('Subject'));
    chomp(my $to      = $o_hdr->get('To'));
    chomp(my $cc      = $o_hdr->get('Cc'));
    chomp(my $xloop   = $o_hdr->get('X-Perlbug'));
    chomp(my $msgid   = $o_hdr->get('Message-Id'));
    #
    my ($ok, $bid, $mid) = (1, '', '');
    $self->debug(1, "BOUNCE: subject($subject) into db for posterity...") if $DEBUG;
    my $rebound = $from;
	my $o_bug = $self->object('bug');
    if ($xloop =~ /\w+/) {
        $self->debug("X-Perlbug($xloop) not putting into DB: '$subject'") if $DEBUG;
        $rebound = $self->system('maintainer');
        $subject = "X-Perlbug: $subject";
    } else {
        # register bounced mails as new onhold notabug low priority bugs
		$o_bug->create({
			'bugid'		=> $o_bug->new_id,
			'subject'	=> $subject,
			'sourceaddr'=> $from,
			'toaddr'	=> $to,
			'header'	=> $header,
			'body'		=> $body,
			'email_msgid'	=> $msgid,
		});
		if ($o_bug->CREATED) {
			$bid = $o_bug->oid;
		} else {
			$ok = 0;
			$self->error("failed to create new bounce bug");	
		}
	}
	if ($ok == 1) {
		$self->{'attr'}{'bugid'} = $bid;
		$o_bug->relation('status')->_assign(['closed']);
		$o_bug->relation('severity')->_assign(['none']);
		$o_bug->relation('group')->_assign(['bounce']);
		$o_bug->relation('address')->_assign([$o_hdr->get('To'), $o_hdr->get('Cc')]);
		my ($title, $bugtron, $hint) = ($self->system('title'), $self->email('bugtron'), $self->email('hint'));
        $body = qq|
    This email address is for reporting $title bugs via $bugtron.
    
    $reason
    
    Please address your mail appropriately and include appropriate data 
    as per the distributed documentation.  
    
    $hint
    -----------------------------------------------
    $body
        |;
    }
    if ($ok == 1) {
        my $o_reply = $self->get_header($o_hdr);
		$o_reply->replace('To', $self->from($replyto, $from));
        $o_reply->replace('Subject', "Bounce: $subject");
		$ok = $self->send_mail($o_reply, $body);
    }

    return $ok;
}


=item assign_bugs

Assign to this admin, so many, of these unclaimed bugs.

N.B. the claimed bugs are shifted off the end of the referenced array!

    $ok = $pb->assign_bugs($admin, 5, \@unclaimed);

=cut

sub assign_bugs { # unclaimed to admins
    my $self    = shift;
    my $admin   = shift;
    my $num     = shift;
    my $a_unclaimed = shift;

    my $ok = 1;
    
	my $o_usr = $self->object('user');
    if (($admin =~ /\w+/) && ($num =~ /^\d+$/) && (ref($a_unclaimed) eq 'ARRAY') && (@{$a_unclaimed} >= 1)) {
        $self->debug(2, "assign_bugs($admin, $num, $a_unclaimed) args OK") if $DEBUG;
    } else {
        $ok = 0;
        $self->error("Duff args given to assign_bugs: admin($admin), num($num), a_unclaimed($a_unclaimed)");
    }
     
    # NOTICE
    my $notice = '';
    if ($ok == 1) {
        my ($perlbug, $maintainer, $home) = ($self->email('perlbug'), $self->system('maintainer'), $self->web('home'));
        $notice = qq|
    As an active perlbug admin, you have been assigned the following 
    (now claimed :-) bugs to categorise, and generally deal with.
	
	If you are too busy, please let '$maintainer' know, or de-activate 
	yourself from the web front end at 
		
		$home
    
	For email help send an email to:
	
		To: $perlbug
		Subject: -h
	
        |;
    }
    
    # BIDS
    my @bids = ();
    my @res  = ();
    if ($ok == 1) {
        my %assign = ();
        my $user = $self->check_user($admin);          # setup admin as current user or not
        foreach my $it (1..$num) {          # of given bugs
            last if $it >= 5;               # Let's not frighten them all off straight away :-)
            my $bug = shift @{$a_unclaimed}; # rand $num @unclaimed
            $self->dok($admin, $bug);    # claim
            push(@res, $self->dob($bug));# feedback
            push(@bids, $bug);           # ref
            $self->debug(2, "Admin($admin), claimed bug($bug)") if $DEBUG;
        }
    }

    if ($ok == 1) {
        push(@res, $self->doo);
	}

    # SEND MAIL
    if ($ok == 1) {
		my $address = $o_usr->read($admin)->data('address');
		my $data = join('', @res);
        my $o_hdr = $self->get_header;
		$o_hdr->add('To' => $address);
        $o_hdr->add('Subject' => $self->system('title').' admin sheet (@bids)');
        $ok = $self->send_mail($o_hdr, "$notice\nBUGIDs: (@bids)\n\n$data\n\n");
    }

    return $ok;
}   # done assign_bugs



=item doD

Mail me a copy of the latest database dump, with 8-figure time filter

=cut

sub doD { # mail database dump
	my $self = shift;
	my $args = shift;

    my $date = (ref($args) eq 'ARRAY') ? join(' ', @{$args}[0]) : $args;
	my $i_ok = 1;
	my $file = $self->directory('arch').'/'.$self->database('latest');
	if ($date !~ /^\s*(\d+)\s*$/) { # incremental
		$self->debug(2, "Full database dump requested($args -> $date)") if $DEBUG;
	} else {	
		$date = $1;
		$file = File::Spec->canonpath($self->directory('arch')."/Perlbug.sql.${date}.gz");
		$i_ok = $self->SUPER::doD($date);
		if ($i_ok != 1) {
			$self->error("Database dump($file) request($date) failed to complete($i_ok)!");
		}
	} 
	if ($i_ok == 1) {
		my ($o_hdr, $header, $body) = $self->_mail;
		my $address = $self->from($o_hdr->get('Reply-To'), $o_hdr->get('From'), $self->system('maintainer'));
		my $title   = $self->system('title');
		if ($address !~ /\w+/) {
			$i_ok = 0;
		} else {
			my $size = -e $file;
			my $cmd  = "uuencode $file $file | mail -s '$title db dump' $address"; # yek! :-/
			$self->debug(2, "doD cmd($cmd)") if $DEBUG;
			$i_ok = !system($cmd);
			if ($i_ok == 1) {
				my $hinweis = qq|$title database($size) dump(-D $date) mailed($i_ok) to '$address'

Incremental updates may be retrieved using the following format:

	-D                  \# everything 
	-D 2000             \# everything since 1st Jan 2000
	-D 20001120         \# everything since 20th Nov 2000
	-D 20001120153527   \# everything since 27 seconds after 3.35pm on 20th Nov 2000

N.B.: If you\'ve loaded the database before 2.26, the structure has changed, you may want to trash it and start all over again.  Alternatively ./scripts/fixit -> mig can help with the migration.

|;
				# $self->result($hinweis);
			} else {
				$self->debug(0, "doD cmd($cmd) failed($i_ok) $!") if $DEBUG;
			} 
		}
	}
	$self->debug(2, "doD i_ok($i_ok)") if $DEBUG;

	return $i_ok;
}


=item scan_header

Scan a typical *@bugs.perl.org header

	my ($cmd, $body) = $o_mail->scan_header($o_hdr, $body); 
		
To: line can be any of:

	close_<bugid>_@bugs.perl.org  = bug admin request
		
	register@bugs.perl.org        = admin registration request

	admins@bugs.perl.org          = admin mail forward

Subject: line may look like:

	-h -o

	-H -d2 -l -A close 20000721.002 lib -r patch -e some@one.net 

=cut

sub scan_header {
	my $self  = shift;
	my $o_hdr = shift; 	# close_<bugid>_install | register | ...
	my $body  = shift;

	my $cmd   = ''; 	# 
	my $str = '';
	if (!ref($o_hdr)) {
		$body = '';
		$self->error("scan_header requires a Mail::Header object($o_hdr)");
	} else {
		my $oldstyle = quotemeta($self->email('bugdb'));
		my $newstyle = quotemeta($self->email('domain'));
		my ($to, $from, $subject) = ($o_hdr->get('To'), $o_hdr->get('From'), $o_hdr->get('Subject'));
		my $msgid = $o_hdr->get('Message-Id');
		my @cc = $o_hdr->get('Cc');
		chomp($to, $from, $subject, @cc, $msgid);
		$self->debug(1, "to($to), subject($subject), from($from), cc(@cc), msgid($msgid)") if $DEBUG;
		# STR
		ADDR:
		foreach my $addr ($to, @cc) { # whoops, forgot the cc's
			next ADDR unless $addr =~ /\w+/;
			if ($addr =~ /^(.+)\@$newstyle$/i) { # *@bugs.perl.org
				$str = $1;
				last ADDR;
				$self->debug(1, "using addr($addr) -> cmd($cmd)") if $DEBUG;
			} elsif ($addr =~ /^$oldstyle$/) {
				$str = $subject;
				last ADDR;
				$self->debug(1, "address($addr) using subject -> cmd($cmd)") if $DEBUG;
			}
		}
		if ($str !~ /\w+/) { 	# ek?
			$self->debug(1, "no valid string($str) found for cmd($cmd)!") if $DEBUG;
		} else {							# NEW style
			# CMD
			# from here is a bit if/but/else'y :-( -> map it through a hash later once all the requests are settled?
			my $origin = $self->email('from'); $origin =~ s/^(.+)?\@.+$/$1/;
			if ($str =~ /^bugdb.*/i) {		# allow old style through $self->email('bugdb') || ...
				$cmd = $subject;
			} elsif ($str =~ /^(h)elp$/i) {	# help|register|admins|propos|patch
				$cmd = $1; # h|H
			} elsif ($str =~ /^regist/i) {	# admin registration request -> accept if in p5p
				$cmd = ($self->in_master_list($from)) ? 'i' : 'V'; 	# doi | doV
				$body = $self->header2admin($o_hdr);
			} elsif ($str =~ /^password/i) {# password forgotten
				$cmd = "y $str";									# doy
				$cmd =~ s/password_*//i;
			} elsif ($str =~ /^admin/i) {	# weiterleiten to all active admins
				$cmd = 'w';											# dow
			} elsif ($str =~ /^perlbug[\-_]test/i) {	# 
				$cmd = 'j';											# dow
				$self->mailing(0);
			} elsif ($str =~ /^overv/i) {	# overview
				$cmd = 'o';											# doo
			} elsif ($str =~ /^track/i) {	# track 
				$cmd = 'j';											# doj
				$self->mailing(0);
			} elsif ($str =~ /^(faq|adminfaq|help|spec|info|$origin)/i) {		# !!!	  
				$cmd = 'h';											# doh
			} elsif ($str =~ /^patch_/i) {  # patch/change/fix      # ONLY IF IT _STARTS_ with ^patch...
				$cmd = "P $str";									# doP
			} elsif ($str =~ /^test_/i) {  # test/change/fix        # ONLY IF IT _STARTS_ with ^test...
				$cmd = "T $str";									# doT
			} else {						# admin/proposal/note => bugid
				$cmd = ($str =~ /^propos\w+/i) ? 'v' : 'a'; 		# dov | doa | note
				my @bids = $self->object('bug')->str2ids($str.'_'.$subject);
				if (scalar(@bids) >= 1) { 
					if ($str =~ /^note/i) {							# doN (body)
						$cmd = 'N '.join('_', @bids) if @bids;
					} else {
						$cmd = "$cmd $str";
					}
				} else {
					$self->debug(0, "Failed to identify($cmd) bugids(@bids) in string($str), referring to admins") if $DEBUG;
					$cmd = "v $str"; # refer to admins				# dov
				}
			}
			$self->debug(1, "cmd($cmd)") if $DEBUG;
		}
	}
	if ($cmd !~ /\w+/) {
		$self->debug(0, "no cmd($cmd) found from str($str) return 'H' instead") if $DEBUG;
		$cmd = 'H';
	} else {
		$self->debug(0, "str($str) -> cmd($cmd)") if $DEBUG;
	}

	return ($cmd, $body);	
}


=item in_master_list

Checks given address against ok-to-be-administrator email address list

	my $i_ok = $o_obj->in_master_list($address);

=cut

sub in_master_list {
	my $self = shift;
	my $addr = shift;

	my $i_ok = 0;
	my $o_usr = $self->object('user');
	my ($address) = $o_usr->parse_addrs([$addr]);
	if ($address !~ /\w+/) {
		$self->debug(0, "address($addr) not parseable($address)") if $DEBUG;
	} else {
		my $list = $self->directory('config').$self->system('separator').$self->email('master_list');
		my $o_log = Perlbug::File->new($list);
		my @list = $o_log->read($list);
		my $found = grep(/^$address$/i, @list);
   		$i_ok = ($found >= 1) ? 1 : 0;
		$self->debug(0, "found($found) addr($addr)->address($address) in list(".@list.")") if $DEBUG;
	}

	return $i_ok;
}


sub reminder { # open/fatal to relevant parties...
    my $self    = shift;
    my $bid     = shift;
	my @addrs   = @_;

	my $ret     = 0;
    if (!(scalar(@addrs) >= 1)) {
        $self->error("Duff addrs(@addrs) given to reminder"); 
    } else {
        my $o_bug = $self->object('bug')->read($bid);
		if (!($o_bug->READ)) {
			$self->debug(0, "Duff bid($bid) for reminder!");
		} else { 
			my $o_usr = $self->object('user');
			my $o_grp = $self->object('group');
			my ($title, $perlbug, $maintainer, $home) = 
				($self->system('title'), $self->email('perlbug'), $self->system('maintainer'), $self->web('hard_wired_url'));
			my ($statusid) = $o_bug->rel_ids('status');
			my ($status) = $o_bug->rel('status')->id2name([$statusid]) if $statusid;

			my ($gid) = my @gids = $o_bug->rel_ids('group');
			my ($group) = join(', ', $o_grp->id2name(\@gids)) if @gids;
			 
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
		
			To: $perlbug
			Subject: -H

		Bug report follows:
		$bugreport
			|;
			my $o_hdr = $self->get_header;
			$o_hdr->add('To' => $maintainer);
			$o_hdr->add('Cc' => join(', ', @addrs)) if @addrs;
			$o_hdr->add('Subject' => $self->system('title')." reminder of bug($bid) status");
			$ret = $self->send_mail($o_hdr, "$notice");
		}
	}
    return $ret;
}   # done reminder


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 1999 2000 2001

=cut

# 
1;


