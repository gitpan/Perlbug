# $Id: $ 

use perlbug;

CREATE TABLE tm_flags (
  type varchar(10) DEFAULT '' NOT NULL,
  flag varchar(15) DEFAULT '' NOT NULL
);  

CREATE table tm_log (
		ts timestamp(14),
		logid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
		entry blob,
		userid varchar(16),
		objectid varchar(16),
		objecttype char(1),
		PRIMARY KEY (logid)
);

CREATE table tm_note (
	  created datetime,
	  ts timestamp(14),
	  noteid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),
	  msgheader blob,		
	  msgbody blob,
	  PRIMARY KEY (noteid)
);
	
CREATE TABLE tm_bug_note ( 
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  noteid bigint(20) DEFAULT '' NOT NULL
);

CREATE table tm_patch (
	  created datetime,
	  ts timestamp(14),
	  patchid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),		
	  msgheader blob,
	  msgbody blob,
	  PRIMARY KEY (patchid)
);

CREATE TABLE tm_bug_patch ( 
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  patchid bigint(20) DEFAULT '' NOT NULL
);

CREATE TABLE tm_patch_change ( 
	  patchid bigint(20) DEFAULT '' NOT NULL,
	  changeid varchar(12) DEFAULT '' NOT NULL
);	

CREATE TABLE tm_patch_version ( 
	  patchid bigint(20) DEFAULT '' NOT NULL,
	  version varchar(12) DEFAULT '' NOT NULL
);

CREATE table tm_test (
	  created datetime,
	  ts timestamp(14),
	  testid bigint(20) unsigned NOT NULL auto_increment,
	  subject varchar(100),		
	  sourceaddr varchar(100),	
	  toaddr varchar(100),		
	  msgheader blob,
	  msgbody blob,
	  PRIMARY KEY (testid)
);

CREATE TABLE tm_bug_test (
	  bugid varchar(12) DEFAULT '' NOT NULL,
	  testid bigint(20) DEFAULT '' NOT NULL
);

CREATE TABLE tm_test_version ( 
	  testid bigint(20) DEFAULT '' NOT NULL,
	  version varchar(12) DEFAULT '' NOT NULL
);

CREATE table tm_bug_user (
  		bugid varchar(12) DEFAULT '' NOT NULL,
  		userid varchar(16)
);

CREATE table tm_cc (
  		bugid varchar(12) DEFAULT '' NOT NULL,
  		address varchar(100)
);

CREATE table tm_message (
 		created datetime,
		ts timestamp(14),
  		messageid bigint(20) unsigned NOT NULL auto_increment,
  		subject varchar(100),		
		sourceaddr varchar(100),	
		toaddr varchar(100),	
		msgheader blob,
		msgbody blob,
		PRIMARY KEY (messageid)
);

CREATE table tm_bug (
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
);

CREATE table tm_user (
		created datetime,
		ts timestamp(14),
		userid varchar(16) DEFAULT '' NOT NULL,
		password varchar(16),
		address varchar(100),
		name varchar(50),
		match_address varchar(150),
		active char(1),
		PRIMARY KEY userid (userid)
);

CREATE table tm_id (
		bugid varchar(12) DEFAULT '' NOT NULL,
		PRIMARY KEY (bugid)
);

