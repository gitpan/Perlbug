
# start migration
# ------------------------------------------------------------------------------

=item x0

Migrate log

=cut

sub x0 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x0', 'tm_log');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT logid FROM $tables ");
	
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_log (
		ts timestamp(14),
		logid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
		entry blob,
		userid varchar(16),
		objectid varchar(16),
		objecttype char(1),
		PRIMARY KEY (logid)
);|;
	my $transfer = qq|INSERT INTO tm_log SELECT ts, logid, entry, userid, objectid, objecttype FROM ${tables}_data|;
	 
	my $update = qq|UPDATE tm_log set objecttype = 'b' WHERE objecttype = 't' AND objectid LIKE '%.%'|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer, $update);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item x1

Migrate notes

=cut

sub x1 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x1', 'tm_notes');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
		
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_notes");
	my $targs = join("', '", @targs);		
	my $rows = 0;
	
	my $store   = qq|ALTER TABLE tm_notes RENAME tm_notes_data|;
	my $create1	= qq|CREATE table tm_note (
	  created datetime,
	  ts timestamp(14),
	  noteid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),
	  msgheader blob,		
	  msgbody blob,
	  PRIMARY KEY (noteid)
);|;
	my $create2	= qq|CREATE TABLE tm_bug_note ( 
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  noteid bigint(20) DEFAULT '' NOT NULL
);|;
	my $transfer= qq|INSERT INTO tm_note SELECT created, ts, noteid, '', '', '', msgheader, msgbody FROM tm_notes_data|;
	my $links	= qq|INSERT INTO tm_bug_note SELECT ticketid, noteid FROM tm_notes_data|;
	
	if (scalar(@targs) >= 1) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create1, $create2, $transfer, $links);
		} else {
			$self->result("tm_notes has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item x2

Migrate patches

=cut

sub x2 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x2', 'tm_patches');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
		
	my @targs = $self->get_list("SELECT DISTINCT patchid FROM tm_patches");
	my $targs = join("', '", @targs);		
	my $rows = 0;
	
	my $store   = qq|ALTER TABLE tm_patches RENAME tm_patches_data|;
	my $create1	= qq|CREATE table tm_patch (
	  created datetime,
	  ts timestamp(14),
	  patchid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),		
	  msgheader blob,
	  msgbody blob,
	  PRIMARY KEY (patchid)
);|;
	my $create2 = qq|CREATE TABLE tm_bug_patch ( 
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  patchid bigint(20) DEFAULT '' NOT NULL
);|;	
	my $create3 = qq|CREATE TABLE tm_patch_change ( 
	  patchid bigint(20) DEFAULT '' NOT NULL,
	  changeid varchar(12) DEFAULT '' NOT NULL
);|;	
	my $create4 = qq|CREATE TABLE tm_patch_version ( 
	  patchid bigint(20) DEFAULT '' NOT NULL,
	  version varchar(12) DEFAULT '' NOT NULL
);|;
	my $transfer= qq|INSERT INTO tm_patch SELECT created, ts, patchid, subject, sourceaddr, toaddr, msgheader, msgbody FROM tm_patches_data|;
	my $refs	= qq|INSERT INTO tm_bug_patch SELECT ticketid, patchid FROM tm_patch_ticket|;
	my $change  = qq|INSERT INTO tm_patch_change SELECT patchid, changeid FROM tm_patches_data|;
	
	if (scalar(@targs) >= 1) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create1, $create2, $create3, $create4, $transfer, $refs, $change);
		} else {
			$self->result("tm_patches has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}


=item x3

Migrate tests

=cut

sub x3 {
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x3', 'tm_tests');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
		
	my @targs = $self->get_list("SELECT DISTINCT testid FROM tm_tests");
	my $targs = join("', '", @targs);		
	my $rows = 0;
	
	my $store   = qq|ALTER TABLE tm_tests RENAME tm_tests_data|;
	my $create1	= qq|CREATE table tm_test (
	  created datetime,
	  ts timestamp(14),
	  testid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),		
	  msgheader blob,
	  msgbody blob,
	  PRIMARY KEY (testid)
);|;
	my $create2 = qq|CREATE TABLE tm_bug_test (
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  testid bigint(20) DEFAULT '' NOT NULL
);|;
	my $create3 = qq|CREATE TABLE tm_test_version ( 
	  testid bigint(20) DEFAULT '' NOT NULL,
	  version varchar(12) DEFAULT '' NOT NULL
);|;
	my $transfer = qq|INSERT INTO tm_test select created, ts, testid, subject, sourceaddr, toaddr, msgheader, msgbody FROM tm_tests_data|;
	my $refs	 = qq|INSERT INTO tm_bug_test SELECT ticketid, testid FROM tm_test_ticket|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create1, $create2, $create3, $transfer, $refs);
		} else {
			$self->result("tm_tests has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

sub x4 { # claimants
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x4', 'tm_claimants');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_claimants");
	
	my $store   = qq|ALTER TABLE tm_claimants RENAME tm_claimants_data|;
	my $create	= qq|CREATE table tm_bug_user (
  		bugid varchar(12) DEFAULT '' NOT NULL,
  		userid varchar(16)
);|;
	my $transfer = qq|INSERT INTO tm_bug_user SELECT ticketid, userid FROM tm_claimants_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
	
} 


sub x5 { # cc
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	
	my ($sub, $tables) = ('x5', 'tm_bug_address');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM tm_bug_address");
	
	my $store   = qq|ALTER TABLE tm_bug_address RENAME tm_bug_address_data|;
	my $create	= qq|CREATE table tm_bug_address (
  		bugid varchar(12) DEFAULT '' NOT NULL,
  		address varchar(100)
);|;
	my $transfer = qq|INSERT INTO tm_bug_address SELECT ticketid, address FROM tm_bug_address_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
	
} 

sub x6 { # tm_messages
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	
	my ($sub, $tables) = ('x6', 'tm_messages');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT messageid FROM $tables");
	
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create1	= qq|CREATE table tm_message (
 		created datetime,
		ts timestamp(14),
  		messageid bigint(20) unsigned NOT NULL auto_increment,
  		subject varchar(100),		
		sourceaddr varchar(100),	
		toaddr varchar(100),	
		msgheader blob,
		msgbody blob,
		PRIMARY KEY (messageid)
);|;
	my $create2	= qq|CREATE table tm_bug_message (
  		bugid varchar(12) DEFAULT '' NOT NULL,
		messageid bigint(20) unsigned NOT NULL
);|;

	my $transfer1 = qq|INSERT INTO tm_message SELECT created, ts, messageid, '', author, '', msgheader, msgbody FROM ${tables}_data|;
	my $transfer2 = qq|INSERT INTO tm_bug_message SELECT ticketid, messageid FROM ${tables}_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_fix += $i_ok = $self->action($tables, $store, $create1, $create2, $transfer1, $transfer2);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
} 

sub x7 { # tm_tickets -> tm_bug
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	
	my ($sub, $tables) = ('x7', 'tm_tickets');
	$self->result("fixing($FIX) $sub $tables");
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT ticketid FROM $tables");
	
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_bug (
		created datetime,
		ts timestamp(14),
		bugid varchar(12) DEFAULT '' NOT NULL,
		subject varchar(100),
		sourceaddr varchar(100),
		toaddr varchar(100),
		status varchar(16) DEFAULT '' NOT NULL,
		severity varchar(16),
		category varchar(16),
		fixed varchar(16),
		version varchar(16),
		osname varchar(16),  	# use instead
		PRIMARY KEY (bugid)
);|;
	my $transfer = qq|INSERT INTO tm_bug 
		SELECT created, ts, ticketid, subject, sourceaddr, destaddr, status, severity, category, fixed, version, osname 
		FROM ${tables}_data|;
	
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_fix += $i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

sub x8 { # users
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x8', 'tm_users');
	$self->result("fixing($FIX) $sub $tables");
	
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT DISTINCT userid FROM tm_users");
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_user (
		created datetime,
		ts timestamp(14),
		userid varchar(16) DEFAULT '' NOT NULL,
		password varchar(16),
		address varchar(100),
		name varchar(50),
		match_address varchar(150),
		active char(1),
		PRIMARY KEY userid (userid)
);|;
	my $transfer = qq|INSERT INTO tm_user
		SELECT now(), NULL, userid, password, address, name, match_address, active 
		FROM ${tables}_data|;
	 
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
} 

sub x9 { # id
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @res  = ();
	my $i_ok = 1;
	my ($sub, $tables) = ('x9', 'tm_bugid');
	$self->result("fixing($FIX) $sub $tables");
	
	my $i_fix = 0;
	my $rows = 0;
	
	my @targs = $self->get_list("SELECT * FROM $tables");
	my $store   = qq|ALTER TABLE $tables RENAME ${tables}_data|;
	my $create	= qq|CREATE table tm_bugid (
		bugid varchar(12) DEFAULT '' NOT NULL,
		PRIMARY KEY (bugid)
);|;
	my $transfer = qq|INSERT INTO tm_bugid SELECT ticketid FROM ${tables}_data|;
	 
	if (scalar(@targs) >= 0) {
		if ($FIX) {
			$i_ok = $self->action($tables, $store, $create, $transfer);
		} else {
			$self->result("$tables has ".@targs." references");
		} 
	} else {
		$self->result("nothing to do (@targs)");
	}
	
	$self->result("fixed $i_fix");
	$self->debug('OUT', $i_ok);
	return $i_ok;
} 

=item x99

Remove MIGRATE deadwood if everythings is OK

=cut

sub x99 { # x99
	my $self = shift;
	$self->debug('IN', @_);
	my $line = shift;
	my @args = @_;
	my @res  = ();
	my $i_ok = 1;
	my $rows = 0;
	my ($sub, $tables) = ('x99', 'drop tables');
	$self->result("fixing($FIX) $sub $tables");
	
	my @drops = (
		'DROP TABLE admingroups',
		'DROP table tm_bug_address_data',
		'DROP table tm_claimants_data',
		'DROP table tm_bugid_data',
		'DROP table tm_log_data',
		'DROP table tm_messages_data',
		'DROP table tm_notes_data',
		'DROP table tm_patches_data',
		'DROP TABLE tm_patch_ticket',
		'DROP table tm_spam',
		'DROP TABLE tm_tests_data',
		'DROP TABLE tm_test_ticket',
		'DROP table tm_tickets_data',
		'DROP table tm_users_data',
	);
	
	if (@drops >= 1) {
		if ($FIX) {
			$i_ok = $self->action($tables, @drops);
			$self->result("Remember to fix Base::check_user->tm_user(s)");
		} else {
			$self->result("$sub has ".@drops." tables to fix(@args)");
		} 
	} else {
		$self->result("nothing to do (".@drops.")");
	}
	
	$self->debug('OUT', $i_ok);
	return $i_ok;
}

# end migration
# ------------------------------------------------------------------------------
