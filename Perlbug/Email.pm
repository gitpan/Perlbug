# $Id: Email.pm,v 1.80 2001/02/07 16:20:18 perlbug Exp $ 
# 
# X-Perlbug-Admin-URL: http://bugs.perl.org/admin/perlbug.cgi?req=bidmids&bidmids=20000817.019
#
# TODO: 
# 

=head1 NAME

Perlbug::Email - Email interface to perlbug database.

=cut

package Perlbug::Email;
use Mail::Address;
use Mail::Send;
use Mail::Header;
use Mail::Internet;
use Data::Dumper;
use File::Spec; 
use Sys::Hostname;
use lib File::Spec->updir;
use Perlbug::Cmd;
@ISA = qw(Perlbug::Cmd);
use strict;
use vars qw($VERSION);
$VERSION = 1.74;
$|=1;
my $o_HEADER = 'non_existent_header_object';
my $o_MAIL = 'non_existent_mail_object';


=head1 DESCRIPTION

Email interface to perlbug database.

=head1 SYNOPSIS

    use Perlbug::Email;

    use Mail::Internet;

    my $o_mail = Mail::Internet->new(*STDIN); 

    my $o_perlbug = Perlbug::Email->new($o_mail);    

    my $call = $o_perlbug->switch;

    my $result = $o_perlbug->$call($o_mail); 

    print $result; # =1 (hopefully :-)


=head1 METHODS

=over 4

=item new

Create new Perlbug::Email object:

    my $pb = Perlbug::Email->new($o_mail); # Mail::Internet

=cut

sub new {
    my $class = shift;
	my $o_mail = shift || '';
	my $self = Perlbug::Cmd->new(@_);
    my $matches = $self->directory('config').'/Matches';
    my ($ok, $prefs) = $self->get_config_data($matches);
	if ($ok == 1) {
        $self = { %{$self}, %{$prefs}, 
			'obj'  => {},
			'attr' => {
				'cc'		=> '',       # 
    			'commands'	=> {},       # commands hash  
    			'address'	=> '',
				'mailing'	=> 1,        # presumably - not if historical
    			'bugid'	=> 'NULL',   # 
    			'messageid'	=> 'NULL',   # 
			},
		};
    }
	bless($self, $class);
	$self->_original_mail($o_mail);
	return $self;
}


=item _original_mail

Maintain original

=cut

sub _original_mail { # Mail::Internet
	my $self = shift;
	$self->debug('IN', @_);
	my $o_mail = shift;
	if (ref($o_mail)) {
		$o_MAIL = $o_mail;
		my $o_dup = $o_mail->head->dup;
		$self->_original_header($o_dup);
	}
	$self->debug('OUT', $o_MAIL);
	return $o_MAIL; # Mail::Internet
}

sub _original_header { # Mail::Header
	my $self = shift;
	$self->debug('IN', @_);
	my $o_hdr = shift || '';
	$o_HEADER = $o_hdr if ref($o_hdr);
	$self->debug('OUT', $o_HEADER);
	return $o_HEADER; # Mail::HEADER
}

=item original

Returns original field/s from header

=cut

sub original { # get lines
	my $self = shift;
	$self->debug('IN', @_);
	my $tag = shift || '';
	my $o_hdr = $self->_original_header;
	my @data = ();
	if (ref($o_hdr) and $tag =~ /\w+/) {
		@data = $o_hdr->get($tag);
		chomp(@data);
	};
	$self->debug('OUT', @data);
	return @data; # line/s
}

sub _duff_mail { # just for tests...
	my $self = shift;
	$self->debug('IN', @_);
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
	$self->debug('OUT', $o_mail);
	return $o_mail; # Mail::Internet
}


=item mailing

Switch mailing on/off, also sets email->mailer to 'test' if off

=cut

sub mailing { # 1|0
	my $self = shift;
	my $flag = shift;
	$self->debug('IN', @_);
	if (defined $flag and $flag =~ /^([01])$/) {
		$self->{'attr'}{'mailing'} = $1;
		$self->debug(2, "mailing set to '$1'");
		if ($self->{'attr'}{'mailing'} != 1) {
			$self->{'EMAIL'}{'mailer'} = 'test'; # cut sendmail :-)
			# $self->current('mailer', 'test'); # cut sendmail :-)
			my $mailer = $self->email('mailer');
			$self->debug(1, "mailing set to 'test'? -> '$mailer'");
		}
	}		
	$self->debug('OUT', $self->{'attr'}{'mailing'});
	return $self->{'attr'}{'mailing'};
}


=item splice

Returns the original mail spliced up into useful bits, set from L<parse_mail> or L<switch>, or given as arg.

    my ($o_hdr, $header, $body) = $self->splice; # or splice($o_mail);

=cut

sub splice { # splice o_mail into useful bits
    my $self = shift;
	$self->debug('IN', @_);
	my $mail = shift || $self->_mail; # expecting a Mail::Internet->new(\$STDIN) product
	unless (ref($mail)) {	
		$self->fatal("Can't splice mail($mail) object!")
	}
    $mail->remove_sig;
    my @data = (
        $mail->head,
        join('', @{$mail->head->header}),
        join('', @{$mail->body}),
    );
	$self->debug('OUT', $data[0], length($data[1]), length($data[2]));
	return @data;
}


=item parse_mail

Given a mail (Mail::Internet) object, parses it into command hash, also checks the header for X-Perlbug loop and the address of the sender via L<check_user>.

    my ($h_commands, $body) = $pb->parse_mail($o_mail);

=cut

sub parse_mail { # bugdb@perl.org|*@bugs.perl.org -> includes check_user
    my $self = shift;
	$self->debug('IN', @_);
	my $o_mail = shift || $self->_mail;
	my $h_cmds = {};
    my ($o_hdr, $header, $body) = $self->splice($o_mail);
    if ($self->check_header($o_hdr)) {
		my $commands = '-h'; # :-) 
        my $user  = $self->check_user($o_hdr->get('From')); # sets admin
        my $debug = ($self->isadmin eq $self->system('bugmaster')) 
			? "user($user), debug(".$self->current('debug')."), version($Perlbug::VERSION), ref($$, $0) $o_hdr\n" 
			: '';
        $self->debug(0, $debug);
        ($commands, $body) = $self->scan_header($o_hdr, $body);
		$h_cmds = $self->parse_commands($commands, $body); # -a <bugids...> close install
	}
	$self->{'attr'}{'commands'} = $h_cmds if ref($h_cmds) eq 'HASH';
	$self->debug('OUT', Dumper($h_cmds).$body);
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
	$self->debug('IN', "@addrs");
	my $from = '';
	my $i_ok = 1;
	if (scalar(@addrs) >= 1) {
		my (@o_addrs) = Mail::Address->parse(@addrs);
		ADDR:
		foreach my $addr ( map { $_->address } @o_addrs ) { # or format?
			chomp($addr);
			next ADDR unless $addr =~ /\w+/;
			next ADDR if grep(/^$addr$/i, $self->get_vals('target'), $self->get_vals('forward'), $self->email('bugdb'), $self->email('bugtron'));
			next ADDR unless $self->ck822($addr);
			$from = $addr;
			chomp($from);
			$self->debug(2, "from address($from)");
			last ADDR;
		}
	}
	$self->debug('OUT', $from);
	return $from;
}


=item check_header

Checks (incoming) email header against our X-Perlbug flags, also slurps up the Message-Id for future reference.

    my $i_ok = $o_perlbug->check_header($o_hdr); # or undef

=cut

sub check_header { # incoming
    my $self  = shift;
	$self->debug('IN', @_);
    my $o_hdr = shift;
    my $i_ok  = 1;
    $self->debug(3, "check_header($o_hdr)");
    my $dodgy = $self->dodgy_addresses('from'); 
	my $tests = $self->dodgy_addresses('test');
    if (!ref($o_hdr)) {
		$i_ok = 0;
		$self->debug(0, "No hdr($o_hdr) given");
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
			$self->debug(0, "X-Test mail -> setting test flag");
			$self->isatest(1);
		}
    } 
    # $self->debug(0, "check_header found a problem ($o_hdr)") unless $i_ok == 1;
	$self->debug('OUT', $i_ok);
    return $i_ok;
}


=item check_user

Checks the address given (From usually) against the tm_user table, sets user or admin access priviliges via the switches mechanism accordingly. 

Returns admin name

    my $admin = $pb->check_user($mail->('From')); # -> user_id || blank

=cut

sub check_user { # from address against database
    my $self = shift;
	$self->debug('IN', @_);
    my $given = shift;
    chomp $given;
	# rjsf - parse address!
    $self->debug(3, "check_user($given)");
    my @addrs = $self->get_data('SELECT userid, match_address FROM tm_user'); # SQL LIKE ?
    ADDR:
    foreach my $data (@addrs) {
        my $userid = $$data{'userid'};
        my $match_address = $$data{'match_address'};
        if ($given =~ /$match_address/i) { # an administrator
            $self->current('admin', $userid);
            $self->debug(1, "Setting admin($userid) switches");
            my $switches = $self->system('user_switches').$self->system('admin_switches');
            $self->current('switches', $switches);
            last ADDR;
        } 
    }
	$self->current('switches', $self->system('user_switches')) unless $self->isadmin;
	$self->debug('OUT', $self->isadmin);
	return $self->isadmin;
}


=item return_info

Takes data ($a_stuff), which may be a ref to the result array, and mails 
it to the From or Reply-To address, Cc:-ing it to any address given by the C<-e> flag.  

    my $i_ok = $pb->return_info($o_mail, $a_stuff);

=cut

sub return_info { # -> from bugdb send_mail
    my $self  = shift;
    $self->debug('IN', @_);
	my $mail  = shift || $self->_mail;
    my $stuff = shift;
    my $data = (ref($stuff) eq 'ARRAY') ? join('', @{$stuff}) : $stuff;
    $self->debug(3, 'return_info: length('.length($data).')');
    my ($o_hdr, $head, $body) = $self->splice($mail);
    $data =~ s/^\s*\.\s*$//g;   # replace troublesome (in email) dots
    my ($title, $maintainer) = ($self->system('title'), $self->system('maintainer'));
    chomp(my ($from, $subject, $reply) = ($o_hdr->get('From'), $o_hdr->get('Subject'), $o_hdr->get('Reply-To')));
    my $header = $self->read('header');
	$header =~ s/Perlbug::VERSION/ - v$Perlbug::VERSION/i;
    my $footer = $self->read('footer');
    my $o_reply = $self->get_header($o_hdr);
	$o_reply->replace('To', $self->from($reply, $from));
    $o_reply->replace('Subject', "$title response: $subject");
    $o_reply->delete('Cc');
	$o_reply->add('Cc', $self->{'attr'}{'cc'}) if defined($self->{'attr'}{'cc'} and $self->{'attr'}{'cc'} =~ /\w+/);
    my $i_ok = $self->send_mail($o_reply, $header.$data.$footer, 'default'); #
	$self->debug('OUT', $i_ok);
	return $i_ok; # 0|1
}            


=item _mail

Get and set the incoming mail object (Mail::Internet)

Returned (used) via L<splice()>

=cut

sub _mail { # 
	my $self = shift;
	$self->debug('IN', @_);
	my $o_mail = shift || $self->_original_mail;
	$self->debug('OUT', $o_mail);
	return $o_mail; # Mail::Internet
}


=item doh

Wraps help message

=cut

sub doh { # help wrapper and modifier
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	my $title = $self->system('title');
	my $res = $self->SUPER::doh(
		'D' => 'Database dump retrieval by email, with optional date filter (20001225)', 
		'e' => 'email a copy to me too (emaila.copy@to.me.too.com)',
		'H' => 'Heavier Help ()',
		# 'p' => 'propose changes to the following (<bugids>)',
	);
	$res .= $self->read('mailhelp');
	$self->debug('OUT', $res);
	return $res;
}


=item doH

Returns more detailed help.

=cut

sub doH { # help wrapper (verbose)
    my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
    my $HELP = $self->help;
    my $bugdb= $self->email('bugdb');
    my $home = $self->web('home');
	# my $HELP = $self->read($self->directory('docs').'/mailhelp');
    $HELP .= qq|
NOTE:
All switches and arguments to the email interface are expected to be separated by a space.

RETRIEVAL:
There are several different ways of searching the db:
    by bugid:       b, B
    by messagid:    m
	by group:       g
    by subject:     s
    by messagebody: r
	by category:    j
	by sql query:   q
    by overview:    o

Upper case letters usually expand upon or reverse the effect of the lowercase command in some way.

j will return all bugs by group: category\|status\|osname\|severity.
eg; 
    '-j low library'  (status = 'low' and category = 'library') 
    '-j lo li'        (status = 'low' and category = 'library')
    '-j l'      	  (status = 'low' and category = 'library' :-)
    '-j mac op pat'   (status = open and category = 'patch' and osname = 'macos')

Note that 'p' is acceptable as a shortened form of 'patch' etc. and may 
be defined by either the first letter or the next several letters, if they 
uniquely identify the available flag, (look at 'l').  If not unique you get all 
the flags in an 'and' operation.

The sql query (q) command expects to see the keyword 'select' at the start of each 
query included in the body of the email.  These are not restricted to any particular 
set of fields and it is possible to exersize full searches on the db.
    
When an item is requested from the db, the data is formatted according to the 
format (-f) flag setting and returned via email.  The supported flags are: 
    a (ascii-default), A (ascii-extended), l, (ascii-list), h (html), H (more data in your HTML)
    |;
    $HELP .= q|
ADMINISTRATION: 
The admin (-a) command reads like this:
    set these flags, (if not an admin of this particular bug - make me one),
    in the following bugids eg;
    
    -a close build 19990606.002 19990606.003 
        #translates to:
            UPDATE tm_bug
            SET status = 'closed' and category = 'build' 
            WHERE bugid IN ('19990606.002', '19990606.003')
        
    Shortcuts are acceptable and '-A' has added-value by returning the bug
    -A cl pa 19990606.002 19990606.003
        #translates to:
        	UPDATE tm_bug
        	SET status = 'closed' and category = 'patch'
        	WHERE bugid IN ('19990606.002', '19990606.003')
    
	You may also use the (To\|Cc): addresses to a similar effect:
	
	To: close_19990606.002_install@bugs.perl.org
	
	|;
    $HELP .= qq|
EXAMPLE:
Below is an example email which retrieves bugs: '19990606.002' and
'19990606.003', then returns this help message, along with all open bugs, 
and those which are still open and under the patch category, then returns the 
results with a copy to the extra email address:

    To: $bugdb
    Subject: -e my\@other.address -b 19990606.002 19990606.003 -h -j pa

    
TUTORIAL:
Beginners may get used to the system by trying out these subject lines:
    -h
    -o
    -b 19990606.002
    -B 19990606.003 
    -m 777
    -j util clos
    -j b sev op
    -o -h -m 3 55 21 -c abandoned patch -fA
etc.
    |;
    my $maintainer = $self->system('maintainer');
    $HELP .= "\nComments, feedback, suggestions to '$maintainer'.\n";
	$self->debug('OUT', $HELP);
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
	$self->debug('IN', @_);
	my $o_orig = shift || '';
	my $context= shift || 'default';
	my $i_ok   = 1;
	my $o_hdr  = Mail::Header->new;
	if (ref($o_orig)) { # partially fresh
		foreach my $tag ($o_orig->tags) { 
			my @lines = $o_orig->get($tag);
			my @res = $self->$context($tag, @lines); # default|remap
			$o_hdr->add($tag, @res) if scalar(@res) >= 1;
		}
	}
	undef $o_hdr unless $i_ok == 1; 
	$self->debug('OUT', $o_hdr);
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
	$self->debug('IN', @_);
    my $tag   = shift;
    my @lines = @_;
	chomp(@lines);
	my @res   = ();
    my $i_ok  = 1;
	if ($tag !~ /\w+/) {
		$i_ok = 0;
		$self->debug(0, "Invalid tag($tag) given for default($tag, @lines)");
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
		$self->debug(3, "tag($tag) defaulted to lines(@res)");
	}
	chomp(@res);
	$self->debug('OUT', @res);
    return @res;
}


=item remap

Operating on a given tag, remaps (To|Cc) -> forwarding address, removes duplicates.

Attempt to remain moderately invisible by maintaining all other original headers.

    my @lines = $self->remap($tag, @lines);

=cut

sub remap { # modify given tag, line
    my $self = shift;
	$self->debug('IN', @_);
    my $tag  = shift;
    my @lines= @_;
	chomp(@lines);
	my %res = ();
	if ($tag !~ /\w+/) {
		$self->debug(0, "Invalid tag($tag) given for remap($tag, @lines)");
	} else {
		# my @targets = $self->get_vals('target');
		my @targets = split(/\s+/, $self->get_vals('target'));
		if ($tag =~ /^(To|Cc)$/i) { # reply-to?
			$self->debug(3, "remapping tag($tag: @lines) with our targets?: (@targets)");	
			LINE:
			foreach my $line (@lines) {
				next LINE unless $line =~ /\w+/;
				if (grep(/$line/i, @targets)) {	# one of ours
					my @forward = $self->get_forward($line);        # find or use generic
					map { $res{$_}++ } @forward ;  					# chunk dupes
					$self->debug(1, "applying ($tag $line) -> @forward");						
        		} else {											# keep
					$res{$line}++;
					$self->debug(3, "line NOT one of ours: keeping line($line)");	
    			}
			}
		} else {
			map { $res{$_}++ } @lines;
			$self->debug(4, "Tag NOT a To/Cc($tag): keeping original(@lines)");
		}
	}
	my @res = keys %res;
	chomp(@res);
	$self->debug('OUT', @res);
    return @res;
}


=item send_mail

Send a mail with protection.

    my $ok = $email->send_mail($o_hdr, $body);

=cut

sub send_mail { # sends mail :-) 
    my $self  = shift;
	$self->debug('IN', @_);
    my $o_hdr = shift;	# prep'd Mail::Header
    my $body  = shift;	# 
    $self->debug(2, "send_mail($o_hdr, body(".length($body)."))");
	my $max = 250001; # 10001;
	if ($o_hdr->get('From') eq $self->email('from') and length($body) >= $max) {
		if (!($self->{'commands'}{'D'} == 1 || $self->{'commands'}{'L'} =~ /\w+/)) {
			$self->debug(0, "trimming body(".length($body).") to something practical($max)");
			$body = substr($body, 0, $max);
			$body .= "Your email exceeded maximum permitted value and has been truncated($max)\n";
		}
	}
	my $i_ok  = 1;
	$o_hdr = $self->defense($o_hdr); 
	if (!ref($o_hdr)) { 	# Mail::Header
		$i_ok = 0;
		$self->debug(0, "requires a valid header($o_hdr) to send!");
	} else {
		($o_hdr, my $data) = $self->tester($o_hdr);
		$body = $data.$body;
		my @to = $o_hdr->get('To');
		my @cc = $o_hdr->get('Cc') || ();
		chomp(@to, @cc);
        $self->debug(0, "Mail to(@to), cc(@cc)");
		if ($self->isatest) { # ------------------------------
			my $o_send = Mail::Send->new;
			TAG:
	        foreach my $tag ($o_hdr->tags) {
				next TAG unless $tag =~ /\w+/;
				my @lines = $o_hdr->get($tag) || ();
				foreach my $line (@lines) {
					chomp($line);
					$o_send->set($tag, $line);
				}
			}
			my $mailer = $self->email('mailer') || 'sendmail'; # or mail or test  
   		 	my $mailFH = $o_send->open($mailer) or $self->debug(0, "Couldn't open mailer($mailer): $!");
        	if (defined($mailFH)) { # Mail::Mailer
            	if (print $mailFH $body) {
					$self->debug(3, "Body printed to mailfh($mailFH)");
				} else {
					$i_ok = 0;
					$self->debug(0, "Can't send mail to mailfh($mailFH)");
            	}
				$mailFH->close; # ? sends twice from tmtowtdi, once from pc026991, once from bluepc? 
				$self->debug(0, "Mail($mailFH) sent!(".length($body).") -> to(@to), cc(@cc)");
        	} else {
            	$i_ok = 0;
            	$self->debug(0, "Undefined mailfh($mailFH), can't mail data($body)");
        	}
		} else { # live --------------------------------------------------------
			my $hdr = '';
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
			if (open(MAIL, "|/usr/lib/sendmail -t")) {  		# :-( sigh...
        		if (print MAIL "$hdr\n$body\n") {
					if (close MAIL) {
						$self->debug(0, "Mail(MAIL) sent?(".length($body).") -> to(@to), cc(@cc)");
					} else {
						$i_ok = 0;
						$self->debug(0, "Can't close sendmail");
					}
				} else {
					$i_ok = 0;
					$self->debug(0, "Can't print to sendmail");
				} 
        	} else {
				$i_ok = 0;
				$self->debug(0, "Can't open sendmail")
			} # ----------------------------------------------------------------
		}
    }
	$self->debug('OUT', $i_ok);
    return $i_ok;
}


=item tester

If test mail, turn header to maintainer and return header data for insertion

=cut

sub tester {
    my $self  = shift;
	$self->debug('IN', @_);
    my $o_hdr = shift; # Mail::Header
    my $data  = '';
	my $i_ok  = 1; 		
	if (!ref($o_hdr)) {
    	$i_ok = 0;
		$self->debug(0, "requires a valid Mail::Header($o_hdr) to test");
	} else {
		if ($self->isatest) {
			my $from = $self->email('from');
			$self->{'EMAIL'}{'mailer'} = 'test' if $self->isatest == 2;
			$self->debug(0, "Test: dumping to maintainer...");
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
	$self->debug('OUT', $o_hdr, length($data));
	return ($o_hdr, $data); 	# Mail::Header and dump
}


=item defense

Set mail defaults for _all_ mail emanating from here, calls L<clean_header()> -> L<trim_to()>.

    my $o_hdr = $self->defense($o_hdr); 

=cut

sub defense { # against duff outgoing headers
    my $self  = shift;
	$self->debug('IN', @_);
    my $o_hdr = shift; # Mail::Header
    my $i_ok  = 1; 		
	my $dodgy = $self->dodgy_addresses('to');
	if (!ref($o_hdr)) {
    	$i_ok = 0;
		$self->debug(0, "requires a valid Mail::Header($o_hdr) to defend");
	} else {
		$o_hdr = $self->clean_header($o_hdr);	# (inc trim_to)
		if (ref($o_hdr)) {
			$o_hdr->add('X-Original-From', $self->original('From', 'Reply-To'));
			$o_hdr->add('X-Original-To', $self->original('To'));
			$o_hdr->add('X-Original-Subject', $self->original('Subject'));
			$o_hdr->add('X-Original-Message-Id', $self->original('Message-Id'));
			my $cc = join(', ', $self->original('Cc'));
			$o_hdr->add('X-Original-Cc', $cc) if $cc =~ /\w+/;
			#
			$o_hdr->replace('X-Perlbug-Test', 'test') if $self->isatest;
			$o_hdr->replace('X-Perlbug', "Perlbug(tron) v$Perlbug::VERSION"); # [ID ...]+
			$o_hdr->replace('From', $self->email('from')) unless defined($o_hdr->get('From'));
			$o_hdr->replace('X-Errors-To', $self->system('maintainer')) unless defined($o_hdr->get('X-Errors-To')); 
			$o_hdr->replace('Return-Path', $self->system('maintainer')); 
				# unless defined($o_hdr->get('Return-Path')); 
			$o_hdr->replace('Message-Id', "<$$".'_'.rand(time)."\@".$self->email('domain').'>') unless defined($o_hdr->get('Message-Id'));
			my $msgid = $o_hdr->get('Message-Id') || '';
			chomp($msgid);
			if (defined($self->{'defense'}{$msgid}) and $self->{'defense'}{$msgid} >= 1) {
				$i_ok = 0;
				$self->debug(0, "found duplicate Message-Id($msgid)!");
			} 
    		$self->{'defense'}{$msgid}++;
        	$o_hdr->add('Bcc', $self->system('maintainer')) if $self->current('debug') >= 3; 
		}
	}
	undef $o_hdr unless $i_ok == 1;
	$self->debug('OUT', $o_hdr);
	return $o_hdr; 	# Mail::Header
}


=item clean_header

Clean header of non-compliant 822 address lines using Mail::Address::parse()

	my $o_hdr = $o_mail->clean_header($o_hdr);

=cut

sub clean_header { # of invalid addresses
	my $self  = shift;
	$self->debug('IN', @_);
	my $o_hdr = shift;	# Mail::Header
	my $i_ok = 1;
	if (!ref($o_hdr)) {
		$i_ok = 0;
		$self->debug("requires a valid Mail::Header($o_hdr) to clean");
	} else {
		my @cc = $o_hdr->get('Cc');
		foreach my $tag ($o_hdr->tags) {
			if ($tag =~ /^(To|Bcc|Cc|From|Reply-To|Return-Path)$/i) {
				my @lines = $o_hdr->get($tag) || ();
				$o_hdr->delete($tag); # if defined($o_hdr->get($tag));
				my (@o_addrs) = Mail::Address->parse(@lines);
				my @addrs = ();
				ADDR:
				foreach my $addr ( map { $_->address } @o_addrs ) {
					push(@addrs, $addr); # if $self->ck822($addr);
				}
				chomp(@addrs);
				if ($tag eq 'To') {
					if (!(scalar(@addrs) >= 1)) {
						$self->debug(0, "!!! $tag(@lines) cleaned to (@addrs) ?!");
					}
				}
				$o_hdr->add($tag, join(', ', @addrs)) if scalar(@addrs) >= 1;
			}
		}
		$o_hdr = $self->trim_to($o_hdr);
		$o_hdr->cleanup if ref($o_hdr); # remove empty lines
	}
	undef $o_hdr unless $i_ok == 1;
	$self->debug('OUT', $o_hdr);
	return $o_hdr;		# Mail::Header
}


=item trim_to

Takes the header and returns it without any dodgy to, or cc addresses (or undef):

	my $o_hdr = $o_obj->trim_to($o_hdr);

=cut

sub trim_to { # Mail::Header -> Mail::Header
    my $self   = shift;
    $self->debug('IN', @_);
    my $o_hdr  = shift;		# Mail::Header
    my $i_ok   = 1;
    if (!ref($o_hdr)) {
    	$i_ok = 0;
		$self->debug(0, "requires a valid Mail::Header($o_hdr) to trim");
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
		    $self->debug(0, "no-one to send mail to ($to)!");
		} else {
		    if (grep(/^($dodgy)$/i, $to, @cc)) { # final check
			$i_ok = 0;
			$self->debug(0, "Managed to find a duff address: '$to, @cc'!"); 
		    } else {
			$self->debug(2, "whoto looks ok: '$to, @cc'");
			$o_hdr->add('To', $to);
			$o_hdr->add('Cc', join(', ', @cc)) if scalar(@cc) >= 1; 
		    }
		} 
	}			
	undef $o_hdr unless $i_ok == 1;
	$self->debug('OUT', $o_hdr);
	return $o_hdr; 	# Mail::Header
}


=item get_forward

Operating on a single (or blank) address, returns a list of forwarding addresses.

    my $to = $perlbug->get_forward('perlbug@perl.org'); # perl5-porters@perl.org

	my $to = $perlbug->get_forward('perl-win32-porters@perl.org'); # perl-win32-porters@perl.org
    
    my $to = $perlbug->get_forward();                   # perl5-porters@perl.org
                    
    my @to = $perlbug->get_forward();                   # perl5-porters@perl.org perl-win32-porters@perl.org etc...

=cut

sub get_forward { # forward to mailing lists
    my $self = shift;
    $self->debug('IN', @_);
    my $tgt  = shift; # perlbug@perl.com 
	my $dest = '';
    my @dest = ();
	TYPE:
	foreach my $type ($self->get_keys('target')) { 
		next if $type eq 'generic';
		my $potential = $self->target($type); 
		my @potential = split(/\s+/, $potential);
		# $self->debug(1, "$type(?): $tgt in(@potential)");
		foreach my $pot (@potential) {
			if ($tgt =~ /^$pot$/i) {   # found which one
				my $forward = $self->forward($type);
				($dest) = @dest = ($forward =~ /\s+/) ? split(/\s+/, $forward) : ($forward); # handle com|org and mailing lists
				$self->debug(0, "found tgt($tgt) -> $type -> dst(@dest)");
				last TYPE;
			} else {
				$self->debug(3, "$type: '$pot' not applicable");
			}
		}
	}
	if (!(scalar(@dest) >= 1)) { 						# not found = default
		($dest) = @dest = ($self->forward('generic'));
		$self->debug(1, "setting generic tgt($tgt) -> dst($dest)");
	}
	$self->debug('OUT', @dest);
    return wantarray ? @dest : $dest;
}



=item switch

Returns appropriate method name to call to handle this mail.

This enables you to bypass the suggested method with your own call (be it on your own head :-):

    my $call = $pb->switch(Mail::Internet->new(\$STDIN);     

=cut

sub switch { # decision mechanism for tron recieved mails
    my $self    = shift;
    $self->debug('IN', @_);
    my $mail    = shift || $self->_mail;           # Mail::Internet->new(*STDIN);
    my $found   = 0;
	my $switch  = 'quiet';  
	my $msg 	= 'zip';     
	if (!ref($mail)) {
		$found++;
		$self->debug(0, "requires Mail::Internet($mail) for decision");
	}

    # which address group?

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
    	my $messageid = $mail->head->get('Message-Id') || '';
    	chomp($from, $subject,  $messageid, $replyto, $inreply, $to, @cc);
		($to) = map { ($_->address) } Mail::Address->parse($to);
		(@cc  = map { ($_->address) } Mail::Address->parse(@cc)) if @cc;
    	$self->debug(1, "$0: To($to), From($from), Subject($subject), Cc(@cc), Message-Id($messageid), Reply-To($replyto), In-Reply-To($inreply)");
    	my $target = ''; # to/cc...
		my @addresses = ();
		my $i_ok = $self->check_header($o_hdr);
		if ($i_ok == 0) {
      		$switch = 'quiet'; $found++;
			$msg = "X-Header found something duff! =:-[]";
      		$self->debug(1, $msg);
    	}

		# which to/cc are we using?
    	if ($found != 1) {
			my $domain = $self->email('domain');
			ADDR:
			foreach my $addr ($to, @cc) { # 
				next ADDR unless $addr =~ /\w+/;
				if ($addr =~ /^(.+)\@$domain/i) { # *@bugs.perl.org
					$target = $1;
					last ADDR;
					$self->debug(1, "using addr($addr) -> target($target)");
				} 
			}
		}
		# and then we ignore target, if it's for bugs.perl.org???
		
    	# Have we seen messageid in db before? -> TRASH it
    	if ($found != 1) {
        	if ($messageid =~ /(\<.+\>)/) {    # trim it
            	$self->debug(2, "Looking at messageid($messageid)");
            	$messageid = $self->quote($1); # escape it
            	$messageid =~ s/\'(.+)\'/$1/;  # unquote it
            	$messageid = "%Message-Id: $messageid%";
				my $sql = qq|SELECT messageid FROM tm_message WHERE UPPER(msgheader) LIKE UPPER('$messageid')|;
            	$self->debug(2, "Have we seen this messageid before? ($sql)");
            	my @mseen = $self->get_list($sql);
            	if (scalar @mseen >= 1) {
					my $mids = join("', '", @mseen);
					my $sql = qq|SELECT DISTINCT bugid FROM tm_bug_message WHERE messageid IN ('$mids')|;
            		my @bseen = $self->get_list($sql);
					if (scalar(@bseen) >= 1) {
	                	$found++;
    	            	$switch = 'quiet'; 
						$msg = "CLONE $switch($found) seen it before (@bseen), bale out! :-(( mids='$mids'";
            	 		$self->debug(1, $msg); 
            		} else {
						$self->debug(2, "Nope, bugid not found(@bseen)");
					}
				} else {
                	$self->debug(2, "Nope, messageid not found(@mseen)");
            	}
        	} else {
            	$self->debug(2, "Messageid not usable($messageid), ignoring it ($found)");
        	}
    	}

		# Is there a bugid in the subject? -> REPLY
    	if ($found != 1) {   
        	if (my @subs = ($subject =~ /\b(\d{8}\.\d{3})\b/)) {    
				foreach my $bid (@subs) {
					$self->debug(2, "Looking at subject/bugid($bid)"); # if in DB?
					my $sql = qq|SELECT bugid FROM tm_bug WHERE bugid = '$bid'|;
					my @seen = $self->get_list($sql);
					$self->debug(2, "Is this a reply to a bug id in the subject? ($sql)");
					if (scalar @seen >= 1) {
						$found++;
						$self->{'attr'}{'bugid'} = $bid;
						$switch = 'reply'; 
						$msg = "REPLY $switch($found) from subject: ($bid) :-)";
						$self->debug(1, $msg); 
					} else {
						$self->debug(2, "Nope, bugid($bid) not found(@seen)");
					}
				}
			} else {
				$self->debug(2, "Subject/bugid not relevant($subject), ignoring it ($found)");
			}
		}
		
		# Is there a ^[(BUG|PATCH|TEST|NOTE)] in the subject? (not BUG! see below)
		# if ($found != 1) { 		# not yet...
		if ($found eq 'xa-1 7 123az^') { 	# unlikely :-)
			foreach my $pos (qw(note patch test)) { # $self->objects
        		my $match = $self->match($pos);
				if ($subject =~ /$match/) {
					$found++;
					$switch = $pos;
					$msg = "NEW $switch($found) in subject:)";
                	$self->debug(1, $msg);
            	} else {
               		$self->debug(3, "Nope, item($pos) not recognised in subject");
            	}
			}
    	}        
		
		# Is there a ^(bug|patch|test|note)_ in the to/cc?
		# these all go to -> mail.pl
		#
		# (mail|tron)->switch()
		# if $mail->isnonbouncer...
		# if $mail->isfortargets() -> tron
		# if $mail->isforus() -> mail
		# else -> scrapit
		
		# Is it a reply to an unknown/unrecognised bug (in the subject) in the db? -> REPLY
    	if ($found != 1) {  
        	if ($inreply =~ /(\<.+\>)/) {
            	$inreply = $self->quote($1); # escape it
            	$self->debug(2, "Looking at in-reply-to($inreply)");
            	$inreply =~ s/\'(.+)\'/$1/;  # unquote it
            	# $inreply = quotemeta($inreply);
            	$inreply = "%Message-Id: $inreply%";
				my $sql = qq|SELECT messageid FROM tm_message WHERE UPPER(msgheader) LIKE UPPER('$inreply')|;    
            	$self->debug(2, "Is this an in-reply-to a bug? ($sql)");
            	my @mreply = $self->get_list($sql);
            	if (scalar @mreply >= 1) {
                	my $mids = join("', '", @mreply);
					my $sql = qq|SELECT DISTINCT bugid FROM tm_bug_message WHERE messageid IN ('$mids')|;
            		my @breply = $self->get_list($sql);
					if (scalar(@breply) >= 1 && $self->ok($breply[0])) { # =~ /(\d{8}\.\d{3})/) {
						$found++;
                		my $bid = $self->{'attr'}{'bugid'} = $1; # !
                		$switch = 'reply'; 
						$msg = "REPLY $switch($found): to previously unknown BUGID ($bid) - @breply) ;-)";
                		$self->debug(1, $msg);
					} else {
                		$self->debug(2, "Nope, reply not found(@breply)");
					}
            	} else {
                	$self->debug(2, "Nope, reply not found(@mreply)");
            	}
        	} else {
            	$self->debug(2, "In-Reply-To not usable ($inreply), ignoring it ($found)");
        	}
    	}        
		
		# Is it addressed to perlbug? -> NEW or BOUNCE
    	if ($found != 1) {  
        	my $match = $self->email('match');
        	my @targets = $self->get_vals('target'); # rjsf
        	$self->debug(2, "Looking at addresses to($to), cc(@cc) against targets(@targets)?");
        	ADDR:
			foreach my $line ($to, @cc) {
				next ADDR unless $line =~ /\w+/;
				last ADDR if $found >= 1;
				if (grep(/$line/i, @targets)) {	# one of ours
		    		$self->debug(2, "Address($line) match :-), have we a match($match) in the body?");
            		if ($body =~ /$match/i) {    # new \bperl|perl\b
                		$found++;
                		$switch = 'new';
						$msg = "NEW BUG $switch($found): Yup! perl($match) subject($subject) :-))";
                		$self->debug(1, $msg);
            		} else {                            # spam?
                		$found++;
                		$switch = 'bounce'; 
                		$self->debug(1, "Nope, $switch($found): addressed to one of us, but with no match in body(".length($body).") :-||");
            		}
        		} else {
            		$self->debug(2, "address($line) not relevant pass($found)");
        		}
			}
			$self->debug(2, "Addressed and bodied to us? ($found) <- ($to, @cc)"); # unless $found == 1;
    	}
	}
	
	# Catch all -> TRASH it
    if ($found != 1) {  
        $switch = 'quiet';
		$msg = "IGNORE $switch($found): invalid perlbug data, potential p5p miscellanea or spam) :-|";
        $self->debug(1, $msg);
    }
    $self->debug(1, "Decision -> do_$switch($found)");
    $self->debug('OUT', 'do_'.$switch);

    return ('do_'.$switch, $msg); # do_(new|reply|quiet|bounce) (do_$res, $reason) (look in the logs)
}


=item do_new

Deal with a new bug

=cut

sub do_new { # bug
    my $self = shift;
    $self->debug('IN', @_);
    my $mail = shift || $self->_mail;
    my ($o_hdr, $header, $body) = $self->splice($mail);
    $self->{'attr'}{'bugid'} = '';
    my ($ok, $err, $msg, $bid, $mid) = (1, '', '', '', '');
    my $from      = $o_hdr->get('From');
    my $subject   = $o_hdr->get('Subject');
    my $to        = $o_hdr->get('To');
    my @cc        = $o_hdr->get('Cc');
    my $reply     = $o_hdr->get('Reply-To') || '';
	my $messageid = $o_hdr->get('Message-Id');
    chomp($from, $subject, $to, $reply, $messageid);
	my $origsubj  = $subject;
	$self->debug(0, "NEW BUG: from($from), subject($subject), to($to), message($messageid)");
    $self->{'attr'}{'messageid'} = $messageid;
	my ($title, $tron, $maint) = ($self->system('title'), $self->email('tron'), $self->system('maintainer'));
	my $h_tkt = {};
    # Open a new bug in the database
    if ($ok == 1) {
        ($ok, $bid, $mid) = $self->insert_bug($subject, $from, $to, $header, $body);
    }
    if ($ok == 1) {
        $self->{'attr'}{'bugid'} = $bid;
        $subject = "[ID $bid] $subject"; 
        $o_hdr->replace('Subject', $subject);
        $h_tkt = $self->scan($body);
        if (ref($h_tkt) eq 'HASH') {
            if ($origsubj =~ /^\s*OK:/) {
				$$h_tkt{'category'} = 'install';
				$$h_tkt{'status'} = 'ok';
			}
			$ok = $self->bug_set($bid, $h_tkt); # inc. tracking
        } else {
            $ok = 0;
            $err = 'SCAN failure';
        }
    }
	if ($ok == 1) {
		($ok, my @ccs) = $self->tm_bug_address($bid, $to, @cc);
	}
	my $url = $self->web('hard_wired_url');
	$o_hdr->add('X-Perlbug-Url-Bug', "$url?req=bid&bid=$bid");
	my $perlbug = $self->web('cgi');
	$url =~ s/$perlbug/admin\/$perlbug/;
	$o_hdr->add('X-Perlbug-Admin-Url-Bug', "$url?req=bidmids&bidmids=$bid");
    if ($ok == 1 && $self->mailing) {                   # NOTIFY	
		my $o_reply = $self->get_header($o_hdr, 'remap');	# p5p
		my @ccs =  $self->bugid_2_addresses($bid, 'new');	# groups, etc
		$o_reply->replace('Cc', join(', ', @ccs));
		$ok = $self->send_mail($o_reply, $body); # auto
        $err = ($ok == 1) ? "Notified" : "Failed to notify master and groups";             
    }
    if ($ok == 1) {
		if ($body =~ /(ack=no)/imsg) { # DON'T send a response back to the source 
			$self->debug(2, "NOT($1) sending form response.");
		} else {
			$self->debug(3, "Sending form response.");
			my $o_response = $self->get_header($o_hdr);
			$o_response->replace('Subject', "Ack: $subject");
			$o_response->replace('To', $self->from($reply, $from)); 
			$o_response->add('X-Perlbug-Admin-Url-Bug', "$url?req=bid&bid=$bid");
			$o_response->add('X-Perlbug-Url-Bug', "$url?req=bid&bid=$bid");
			my $response = $self->read('response');
			my $footer   = $self->read('footer');
			$response =~ s/Bug\sID/Bug ID ($bid)/;
			$response =~ s/(Original\ssubject:)/$1 $origsubj/;
				$ok = $self->send_mail($o_response, $response.$footer);
		}
    }
    $self->debug('OUT', $ok);
    return $ok;
}


sub do_bug { # wrapper
	my $self = shift;
	return $self->do_new(@_);
}


=item scan

Scan for perl relevant data putting found or default switches in $h_data.
Looking for both category=docs and '\brunning\s*under\ssome\s*perl' style markers.

    my $h_data = $o_mail->scan($body);
    
    my $res = $o_mail->bug_set($bid, $h_data);

=cut

sub scan { # bug body 
    my $self    = shift;
    $self->debug('IN', @_);
    my $body    = shift;
    my %set     = ();
    my $ok      = 1;
    my $i_cnt   = 0;
	$self->debug(2, "Scanning mail (".length($body).")");
    my %flags = $self->all_flags;
    my %data =  (   # default
        'category'  => $self->default('category') || 'unknown',
        'osname'    => $self->default('osname')   || 'generic',
        'severity'  => $self->default('severity') || 'low',
        'status'    => $self->default('status')   || 'open',
        'version' => $self->default('version')  || '5',
    );
	LINE:
    foreach my $line (split(/\n/, $body)) {         # look at each line for a type match
        $i_cnt++;
		next unless defined($line) && $line =~ /\w+/;
		$self->debug(3, "line($line)");
		TYPE:
        foreach my $type (keys %flags, 'version') {     # status, category, severity...
            $self->debug(4, "type($type)");
			next TYPE if defined($set{$type}) and ($set{$type} >= 1); # set the first match only?
            # PERLBUG?
            my @setindb = @{$flags{$type}} if ref($flags{$type}) eq 'ARRAY';
            if ((@setindb >= 1) && ($type ne 'version')) {      # SET by perlbug?
                foreach my $indb (@setindb) {                   # open closed onhold, core docs patch, linux aix...
                    if ($line =~ /\b$type=$indb\b/i) {
                        $self->debug(0, "Bingo($type=$indb)");
						$data{$type} = lc($indb);               # :-)
                        $set{$type}++;
                        next TYPE;
                    }
                } 
            }
            # MATCHES?
			my @matches = $self->get_keys($type);               # SET from config file
            $self->debug(4, "matches(@matches)");
			if (@matches >= 1) {
                MATCH:
                foreach my $match (@matches) {                  # \bperl|perl\b, success\s*report, et
            		$self->debug(3, "type($type) <-> match($match)?");
                    if ($line =~ /$match/i) {                   # to what do we map?
                        if ($type eq 'version') {               # bodge for version
                            my $num = $1;                 
                            if ($num =~ /^\d+/) {
                                $self->debug(0, "Bingo: versnum($num)");
								$data{$type} = $num;			# :-)
                                $set{$type}++;
                                $self->debug(2, "YUP line($line) version ($num) -> next LINE");
                                next TYPE;
                            }               
                        } else {
							next MATCH unless $line =~ /=/;		# short circuit
                            my $target = $self->$type($match);  # open, closed, etc.
                            if (grep(/^$target/i, @setindb)) {  # do we have an assignation?
                                $self->debug(0, "Bingo: target($target)");
								$data{$type} = $target;			# :-)
                                $set{$type}++;
                                $self->debug(3, "YUP target($target) -> next LINE");
                                next TYPE;
                            }
                        }
                    }
                }
            }
			$self->debug(3, "Matches found anything? -> ".Dumper(\%set));
			
        }
        last LINE if keys %set >= 5; # found a match for each type      
    }
    my $reg = scalar keys %set;
    $self->debug(1, "Scanned($ok) count($i_cnt), registered($reg): ".$self->dump(\%data));  
	$self->debug('OUT', \%data);
    return \%data;
}


=item do_reply

Deal with a reply to an existing bug - no acknowledgement, no forward (quiet)

=cut

sub do_reply { # to existing bug
    my $self = shift;
    $self->debug('IN', @_);
    my $mail = shift || $self->_mail;
    my $bid  = $self->{'attr'}{'bugid'}; # yek
    my ($ok, $msg, $mid) = (1, '', '');
    if (!(ref($mail) and $self->ok($bid))) {
		$ok = 0;
		$self->debug(0, "requires a Mail::Internet($mail) and a bid($bid)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($mail);
    	my $from 	= $o_hdr->get('From');
    	my $subject = $o_hdr->get('Subject');
    	my $reply   = $o_hdr->get('Reply-To');
    	my $to      = $o_hdr->get('To');
		chomp($from, $subject, $reply, $to);
    	$self->debug(1, "REPLY: subject($subject), bid($bid), from($from), reply($reply), to($to)");
    	# Add it to the database
    	($mid) = $self->message_add($bid, { 
			'sourceaddr'	=> $from,
            'subject'   	=> $subject,
            'toaddr'    	=> $to,
			'msgheader'	 	=> $header,
            'msgbody'   	=> $body,
    	});
    	if ($mid =~ /\d+/) {
        	$self->{'attr'}{'bugid'} = $bid;
        	$msg = "mid($mid) ok";
			($ok, my @ccs) = $self->tm_bug_address($bid, $to, $o_hdr->get('Cc'));
    	} else {
        	$msg = 'reply failed to add message'; 
    	}
	}
	$self->debug('OUT', $mid);
    return $mid;
}


=item header2admin

Given a Mail::Header object attempts to return a valid create admin command

	my $data = $o_email->header2admin($o_hdr);

=cut

sub header2admin {
	my $self = shift;
    $self->debug('IN', @_);
    my $o_hdr = shift;
    my $data  = '';
	if (!ref($o_hdr)) {
		$self->debug(0, "registration requires a header object($o_hdr)");
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
		$self->debug(1, "Looking at registration request($user) from($from)");
		my ($o_from) = Mail::Address->parse($from);
		if (!ref($o_from)) {
			$self->debug(0, "Couldn't get an address object($o_from) from($from)");
		} else {
			my $address = $o_from->address;
			my $name 	= $o_from->name;
			chomp($address, $name); # probably uneccessary - paranoid now
			my $last  	= $name; $name =~ s/\s+/_/g;
			my $userid 	= $user || $o_from->user."_$$" || $last."_$$"; #
			my $pass 	= $userid; $pass =~ s/[aeiou]+/\*/gi;
			my $match 	= quotemeta($address);
			$data = "userid=$userid:\nname=$name:\npassword=$pass:\naddress=$address:\nmatch_address=$match\n"; 
			$self->debug(1, "data($data)");
		}
	}
	$self->debug('OUT', $data);
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
    $self->debug(2, "Cc emails registered: ".$self->{'attr'}{'cc'});
	return $self->{'attr'}{'cc'};
}


=item doy

New password

=cut

sub doy {  # new pass 
    my $self = shift;
    my $args = shift;
	$self->debug('IN', @_);
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : ($args);
	my $i_ok = 0;
    my $userid = $self->isadmin;
	($i_ok) = $self->SUPER::doy(["$userid @args"]);
	my $res = "new password(@args) request($i_ok)";
	$self->debug('OUT', $res);
	return $res;
}


=item dov

Volunteer proposed bug modifications

	propose_close_<bugid>@bugs.perl.org
	
	my $i_ok = $o_obj->dov('bid close patch');

=cut

sub dov { # volunteer propose new bug status/mods
	my $self = shift;
	$self->debug('IN', @_);
	my $args = shift;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	my $o_mail = $self->_mail;
	my $i_ok = 1;
	if (!ref($o_mail)) {
		$i_ok = 0;
		$self->debug(0, "bug proposal requires a Mail::Internet object($o_mail)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		my ($subject, $from, $replyto) = ($o_hdr->get('Subject'), $o_hdr->get('From'), $o_hdr->get('Reply-To'));
		chomp($subject, $from, $replyto);
		my $admin   = $self->system('maintainer');
		my @admins  = $self->active_admin_addresses;
		$self->debug(0, "perlbug proposal: @args");
		my $o_prop = $self->get_header($o_hdr);
		$o_prop->replace('To', $admin);
		$o_prop->replace('Cc', join(', ', @admins));
		$o_prop->replace('From', $self->from($replyto, $from));
		$o_prop->replace('Subject', $self->system('title')." proposal: $subject");
		$i_ok = $self->send_mail($o_prop, $body);
	}
	my $res = "Proposal request($i_ok)";
	$self->debug('OUT', $res);
	return $res;
}


=item doV

Volunteer a new administrator

	register_MYUSERID@bugs.perl.org

=cut

sub doV { # Propose new admin
	my $self = shift;
	$self->debug('IN', @_);
	my $args = shift;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	my $request = "New admin request -i[nitiate] (\n@args\n)\n";
	my $i_ok = 1;
    my $o_mail = $self->_mail; # hopefully 
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->debug(0, "admin volunteer requires a mail object($o_mail)");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		my $o_prop = $self->get_header($o_hdr, 'default');
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
	$self->debug('OUT', $res);
	return $res;
}


=item doa

admin a bug

	close_<bugid>_patch_macos@bugs.perl.org

=cut

sub doa { # admin a bug
	my $self = shift;
	$self->debug('IN', @_);
	my $args = shift;
	my @args = (ref($args) eq 'ARRAY') ? @{$args} : $args;
	@args = map { split(/[\s_]+/, $_) } @args;
	my @bids = ();
	my $i_cnt= 0;
	my $i_ok = 1;
	my $res  = '';
    my $o_mail = $self->_mail; # hopefully 
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->debug(0, "admin requires a mail object($o_mail)");
	} else {
		$res = $self->SUPER::doa($args, $o_mail);
	}
	$self->debug('OUT', $res);
	return $res;
}


=item doP

Recieve a patch

	patch_<version>*_<changeid>*_<bugid>*@bugs.perl.org

=cut

sub doP { # recieve a patch
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	my $args = shift;
	my $o_mail = $self->_mail; 
	my @bids = (); 
	my $res = '';
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->debug(0, "requires a mail object($o_mail) for patching");
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
	$self->debug('OUT', $res);
	return $res;
}


=item doT

Recieve a test

	test_<bugid>@bugs.perl.org

=cut

sub doT { # recieve a test
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	my $args = shift;
    my $o_mail = $self->_mail; 
	my $res = '';
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->debug(0, "requires a mail object($o_mail) for testing");
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
	$self->debug('OUT', $res);
	return $res;
}


=item doN

Recieve a note

	note_<bugid>*@bugs.perl.org

=cut

sub doN { # recieve a note
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	my $args = shift;
	my @args = @_; # have to ignore these
	my $o_mail = $self->_mail; 
	my @bids = (); 
	my $res  = '';
	if (!ref($o_mail)) {
    	$i_ok = 0;
		$self->debug(0, "requires a mail object($o_mail) for note");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		chomp(my $to = $o_hdr->get('To'));
		chomp(my $from = $o_hdr->get('From'));
		chomp(my $subject = $o_hdr->get('Subject'));
		$res = $self->SUPER::doN($args, $body, $header, $subject, $from, $to);
	}
	$self->debug('OUT', $res);
	return $res;
}


=item dow

Forward (weiterleiten) mail onto all active administrators

	admin(s)@bugs.perl.org

	my $i_ok = $o_obj->dow($body);

=cut

sub dow { # weiterleiten -> all active admins
	my $self = shift;
	$self->debug('IN', length($_[0]));
	# my $body = shift; # no point in carting it around? 		# -> 
	my $cmd    = shift;
	my $o_mail = shift || $self->_mail;
	my $i_ok = 1;
	if (!ref($o_mail)) {
		$i_ok = 0;
		$self->debug(0, "forwarding requires a Mail::Internet object($o_mail)");
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
	$self->debug('OUT', $i_ok);
	return ($i_ok);
}


=item do_quiet

Drop out quietly, no entry in database, silent dump into black hole.

=cut

sub do_quiet { # log this mail and do nothing else
    my $self = shift;
    $self->debug('IN', @_);
    my $mail = shift || $self->_mail;
    my ($o_hdr, $header, $body) = $self->splice($mail);
    my $i_ok = 1;
    # silent pass through
    if (1) {
        $self->debug(0, "QUIET ($mail, @_) logged(pass through), not in db:\n");
    }
	$self->debug('OUT', $i_ok);
    return $i_ok;
}


=item do_bounce

Deal with a bounced mail

=cut

sub do_bounce { # and place in db
    my $self    = shift;
    $self->debug('IN', @_);
    my $mail    = shift || $self->_mail;
    my ($reason)= @_;
    my ($o_hdr, $header, $body) = $self->splice($mail);
    chomp(my $from    = $o_hdr->get('From'));
    chomp(my $replyto = $o_hdr->get('Reply-To'));
    chomp(my $subject = $o_hdr->get('Subject'));
    chomp(my $to      = $o_hdr->get('To'));
    chomp(my $cc      = $o_hdr->get('Cc'));
    chomp(my $xloop   = $o_hdr->get('X-Perlbug'));
    #
    my ($ok, $bid, $mid) = (1, '', '');
    $self->debug(0, "BOUNCE: subject($subject) into db for posterity...");
    my $rebound = $from;
    if ($xloop =~ /\w+/) {
        $self->debug("X-Perlbug($xloop) not putting into DB: '$subject'");
        $rebound = $self->system('maintainer');
        $subject = "X-Perlbug: $subject";
    } else {
        # register bounced mails as new onhold notabug low priority bugs
        ($ok, $bid, $mid) = $self->insert_bug($subject, $from, $to,  $header,  $body);
        if ($ok == 1) {
            $self->{'attr'}{'bugid'} = $bid;
            $ok = $self->bug_set($bid, { 
                'status'    => 'closed',
                'severity'  => 'none',
                'category'  => 'bounce',
                'osname'    => '',
            });  
            # my $x = $self->track('t', $bid, "closed:none:bounce");
        }
        if ($ok == 1) {
			($ok, my @ccs) = $self->tm_bug_address($bid, $o_hdr->get('To'), $o_hdr->get('Cc'));
		}
		my ($title, $tron, $hint) = ($self->system('title'), $self->email('tron'), $self->email('hint'));
        $body = qq|
    This email address is for reporting $title bugs via $tron.
    
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
	$self->debug('OUT', $ok);
    return $ok;
}


=item assign_bugs

Assign to this admin, so many, of these unclaimed bugs.

N.B. the claimed bugs are shifted off the end of the referenced array!

    $ok = $pb->assign_bugs($admin, 5, \@unclaimed);

=cut

sub assign_bugs { # unclaimed to admins
    my $self    = shift;
    $self->debug('IN', @_);
    my $admin   = shift;
    my $num     = shift;
    my $a_unclaimed = shift;
    my $ok = 1;
    
    if (($admin =~ /\w+/) && ($num =~ /^\d+$/) && (ref($a_unclaimed) eq 'ARRAY') && (@{$a_unclaimed} >= 1)) {
        $self->debug(2, "assign_bugs($admin, $num, $a_unclaimed) args OK");
    } else {
        $ok = 0;
        $self->debug(0, "Duff args given to assign_bugs: admin($admin), num($num), a_unclaimed($a_unclaimed)");
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
            $self->debug(2, "Admin($admin), claimed bug($bug)");
        }
    }

    if ($ok == 1) {
        push(@res, $self->doo);
	}

    # DATA + overview 
    my $data = '';
    if ($ok == 123) {
        $self->doo;
        # my ($a_results) = $self->get_results;
        # my @results = $self->get_results;
        # $data = (ref($a_results) eq 'ARRAY') ? join('', @{$a_results}) : $a_results;
        my $fh = $self->fh('res'); # REWIND results to zero HERE.
        flock $fh, 2;
        truncate $fh, 0;
        flock $fh, 8;
    }
     
    # SEND MAIL
    if ($ok == 1) {
        my ($address) = $self->get_list("SELECT address FROM tm_user WHERE userid = '$admin'");
		my $data = join('', @res);
        my $o_hdr = $self->get_header;
		$o_hdr->add('To' => $address);
        $o_hdr->add('Subject' => $self->system('title').' admin sheet (@bids)');
        $ok = $self->send_mail($o_hdr, "$notice\nBUGIDs: (@bids)\n\n$data\n\n");
    }
	$self->debug('OUT', $ok);     
    return $ok;
}   # done assign_bugs



=item doD

Mail me a copy of the latest database dump, with 8-figure time filter

=cut

sub doD { # mail database dump
	my $self = shift;
	$self->debug('IN', @_);
	my $args = shift;
    my $date = (ref($args) eq 'ARRAY') ? join(' ', @{$args}[0]) : $args;
	my $i_ok = 1;
	my $file = $self->directory('arch').'/'.$self->database('latest');
	if ($date !~ /^\s*(\d+)\s*$/) { # incremental
		$self->debug(2, "Full database dump requested($args -> $date)");
	} else {	
		$date = $1;
		$file = File::Spec->canonpath($self->directory('arch')."/Perlbug.sql.${date}.gz");
		$i_ok = $self->SUPER::doD($date);
		if ($i_ok != 1) {
			$self->debug(0, "Database dump($file) request($date) failed to complete($i_ok)!");
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
			$self->debug(2, "doD cmd($cmd)");
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
				$self->debug(0, "doD cmd($cmd) failed($i_ok) $!");
			} 
		}
	}
	$self->debug(2, "doD i_ok($i_ok)");
	$self->debug('OUT', $i_ok);
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
    $self->debug('IN', @_);
	my $o_hdr = shift; 	# close_<bugid>_install | register | ...
	my $body  = shift;
	my $cmd   = ''; 	# 
	my $str = '';
	if (!ref($o_hdr)) {
		$body = '';
		$self->debug(0, "scan_header requires a Mail::Header object($o_hdr)");
	} else {
		my $oldstyle = quotemeta($self->email('bugdb'));
		my $newstyle = quotemeta($self->email('domain'));
		my ($to, $from, $subject) = ($o_hdr->get('To'), $o_hdr->get('From'), $o_hdr->get('Subject'));
		my @cc = $o_hdr->get('Cc');
		chomp($to, $from, $subject, @cc);
		$self->debug(1, "to($to), subject($subject), from($from), cc(@cc)");
		# STR
		ADDR:
		foreach my $addr ($to, @cc) { # whoops, forgot the cc's
			next ADDR unless $addr =~ /\w+/;
			if ($addr =~ /^(.+)\@$newstyle$/i) { # *@bugs.perl.org
				$str = $1;
				last ADDR;
				$self->debug(1, "using addr($addr) -> cmd($cmd)");
			} elsif ($addr =~ /^$oldstyle$/) {
				$str = $subject;
				last ADDR;
				$self->debug(1, "address($addr) using subject -> cmd($cmd)");
			}
		}
		if ($str !~ /\w+/) { 	# ek?
			$self->debug(1, "no valid string($str) found for cmd($cmd)!")
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
			} elsif ($str =~ /^overv/i) {	# overview
				$cmd = 'o';											# doo
			} elsif ($str =~ /^(faq|adminfaq|help|spec|info|$origin)/i) {		# !!!	  
				$cmd = 'h';											# doh
			} elsif ($str =~ /^patch_/i) {  # patch/change/fix      # ONLY IF IT _STARTS_ with ^patch...
				$cmd = "P $str";									# doP
			} elsif ($str =~ /^test_/i) {  # test/change/fix        # ONLY IF IT _STARTS_ with ^test...
				$cmd = "T $str";									# doT
			} else {						# admin/proposal/note => bugid
				$cmd = ($str =~ /^propos\w+/i) ? 'v' : 'a'; 		# dov | doa | note
				my ($isok, $bid) = $self->get_id($str);
				if (!($isok == 1 || $bid =~ /\d+/)) { 				# try again
					($isok, $bid) = $self->get_id($subject); 		# ?
					$str .= "_$bid" if $isok;
				}
				if ($isok == 1 && $bid =~ /\d+/) {
					if ($str =~ /^note/i) {							# doN (body)
						$cmd = "N $bid";
					} else {
						$cmd = "$cmd $str";
					}
				} else {
					$self->debug(0, "Failed($isok) to identify($cmd) bugid($bid) in string($str), referring to admins");
					$cmd = "v $str"; # refer to admins				# dov
				}
			}
			$self->debug(1, "cmd($cmd)");
		}
	}
	if ($cmd !~ /\w+/) {
		$self->debug(0, "no cmd($cmd) found from str($str) return 'H' instead");
		$cmd = 'H';
	}
	$self->debug('OUT', $cmd, length($body));
	return ($cmd, $body);	
}


=item admin_of_bug

Checks given bugid and administrator against tm_user_bug, tm_bugs::sourceaddr, tm_bug_address.

Now you can admin a bug if you're on the source address, or the Cc: list.

=cut

sub admin_of_bug {
    my $self  = shift;
	$self->debug('IN', @_);
	my $bid   = shift || '';
	my $admin = shift || $self->isadmin;
	chomp($admin);
	my $i_ok  = $self->SUPER::admin_of_bug($bid, $admin);	# tm_user_bug::admin
	if ($i_ok != 1) { 				# try again with address
		my ($o_hdr, $header, $body) = $self->splice; # !
		my ($from) = $o_hdr->get('From');
		my ($o_addr) = Mail::Address->parse($from);
		if (!ref($o_addr)) {
			$i_ok = 0;
			$self->debug(0, "Can't get address object($o_addr) from ($from)");
		} else { 												# tm_bug_address::address
			my ($addr) = $o_addr->address;
			chomp($addr);
			my $sql   = "SELECT DISTINCT bugid FROM tm_bug_address WHERE UPPER(address) = UPPER('$addr') AND bugid = '$bid'";
    		my ($tkt) = $self->get_list($sql);
			if (defined($tkt) and $tkt eq $bid) { 	# try again with source
				$i_ok = 1;
				$self->debug(1, "Found: bid($bid) eq tm_bug_address_tkt($tkt)");
			} else { 											# tm_bug::sourceaddr
				$sql  = "SELECT sourceaddr FROM tm_bug WHERE bugid = '$bid'";
				my ($src) = $self->get_list($sql) ;
				my ($o_addr) = Mail::Address->parse($src);
				if (ref($o_addr)) {
					my $source = $o_addr->address;
					if (defined($source) and $source eq $addr) {
						$i_ok = 1;
						$self->debug(1, "Found: address($addr) eq src($source)");
					} else {
						$i_ok = 0;
						$self->debug(1, "NOT found: address($addr) ne src($source)");
					}
				}
			}
		}
	}
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item administration_failure

Deal with a failed administration attempt

	my $i_ok = $self->administration_failure($bid, $user, $commands);

=cut

sub administration_failure {
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = $self->SUPER::administration_failure(@_);
	my $bid  = shift;
	my $cmds = shift;
	my $user = shift || $self->isadmin;
	my $reason = shift || '';
	my ($o_hdr, $header, $body) = $self->splice; # !
	my $o_note = $self->get_header($o_hdr);
	$o_note->replace('To', $self->system('maintainer')); 
	$o_note->replace('Subject', $self->system('title')." administration FAILURE: $cmds");
	$o_note->delete('Cc');
	# $o_note->replace('Cc', join(', ', $self->active_admin_addresses));
	#
	$i_ok = $self->send_mail($o_note, $body);
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item in_master_list

Checks given address against ok-to-be-administrator email address list

	my $i_ok = $o_obj->in_master_list($address);

=cut

sub in_master_list {
	my $self = shift;
	$self->debug('IN', @_);
	my $addr = shift;
	chomp($addr);
	my $i_ok = 0;
	my ($o_addr) = Mail::Address->parse($addr);
	if (!ref($o_addr)) {
		$self->debug(0, "address($addr) nor parseable($o_addr)");
	} else {
		$addr = $o_addr->address;
		my $list = $self->directory('config').$self->system('separator').$self->email('master_list');
		my @list = @{$self->{'o_log'}->read($list)};
		my $found = grep(/^$addr$/i, @list);
   		$i_ok = ($found >= 1) ? 1 : 0;
		$self->debug(0, "found($found) addr($addr) in list(".@list.")");
	}
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 1999 2000

=cut

# 
1;

sub _switch { # 
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	my $switch = 'ignore'; # | target | reply | interface
	my $o_mail = shift || $self->_mail; # Mail::Internet->new(*STDIN);
    if (!ref($o_mail)) {
		$i_ok = 0;
		$self->debug(0, "requires Mail::Internet($o_mail) for decision");
	} else {
		my ($o_hdr, $header, $body) = $self->splice($o_mail);
		my $to = $o_hdr->get('To');
		chomp($to);
		
	}
	$self->debug('OUT', $i_ok);
	return $i_ok; 	
}


sub reminder { # open/fatal to relevant parties...
    my $self    = shift;
    $self->debug('IN', @_);
    my $bid     = shift;
	my @addrs   = @_;
    my $ok = 1;
    
    if (!(($bid =~ /^\d{8}\.\d{3}$/) && (scalar(@addrs) >= 1))) {
        $ok = 0;
        $self->debug(0, "Duff args given to reminder: bid($bid), addrs(@addrs)");
    } 
     
    my $o_bug = $self->object('bug')->read($bid);
	my $o_usr = $self->object('user');
    my $o_grp = $self->object('group');
    my ($title, $perlbug, $maintainer, $home) = 
		($self->system('title'), $self->email('perlbug'), $self->system('maintainer'), $self->web('hard_wired_url'));
	my $status = $o_bug->data('status');
    my $group = $o_bug->data('category');
	my $gid = $o_grp->name2id($group);

    # DATA + overview 
    my $bugreport = '';
    if ($ok == 1) {
		($bugreport) = $self->dob([$bid]);
        # my ($a_results) = $self->get_results;
        # $bugreport = (ref($a_results) eq 'ARRAY') ? join('', @{$a_results}) : $a_results;
	}
	
	if ($ok == 1) {
        my $fh = $self->fh('res'); # REWIND results to zero HERE.
        flock $fh, 2;
        truncate $fh, 0;
        flock $fh, 8;
    }
     
    # NOTICE
    if ($ok == 1) {
        my $notice = qq|
	This is a $title status($status) reminder for an outstanding 
	bug, a report for which is appended at the base of this email.

	Data relating to this bug ($bid) itself may be found at:

		$home/perlbug.cgi?req=bidmids&bidmids=$bid

	The group($group) responsible for this bug:

		$home/perlbug.cgi?req=gid&gid=$gid
    
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
        $ok = $self->send_mail($o_hdr, "$notice");
    }
	$self->debug('OUT', $ok);     

    return $ok;
}   # done reminder


__END__

sub stub { # 
	my $self = shift;
	$self->debug('IN', @_);
	my $i_ok = 1;
	# 
	# ...
	# 
	$self->debug('OUT', $i_ok);
	return $i_ok; 	
}
