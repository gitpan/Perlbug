# $Id: Fix.pm,v 1.38 2001/12/05 20:58:37 richardf Exp $ 
# 	

=head1 NAME

Perlbug::Fix - Command line interface to fixing perlbug database.

=cut

package Perlbug::Fix;
use strict;
use vars qw($VERSION @ISA);
$VERSION = do { my @r = (q$Revision: 1.38 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
$|=1;

use Data::Dumper;
use Perlbug::Interface::Cmd;
@ISA = qw(Perlbug::Interface::Cmd);

my %ARG = (
    "h" => '', "t" => 0, 'd' => 0, 'p' => '', 'u' => '', 'v' => 0,
);

=head1 DESCRIPTION

Command line interface to fixing incorrect perlbug data.

Most calls take an integer as the maximimum number of records to process, or default to a relatively low value.


=head1 SYNOPSIS

	use Perlbug::Fix;

	my $o_fix = Perlbug::Fix->new();

	$o_fix->cmd; # loop


=head1 USAGE 

  	lowercase is indicator/report 
	
	UPPERcase expands/effects
	
	> h		# help [with args]
	
	> H		# Helpful help

	> k 125	# set Perlbug_Max (number of records to fix) to 125

	> s		# scan for correctable relationships

	> S 200108%	# implement corrections for August registered bugs

	> 		# etc.


=head1 METHODS

=over 4

=item new

Create new Perlbug::Fix object:

    my $o_fix = Perlbug::Fix->new();

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto; 
    my $arg   = shift;
    my $self = Perlbug::Interface::Cmd->new(@_);

    bless($self, $class);
}

my $FIX = 0;
my $MAX = $ENV{'Perlbug_Max'} || 33;
my %MAP = ( # a=pb_address bu=pb_bug_user l=pb_log...
	'a' 	=> 'address      [bugid%]',		'ah' 	=> 'trawls for in/valid addresses - see also "r (bug|group) address"',
	'b' 	=> 'scan_body    [bugid%]',    	'bh' 	=> 'scan bug bodies (see <s>)',
	'c'		=> 'change       [filename',  	'ch'	=> 'trawls given file for bugid=>patchid=>changid relations',
	'd'		=> 'discard      [bugid%]',		'dh'	=> 'discard duplicates or redundant data, see also r=relations',
#	'e' 	=> 'forward      [bugid%]',		'wh' 	=> 'forward non-forwarded mails',
	'f'		=> 'trim_flags   [flag%]',		'fh'	=> 'trim flags where dupes',
	'h' 	=> 'help         []',			'hh' 	=> 'more detailed help',
	'i' 	=> 'scan_ids     [bugid%]',		'ih' 	=> 'trawls for email Message-Ids', 
	'k' 	=> 'kick         [Perlbug_Max]','kh' 	=> 'kick Perlbug_Max value to n',
    'l' 	=> 'ubl          [userid%]',	'lh'	=> 'updates user_bug table via log entries',
	'm'		=> 'message      [messageid%]',	'mh'	=> 'message fix for subject lines',
	'q' 	=> 'doq          [sql]',    	'qh' 	=> 'query the database (Q for the schema)',
	'r'		=> 'references   [bugid%]',		'rh'	=> 'deletes non-existent pb_\w_\w references, see also d=discard',
	's' 	=> 'scan_header  [bugid%]',    	'sh' 	=> 'scan bug headers (see <b>)',
#	't' 	=> 'tables       [primaryid%]',	'th' 	=> 'tidy all tables created=SYSDATE(), etc.',
	'u' 	=> 'users        [userid%]',	'uh' 	=> 'de-activate non-valid users',
	'x'		=> 'execute      [sql]',		'xh'	=> 'xecute sql on db!', # only if bugmaster
	'w'		=> 'wrapper      [Perlbug_Max]','wh'	=> 'wrap all calls(@WRAP) - takes quite a looong time...',
#	'v'		=> 'version      [bugid%]',     'vh'    => 'version specific scanning',
	'z'		=> 'header_body  [bugid%]',	 	'zh'	=> 'migrate headers and body across to bug from original mail',
);

my @WRAP = qw(z i d m f s a c u l); 

sub wrapper { # w 
	my $self = shift;
	foreach my $w (@WRAP) {
		my $W = uc($w);
		print "Wrapping $w($W) of wrap(@WRAP) -> \n";
		$self->process($w, @_);
		print "... done wrapping $w($W)       <-\n";
	}
	# return "Unsupported: try calling(@wrap)\n";
}

sub output { print @_; }
	
sub quit { print "Bye bye!\n"; exit; }

sub help { # h 
	my $self = shift;
	my $i_ok = 1;
	my $help = qq|Fix help:\nlowercase reports, UPPERCASE eFFects it!
ENV{Perlbug_Max} (currently $MAX) may be set for loop control.
Most commands accept an argument, a bugid or something, as indicated.
Modification feedback takes the form of, where object_type is uppercase
where the database was actually changed:

	[i_seen] <i_fixed> object_type(object_id): modification_feedback

|;
	foreach my $k (sort keys %MAP) {
		next if $k =~ /^\w+h$/o;
		my $hint = "${k}h";
		$help .= ($FIX == 1) ? "$k = $MAP{$hint}\n" : "$k = $MAP{$k}\n";
	}
	return $help;
}

sub doq { # q rewrapper :-\
	my $self = shift;
	my @args = @_;
	my $sql = join(' ', @args);
	my $query = ($FIX == 1) ? 'SUPER::doQ' : 'SUPER::doq';
	return $self->$query($sql);
}



=item kick

Kick Perlbug_Max value ...

=cut

sub kick { # k 
	my $self = shift;
	my $newval = shift;
	
	my $ret = "Perlbug_Max($newval) must be a digit!\n";	

	if ($newval =~ /^\d+$/o) {
		$MAX = $newval;
		$ret = "set Perlbug_Max($MAX)\n";	
	}

	return $ret;
}


=item process

Processes the command given, gets and truncates the results, calls scroll

This could be redundant ? -> Cmd::process()

=cut

sub process { 
	my $self = shift;
	my $orig = shift;

	my @res  = ();
	my $targ = lc($orig);
	my ($call, @args) = split(/\s+/, $orig);

    # print "fix: $orig -> call($call) args(@args)\n";	
	if ($call !~ /^\w+$/) {
		print "didn't understand orig($orig), call($call), args(@args)\n";
	} else { 
		$FIX++ if $call =~ /^[A-Z]+$/o;
		my $meth = $MAP{lc($call)};
		$meth =~ s/^(\w+)\s+.+$/$1/;
		if (!$self->can($meth)) {
			$self->error("unsupported call($call) meth($meth)");
		} else {
			# print "fix($FIX) max($MAX) call($meth) args(@args)\n";
			@res = $self->$meth(@args);
		}
		$FIX=0;
	}
	if (!(scalar(@res) >= 1)) { 
		@res = ("Command($orig) failed to produce any results(@res) - try 'h'\n");
	} else {
		$self->scroll(@res);
	}

	return @res;
}


sub address { # a
	my $self = shift;
	my $addr = shift || '';
	return $self->references('bug', 'address', $addr);
}


=item references

Delete duff references in bug_\w+_\w+ tables by given arg

Or, if two args given appropriate relationship:

	r patch # bug->patch understood

	r patch version # patch->version

=cut

sub references { # r 
	my $self = shift;
	my $src  = shift;
	my $tgt  = shift || '';
	my $attr = shift || '_%';

	($src, $tgt) = ('bug', $src) unless $tgt =~ /\w+/o;

	my $ret = '';

	if (!($src =~ /^\w+$/o && $tgt =~ /^\w+$/o)) {
		print "references requires a source($src) and target($tgt) attr($attr)"; 
	} else {
		print "fixing($FIX) src($src) tgt($tgt) attr($attr)\n";
		my $o_src = $self->object($src);
		my $o_tgt = $self->object($tgt);
		my $o_rel = $o_src->rel($tgt);
		my $srcpkey  = $o_src->attr('primary_key');
		my $srctable = $o_src->attr('table');
		my $reftable = $o_rel->attr('table');

		if ($src eq 'bug' && $tgt eq 'address') {
			$ret = $self->src_address($src, $tgt, $o_rel, $attr);	
		} else {
			print "fixing($FIX) src($src) tgt($tgt) with $srcpkey($srctable) and ref($reftable)\n";
			my @ok = $self->get_list("SELECT $srcpkey FROM $srctable");
			my $ok = join('|', @ok);
			my @targs = $self->get_list("SELECT DISTINCT $srcpkey FROM $reftable WHERE $srcpkey LIKE '$attr'");
			my @notok = ();
			foreach my $targ (sort @targs) {
				push(@notok) unless grep(/^$targ$/, @ok);
			}
			print "ok(".@ok."), notok(".@notok.")\n";

			$#notok = $MAX - 1 if @notok > $MAX;
			my $notok = join("', '", @notok);
			print "ok($ok), notok($notok)\n";
			
			my $rows = 0;
			if (!(scalar(@notok) >= 1)) {
				print "nothing to do (@notok)\n";
			} else {
				if (!$FIX) {
					print "$reftable has ".@notok." non-existent $src -> $tgt references($notok)\n";
				} else {
					my $sql = "DELETE FROM $reftable WHERE $srcpkey IN ('$notok')";
					my $sth = $self->exec($sql);
					print "$reftable delete success\n" if $sth;
				}		
			}
		}
	}

	return $ret;
}


=item src_address 

Correct db_SRC_table where SRC may be<bug>|group

=cut

sub src_address { # address
	my $self = shift;
	my $src 	= shift;
	my $tgt 	= shift; 
	my $o_rel 	= shift;
	my $attr    = shift || '_%';

	my $reftable= $o_rel->attr('table');

	my $ret = '';

	my $o_bug = $self->object('bug');
	my $o_msg = $self->object('message');
	my $o_addr = $self->object('address');
	my $a_table = $o_addr->attr('table');
	my $m_table = $o_msg->attr('table');
	my $ba_table = $o_bug->rel('address')->attr('table');
	my $bm_table = $o_bug->rel('message')->attr('table');

	my @ok = $o_rel->source->ids($o_rel->source->primary_key." LIKE '$attr'");
	print "fixing($FIX) src($src) tgt($tgt) via rel($reftable) ".@ok." attr($attr) potentials...\n";

	my $cnt = 0;
	my $i_t = 0;
	my $fnd = 0;
	my $dodgy = $self->dodgy_addresses('from');
	BID:
	foreach my $id (@ok) { 				# EACH
		next BID if $o_rel->source->key eq 'bug' && $id eq '19870502.007';
		$i_t++;
		$o_rel->source->read($id);
		my @exists = $self->get_list("SELECT DISTINCT a.name FROM $a_table a, $ba_table b WHERE b.bugid = '$id' AND a.addressid = b.addressid");
		my $exists = join('|', @exists, $dodgy);
		my @mids   = $self->get_list("SELECT messageid FROM $bm_table WHERE bugid = '$id'"); 
		MID:
		foreach my $mid (@mids) { 		# AND EVERY
			my ($header) = $self->get_list("SELECT header FROM $m_table WHERE messageid = '$mid' AND header LIKE '%Cc:%'");
			$header = '' unless $header;
			next MID unless $header =~ /\w+/o;
			# my $o_hdr = $o_email->header2hdr($header);
			my @lines = split("\n", $header);
			my @cc = map { /^Cc:\s*(.+)\s*$/ } grep(/^Cc:/, @lines);
			my @o_ccs = Mail::Address->parse(@cc);
			my @addrs = ();
			CC: 
			foreach my $o_cc (@o_ccs) {
				next CC unless ref($o_cc);
				# my ($addr) = $o_cc->address;
				my ($addr) = $o_cc->format;
				push (@addrs, $addr) if ($addr =~ /\w+/o and $addr !~ /$exists/i and $addr =~ /\@/o);
			}
			if (!(scalar(@addrs) >= 1)) {	# ONE
				print "$i_t($id->$mid) looks ok missing(".@addrs.")\n";
			} else {
				$fnd++;
				my $s = (@addrs > 1) ? 's' : '';
				if (!$FIX) {
					print "$i_t($id->$mid) missing(".@addrs.") reference$s(@addrs)\n";
				} else {
					$o_rel->_assign(\@addrs);
					$cnt += 1 if $o_rel->ASSIGNED;
					print "$i_t($id->$mid <$cnt> fixed(".@addrs.") reference$s(@addrs)\n";
					last BID if $fnd >= $MAX;
				}
			} 
		}
		last BID if $fnd >= $MAX;
	} 
	print ($fnd >= 1) ? "fixed $cnt $reftable records\n" : ".\n";

	return $ret;
}


=item change

Correct bug_patch, bug_change, bug_patch, patch_change tables via given file

Example file contents:

	____________________________________________________________________________
	[  7012] By: nick                                  on 2000/09/02  17:25:20
			Log: More %{} and other deref special casing - do not pass to 'nomethod'.
		 Branch: perl
			   ! gv.c lib/overload.pm    
	____________________________________________________________________________
	[  7001] By: jhi                                   on 2000/09/01  23:00:13
			Log: Subject: [PATCH: 6996] minimal removal of 8 bit chrs from perlebcdic.pod
				 From: Peter Prymmer <pvhp@forte.com>
				 Date: Fri, 1 Sep 2000 15:50:57 -0700 (PDT)
				 Message-ID: <Pine.OSF.4.10.10009011542550.147696-100000@aspara.forte.com>

				 plus rework the http: spots as suggested by Tom Christiansen,
				 plus regen perltoc.
		 Branch: perl
			   ! README.os2 pod/perl56delta.pod pod/perlebcdic.pod
			   ! pod/perlguts.pod pod/perltoc.pod pod/perlxs.pod
	____________________________________________________________________________  

	[  6921] By: jhi                                   on 2000/08/30  19:40:16
			Log: Subject: [ID 20000830.036] [DOC] chom?p %hash not documented
				 From: Rick Delaney <rick@consumercontact.com>
				 Date: Wed, 30 Aug 2000 15:36:55 -0400 (EDT)
				 Message-Id: <Pine.UW2.4.10.10008301535210.1949-100000@consumer>
		 Branch: perl
			   ! pod/perlfunc.pod
	____________________________________________________________________________ 

=cut

sub change { # c 
	my $self = shift;
	my $file 	= shift || './Changes';

	my $i_max	= $MAX;
	my $ret     = '';

	my $o_bug = $self->object('bug');
	my $bc_table = $o_bug->rel('change')->attr('table');
	print "fixing($FIX) $bc_table file($file) max($i_max)\n";

	my ($i_cnt, $i_fnd, $i_nindb, $i_rec) = (0, 0, 0, 0);
	my $o_bug = $self->object('bug');
	my @bids = $o_bug->ids;
	
	if (!(-f $file && -r _)) {
		print "no Changes file($file) given or not readable: $!\n";
	} else {
		my $FH = FileHandle->new($file);
		if (!defined($FH)) {
			print "Can't open file($file): $!\n";
		} else {
			my ($bid, $body, $cid, $hdr, $msgid) = ('', '', '', '', '', '');
			my ($inarec, $inalog, $inabranch) = (0, 0, 0);
			my ($brnch, $notarec, $rec) = ('', '', '');
			LINE:
			foreach my $line (<$FH>) {
				chomp($line);
				# print "looking at line($line)\n" if $line =~ /subject/i;
				last LINE if $i_rec >= $i_max;
				next LINE unless $line =~ /\w+/o;
				if ($line =~ /^\[\s*(\d+)\]/o) {
					$cid = $1;
					$inarec++;
					$i_rec++;
					# print "found start: cid($cid), inarec($inarec), i_rec($i_rec)\n";
				}
				$inalog++    if $line =~ /Log: /o;
				$inabranch++ if $line =~ /Branch: /o;
				if (!$inarec) {
					$notarec  .= $line;
					# print "notarec($inarec)\n";
				} else {
					if ($inalog) {
						# $bid   = $1 if $line =~ /Subject:.*?\D*(\d{8}\.\d{3})\D*/;
						$bid   = $1 if $line =~ /Subject:.+?(\d{8}\.\d{3})/o;
						$msgid = $1 if $line =~ /Message-Id:\s*(\S+)\s*$/o;
						$hdr  .= $line if $line =~ /^\s+[\w-]+:\s*/o;
						$body .= $line if $line !~ /^\s+[\w-]+:\s*/;
						# print "inalog: cid($cid) bid($bid) at current line($line)\n" if $line =~ /subject/i;
					} elsif ($inabranch) {
						$brnch.= $line;
						# print "inabranch($inabranch)\n";
					} else {
						$rec  .= $line;
						# print "undecided\n";
					}
				}	
				if ($line =~ /^__+\s*$/o) { # end of rec
					# print "end of rec\n";
					if (!($bid =~ /\w+/o && $cid =~ /\w+/o)) {
						# print "failed to find bid($bid) and cid($cid)\n";
					} else {
						# print "found bid($bid), cid($cid)\n";
						if (!(grep(/^$bid$/, @bids))) {
							# print "bid($bid) not in db, nothing to tag against\n";
						} else {
							$i_fnd++;
							# print "bid($bid) IN db, tagging($i_fnd) cid($cid)\n";
							my $check = "SELECT COUNT(*) FROM $bc_table WHERE bugid='$bid' AND changeid='$cid'";
							my ($in_db) = $self->get_list($check);
							if (!$in_db) {
								$i_nindb++;
								if ($FIX) {
									my $insert = "INSERT INTO $bc_table SET created=SYSDATE(), modified=SYSDATE(), bugid='$bid', changeid='$cid'";
									my $sth = $self->exec($insert);
									print "[$i_cnt]: inserted bid($bid), cid($cid)\n" if $sth;
									last LINE if $i_nindb >= $MAX;
								}
							} else {
								# print "combo already in db($in_db)\n";
							}
						}
					} 
					($bid, $body, $cid, $hdr, $msgid) = ('', '', '', '', '', '');
					($inarec, $inalog, $inabranch) = (0, 0, 0);
					($brnch, $notarec, $rec) = ('', '');
				}
			}
			$FH->close;
		}
	}
	print "Looked at($i_rec) records, found($i_fnd) notindb($i_nindb) and inserted($i_cnt)\n";

	return $ret;
}


=item message 

Fix message subject lines where empty

=cut

sub message { # m 
	my $self = shift;
	my $msgid = shift || '';
	my $ret = '';

	my $o_bug = $self->object('bug');
	my $o_msg = $self->object('message');
	my $table = $o_msg->attr('table');

	my $where = ($msgid =~ /\w+/o) ? "messageid LIKE '$msgid'" : '';
	print "fixing($FIX) $table($where)\n";

	my $i_mids = my @mids = $o_msg->ids($where);
	if (@mids == 0) {
		print "no mids found(@mids)\n";
	} else {
		my ($i_cnt, $i_req, $i_fnd, $i_fxd) = (0, 0, 0, 0);
		my @fixable = ();
		MID:
		foreach my $mid (@mids) {
			last MID if $i_fnd >= $MAX;
			$i_cnt++;
			print "[$i_cnt] $mid ";
			my $subject = $o_msg->read($mid)->data('subject');
			if ($subject !~ /\w+/) {
				$i_req++;
				print "! ";
				my $header = $o_msg->data('header');
				if ($header =~ /Subject:\s*([^\n]+)\n/msio) {
					$subject = $1;
					$i_fnd++;
					print "$i_fnd ($subject)";
					if ($FIX) {
						my ($qsubj) = $o_msg->base->db->quote($subject);
						$o_msg->update({'subject' => $subject});
						$i_fxd++;
						print ':-) ';
					}
				}
			}
			print "\n";
		}
		print "mids($i_mids), seen($i_cnt), fixable($i_req), found($i_fnd), fixed($i_fxd)\n";
	}	

	return $ret;
}


=item header_body 

Migrate headers and body from original bug

=cut

sub header_body { # z
	my $self = shift;
	my $bugid= shift || '';
	my $and  = ($bugid =~ /\w+/o) ? "AND bugid LIKE '$bugid'" : '';
	my $ret  = ();

	my $fix = 'header_body';
	my $sql = "(header = '' OR body = '') $and";
	print "fixing($FIX) $fix($sql)\n";

	my $o_bug = $self->object('bug');
	my $o_msg = $self->object('message');

	my $i_bids = my @bids = $o_bug->ids($sql);
	if (@bids == 0) {
		print "no bids found(@bids)\n";
	} else {
		my $fix_bugid = '19870502.007';
		my ($i_cnt, $i_req, $i_fnd, $i_fxd) = (0, 0, 0, 0);
		my @fixable = ();
		BID:
		foreach my $bid (@bids) {
			last BID if $i_fnd >= $MAX;
			next BID unless $o_bug->ok_ids([$bid]); 
			$i_cnt++;
			print "[$i_cnt] $bid ";
			my ($header, $body) = ($o_bug->read($bid)->data('header'), $o_bug->data('body'));
			print "header(".length($header).") body(".length($body).") ";
			if ($header !~ /\w+/ && $body !~ /\w+/) { # ferret...
				my @mids = $o_bug->rel_ids('message');
				my ($mid) = my @sorted = sort { $a <=> $b } @mids; # the first one
				print "-> mid($mid) of ".@mids." from($sorted[0]) to($sorted[$#sorted])\n" ;
				if ($mid =~ /^\d+$/o) {
					$i_req++;
					print "\t* ";
					$o_msg->read($mid);
					my ($hdr, $bdy) = ($o_msg->data('header'), $o_msg->data('body'));
					if ($hdr.$bdy !~ /\w+/) {
						print "no info found header($header) or body($body)\n";
					} else {
						if (length($bdy) >= 35000) {
							print "body length(".length($bdy).") excessive!\n";
							next BID;
						} else {
							$i_fnd++;
							print "-> fnd($i_fnd) lengths: header(".length($hdr)."), body(".length($bdy).") ";
							if ($FIX) {
								$o_bug->data({ 'header' => $hdr, 'body'	=> $bdy, });
								$o_bug->update($o_bug->_oref('data'));
								my $o_msg = $o_bug->rel('message');
								$o_msg->set_source($o_bug);
								$o_msg->delete([$mid]);
								$o_msg->assign([$fix_bugid]);
								# $o_msg->delete([$mid]);
								$i_fxd++;
								print ':-) ';
							}
						}
					}
				}
			}
			print "\n";
		}
		print "bids($i_bids), seen($i_cnt), fixable($i_req), found($i_fnd), fixed($i_fxd)\n";
	}	

	return $ret;
}

sub _log {
	my $self = shift;
	my @args = @_;
	my $ret = '';

	my $o_log = $self->object('log');
	my $table = $o_log->attr('table');
	print "fixing($FIX) $table\n";

	if ($FIX) {
		my $sql = "UPDATE $table SET entry = 'trimmed'";
		my $sth = $self->exec($sql);
		print "modified($sql) over enthusiastic log entries\n" if $sth;
	}

	return $ret;
}


=item users

Correct users table, currently only looks for blank passwords

=cut

sub users { # u 
	my $self = shift;
	my $user = shift || '';
	my $and  = ($user =~ /\w+/o) ? "AND userid LIKE '$user'" : '';

	my $ret  = '';

	my $o_usr = $self->object('user');
	my $table = $o_usr->attr('table');
	print "fixing($FIX) $table($and)\n";
	
	my @ok = $self->get_list("SELECT DISTINCT userid FROM $table WHERE userid IS NOT NULL $and");
	my $ok = join('|', @ok);
	my @targs = $self->get_list("SELECT DISTINCT userid FROM $table WHERE password = '' $and");
	my @notok = map { grep(!/^($ok)$/, $_) } @targs;
	
	print "ok(".@ok."), notok(".@notok.")\n";

	$#notok = $MAX - 1 if @notok > $MAX;
	my $notok = join("', '", @notok);
	
	my $rows = 0;
	if (scalar(@notok) >= 1) {
		if ($FIX) {
			my $sql = "UPDATE $table SET active = NULL WHERE userid IN ('$notok')";
			my $sth = $self->exec($sql);
			print "disabled($sql) invalid userids\n" if $sth;
		}
	} else {
		print "nothing to do (@notok)\n";
	}
	
	return $ret;
}


=item execute 

Process action on behalf user 

	my $i_ok = $self->execute('UPDATE x SET y WHERE z etc...');

=cut

sub execute { # x 
	my $self = shift;
	my $action = join(' ', @_); # sql

	my $ret  = '';
	my $ROWS = 0;
		
	if ($action !~ /\w+/) {
		print "No actions supplied($action)\n";
	} else {
		$FIX = 0 unless $self->isadmin eq $self->system('bugmaster'); # rjsf hardwired
		if (!$FIX) {
			# my $sth = $self->dbh->prepare($action);
			print "Not bugmaster!\n";
		} else {
			my $sth = $self->exec($action);
			if (!$sth) {
				print "Action failed($sth) -> for action($action)\n";
			} else {
				print "Action $action OK\n";
			}
		}
	}
		
	return $ret;
}


=item ubl 

Update db_user_bug from db_log by userid

=cut

sub ubl { # ubl user_bug_log 
	my $self = shift;
	my $user = shift || '';
	my $sql  = ($user =~ /\w+/o) ? "userid LIKE '$user'" : "userid LIKE '_%'";

	my $ret   = '';
	my $i_cnt = 0;
	my $i_seen= 0;

	my $o_bug = $self->object('bug');
	my $o_usr = $self->object('user');
	my $o_log = $self->object('log');

	print "fixing($FIX) ubl sql($sql)... ";
	my @users = $o_usr->ids($sql);
	print "users(@users)\n";

	USER:
	foreach my $usr (sort @users) {
		$o_usr->read($usr);
		my $o_rel = $o_usr->rel('bug');
		$o_rel->set_source($o_usr);
		my %known = ();
		%known = map { $_ => ++$known{$_} } $o_rel->ids($o_usr);
		my $i_known = keys %known;
		my $known = join("', '", keys %known);
		print "user($usr) knows($i_known)...";
		my $sql   = "objectkey = 'bug' AND userid = '$usr' AND objectid NOT IN ('$known')";
		my $i_tgt = my @notok = $o_log->col('objectid', $sql);
		print " and misses($i_tgt)\n";
		$#notok = $MAX - 1 if @notok > $MAX;
		BUG:
		foreach my $bid (@notok) {
			$i_seen++;
			$o_rel->assign([$bid]) if $FIX;
			$i_cnt += my $assigned = 1 if $o_rel->ASSIGNED;
			print "[$i_seen] <$i_cnt> $usr: assigned($bid)\n";
			last BUG if $i_cnt >= $MAX;
		} 
	}
	print "fixed($FIX) fixable($i_cnt) of seen($i_seen)\n";
	
	return $ret;
}


=item forward 

Assumes bugids in db, messages in dir, find messages which were not forwarded, forward them.

Not the same as an historic trawl, which is looking for new/replies, etc.

redundant

=cut

sub forward { # e
	my $self = shift;
	my $bugid = shift || ''; # 
	my $and  = ($bugid =~ /\w+/o) ? "AND bugid LIKE '$bugid'" : "AND bugid LIKE '_%'";

	my $ret  = '';
	print "fixing($FIX) x32($and)\n";
	
	my $o_bug = $self->object('bug');
	my $o_msg = $self->object('message');
	my $b_table = $o_bug->attr('table');
	my $m_table = $o_msg->attr('table');
	my @targs = $self->get_list("SELECT DISTINCT bugid FROM $b_table WHERE status = 'open' $and");
	my $targs = join("', '", @targs);
	
	my $i_fix = 0;
	my %noticed = $self->messageids_in_dirs($self->directory('mailinglists'));
	foreach my $tid (@targs) {
		my $get = "SELECT messageid FROM $m_table WHERE bugid = '$tid'";
		my @got = $self->get_list($get);
		if (scalar(@got) == 1) { # some reason for this.
			my ($header) = $self->get_list("SELECT header FROM $m_table WHERE bugid = '$tid'");
			if ($header =~ /^Message-Id:\s*(.+)\s*$/msio) {
				print "Couldn't get message-id($1) for tid($tid) from header($header)\n";
			} else {
				my $mid = $1;
				if (grep(/^$mid$/i, keys %noticed)) {
					print "tid($tid) was forwarded($mid) and ignored\n";
				} else {
					if ($FIX) {
						print "tid($tid) has lost message($mid)\n";
					} else {
						print "forwarding lost($tid) message($mid)\n";
						my ($h_data) = $self->get_data("SELECT * FROM $m_table WHERE bugid = '$tid'");
						my $o_mail = $self->convert_db2mail($h_data);
						if (ref($o_mail)) { # Notify p5p ...
							print "Failed to retrieve mail object($o_mail) from database with tid($tid)\n";
    					} else {
							my ($o_hdr, $header, $body) = $self->splice($o_mail);
        					my $o_fwd = $self->get_header($o_hdr, 'remap');
							my $i_ok = $self->send_mail($o_fwd, $body); 
        					my $msg = ($i_ok == 1) ? "Re-notified OK" : "Failed($i_ok) to re-notify with original header($header)";             
        					print $msg."\n";
							$i_fix += $i_ok;
						}
					}
				}
			}
		}
	}
	
	print "fixed $i_fix\n";

	return $ret;
}


=item scan_header

Scan only the header portion of the bug

=cut

sub scan_header {
	my $self = shift;
	return $self->scan_bugs('header', @_);
}

=item scan_body

Scan only the body portion of the bug

=cut

sub scan_body {
	my $self = shift;
	return $self->scan_bugs('body', @_);
}


=item scan_bugs

Trawls and updates bug group, osname, versions etc.

	$o_fix->scan_bugs([header|body], [bugid%]);

=cut

sub scan_bugs { # s 
	my $self 	= shift;
	my $which   = shift;
	my $bugid   = shift || '';
	my $and     = ($bugid =~ /\w+/o) ? "bugid LIKE '$bugid'" : "bugid LIKE '%_.___'";

	my $ret     = 1;
	my $i_seen	= 0;
	my $i_cnt   = 0;

	my $o_bug   = $self->object('bug');
	my @bids    = $o_bug->ids($and);

	print "fixing($FIX) to $MAX of ".@bids." bugs($and)\n";

	BUG:
	foreach my $bid (@bids) {
		my $i_fxd = 0;
		print "[$i_seen] <$i_cnt> $bid: ";		
		$i_seen++;
		$o_bug->read($bid);
		my $body   = $o_bug->data('body');
		my $header = $o_bug->data('header');
		my $o_int  = $self->setup_int($header);
		my @cc     = ();	

		if (ref($o_int) and $which eq 'header') {
			my $o_hdr  = $o_int->head; 
			@cc        = $o_hdr->get('Cc');
			my $from   = $o_hdr->get('From');
			my $msgid  = $o_hdr->get('Message-Id');
			my $subject= $o_hdr->get('Subject');
			my $to     = $o_hdr->get('To');
			chomp(@cc, $from, $subject, $to);

			my $wanted = '^(no\-[a-z]+\-given|\s*)$';
			if ($o_bug->data('email_msgid') =~ /$wanted/) {
				$o_bug->update({'email_msgid'	=> $msgid});
				print "fixed(".$o_bug->UPDATED.") was($1) => msgid($msgid)\n";
			}
			if ($o_bug->data('sourceaddr') =~ /$wanted/) {
				$o_bug->update({'sourceaddr'	=> $from});
				print "fixed(".$o_bug->UPDATED.") was($1) => from($from)\n";
			}
			if ($o_bug->data('subject') =~ /$wanted/) {
				$o_bug->update({'subject'	=> $subject});
				print "fixed(".$o_bug->UPDATED.") was($1) => subject($subject)\n";
			}
			if ($o_bug->data('toaddr') =~ /$wanted/) {
				$o_bug->update({'toaddr'	=> $to});
				print "fixed(".$o_bug->UPDATED.") was($1) => to($to)\n";
			}
		}

		if ($which eq 'body') {
			if (length($body) >= 1) {
				print '... ';
				my $h_scan = $self->scan($body);
				# don't modify any that have already been set?!
				$$h_scan{'address'}{'names'} = \@cc if scalar(@cc) >= 1;
				print 'scanned('.length($body).') '; # .(Dumper($h_scan));		
				my $i_rels = my @rels = $o_bug->relate($h_scan);
				print "-> fixed $i_rels rels(@rels)\n";
			}
		}
		print "\n";		
		last BUG if $i_cnt >= $MAX;
	}	# each BUG

	print "fixed($FIX) fixable($i_cnt) of seen($i_seen) bids(".@bids.")\n";
	return $ret;
}


=item trim_flags

Trim flags where duplicates

=cut

sub trim_flags { # f 
	my $self 	= shift;
	my $flag    = shift || '';

	my $ret     = '';
	my $i_seen	= 0;
	my $i_cnt   = 0;
	my $i_cnts  = 0;

	my @flags   = grep(/^$flag/, ($self->objects('flag'), 'group'));

	print "fixing($FIX) to $MAX of constrained($flag) flags(@flags)\n";

	BUG:
	foreach my $flag (@flags) {
		my $i_fxd = 0;
		print "[$i_seen] <$i_cnt> $flag: ";		
		$i_seen++;
		my $o_flag = $self->object($flag);
		my @ids = $o_flag->ids();
		my @names = $o_flag->id2name(\@ids);
		my %names = ();
		%names = map { $_ => ++$names{$_} } @names;
		# print Dumper(\%names);
		NAME:
		foreach my $name (keys %names) {
			print "\tname($name) ";
			if ($names{$name} == 1) {
				print "\tok($names{$name})\n";
			} else {
				print "has a problem($names{$name})... ";
				my @ids = $o_flag->name2id([$name]);
				my ($ok, @others) = sort { $a <=> $b } @ids;
				print "ids: ok($ok) others(@others)\n";
				if (!@others) {
					print "\t$name can't be fixed\n";
				} else {
					$i_fxd++;
					$o_flag->read($ok);
					my $others = join("', '", @others);
					my @rellies = (@{$o_flag->attr('from')}, @{$o_flag->attr('to')});
					print "\tfixing $name(@rellies)...\n";
					my $i_rows = 0;
					foreach my $rel (@rellies) { # bug, user, address, etc.		
						my $o_rel = $o_flag->rel($rel);
						my ($pri, $table) = ($o_rel->primary_key, $o_rel->attr('table'));
						print "\t\trel($rel)...";
						my $sql = "UPDATE $table SET $pri = '$ok' WHERE $pri IN ('$others')";
						if ($FIX) {
							my $sth = $self->exec($sql) ;
							print "\tset($sql) $pri($table) to ok($ok)\n" if $sth;
						}
					}
					print "\tdeleted($i_rows)\n";
					$i_cnts++ if $i_rows;
					$o_flag->delete(\@others) if $FIX;
					print "\tcleaned(@others)\n" if $FIX && $o_flag->DELETED;
				}
			}
		}
		$i_cnt++ if $i_fxd;
		print "\n";
	}

	print "fixed($FIX) fixable($i_cnt) names($i_cnt) ids($i_cnts) of seen($i_seen) flags(".@flags.")\n";
	return $ret;
}


=item discard

Discard duplicate and otherwise redundant info

=cut

sub discard { # d 
	my $self 	= shift;
	my $bugid   = shift || '';
	my $and     = ($bugid =~ /\w+/o) ? "bugid LIKE '$bugid'" : "bugid LIKE '_%'";

	my $ret     = '';
	my $i_seen	= 0;
	my $i_cnt   = 0;

	my $o_bug   = $self->object('bug');
	my @targets = $self->objects('mail');

	print "fixing($FIX) to $MAX targets(@targets) and($and)\n";

	if (1) { # duff
		my @notok = $o_bug->ids("bugid NOT LIKE '________.___' AND $and");
		$#notok = $MAX -1 if @notok > $MAX;
		my $notok = join("', '", @notok);
		my $b_table = $o_bug->attr('table');
		if (!$FIX) {
			print "$b_table has ".@notok." strange looking bugids('$notok')\n";
		} else {
			my $sql = "DELETE FROM $b_table WHERE bugid IN ('$notok')"; # o_bug won't allow this
			my $sth = $self->exec($sql);
			print "$b_table removed($sql) strange looking bugids(@notok)\n" if $sth;
		}
	}
	if (1) { # duplicate
		my @seen = ();
		my @bids = sort { $a <=> $b } $o_bug->ids("email_msgid LIKE '_%' AND $and");
		print "looking at ".@bids." bugids($and)\n";
		my ($grp, $sev, $stat) = ('notabug', 'none', 'duplicate');
		BUG:
		foreach my $bid (@bids) {
			$i_seen++;
			print "[$i_seen] <$i_cnt> $bid: ";
			if (grep(/^$bid$/, @seen)) {
				print "seen already\n";
			} else {
				$o_bug->read($bid);			
				my $msgid = $o_bug->data('email_msgid');
				if ($msgid !~ /\w+/) {
					print "has no email Message-Id($msgid) - fix=(i $bid)?\n";
				} else {
					my @dupes = grep(!/$bid/, $o_bug->ids("email_msgid = '$msgid'"));	
					if (!(scalar(@dupes) >= 1)) {
						# print "has no dupes(@dupes)\n";
						print ".\n";
					} else {
						push(@seen, @dupes);
						my $i_fxd = 0;
						foreach my $dupe (@dupes) {
							$o_bug->read($dupe);
							my $o_dup = $o_bug->rel('group')->set_source($o_bug);
							$o_dup->_store(['notabug']) if $FIX;
							$i_fxd++ if $o_dup->STORED;
							# $i_fxd++ if $o_bug->rel('group')->set_source($o_bug)->_store(['notabug'])->STORED;
							my $o_sev = $o_bug->rel('severity')->set_source($o_bug);
							$o_sev->_store(['none']) if $FIX;
							$i_fxd++ if $o_sev->STORED;
							my $o_stat = $o_bug->rel('status')->set_source($o_bug);
							$o_stat->_store(['duplicate']) if $FIX;
							$i_fxd++ if $o_stat->STORED;
							print "\t$dupe set($FIX) group($grp), severity($sev), status($stat) fixed($i_fxd)\n";
							foreach my $rel (grep(!/^(bug|parent|child)$/i, $self->objects('mail'))) {
								my $o_rel = $self->object($rel);
								my @ids = $o_rel->rel_ids('bug');	
								if (scalar(@ids) >= 1) {
									$o_bug->rel($rel)->assign(\@ids);	
									print "\t\t$rel passed on ".@ids." ids\n";
								}
							}
						}
						$i_cnt++ if $i_fxd;
					}
				}
			}
			last BUG if $i_cnt >= $MAX;
		}
	}

	print "fixed($FIX) fixable($i_cnt) of seen($i_seen) targets(".@targets.")\n";
	return $ret;
}


=item scan_ids

Trawls and updates bugs for msgid (email_msgid) Message-Id field

=cut

sub scan_ids { # i 
	my $self 	= shift;
	my $bugid   = shift || '';
	my $and     = ($bugid =~ /\w+/o) ? "AND bugid LIKE '$bugid'" : "AND (email_msgid IS NULL OR email_msgid = '')";

	my $ret     = '';
	my $i_seen	= 0;
	my $i_cnt   = 0;

	my $sql     = "header LIKE '_%' $and";
	print "fixing($FIX) to $MAX bugs($sql)...";

	my $o_bug   = $self->object('bug');
	my @bids    = $o_bug->ids($sql);
	my %seen    = ();
	my %dupes   = ();

	print "working with ".@bids." bugs\n";

	BUG:
	foreach my $bid (@bids) {
		my $i_fxd = 0;
		print "[$i_seen] <$i_cnt> $bid: ";		
		$i_seen++;
		$o_bug->read($bid);
		my $msgid = $o_bug->data('emailid');
		if ($msgid =~ /\w+/o) {
			print "has Message-Id($msgid)\n";
		} else {
			my $header = $o_bug->data('header');
			if ($header !~ /\w+/) {
				print "has no header($header)\n";
			} else {
				my @header = split("\n", $header);
				print "hdr(".length($header).")...";
				my $o_hdr  = Mail::Header->new(\@header);
				if (ref($o_hdr)) {
					my $msgid = $o_hdr->get('Message-Id');
					chomp($msgid);
					if ($msgid !~ /\w+/) {
						print "\tno msgid($msgid) found!\n";
					} else {
						if (length($msgid) >= 100) {
							print "problem with extra long Message-Id($msgid)\n";
						} else {
							$seen{$msgid}++;
							$dupes{$msgid}++ if $seen{$msgid} > 1;
							$o_bug->update({ 'email_msgid' => $msgid, }) if $FIX;
							$i_cnt += my $updated = $o_bug->UPDATED;
							print qq|\tSET($updated) seen($seen{$msgid}) length(|.length($msgid).
								  qq|) ->\tmsgid($msgid)\n|;
						}
					}
				}
			}
		}
		last BUG if $i_cnt >= $MAX;
	}	# each BUG

	if (keys %dupes >= 1) {
		print "Dupes: ".Dumper(\%dupes)."\n";
	}

	print "fixed($FIX) fixable($i_cnt) of seen($i_seen) bids(".@bids.")\n";
	return $ret;
}



=back

=head1 AUTHOR

Richard Foley perlbug@rfi.net 2000 2001

=cut

# 
1;
