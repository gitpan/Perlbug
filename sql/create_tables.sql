# MySQL dump 6.0
#
# Host: localhost    Database: perlbug
#--------------------------------------------------------
# Server version	3.23.2-alpha
use perlbug;

#
# Table structure for table 'tm_cc'
#
CREATE TABLE tm_cc (
  ts timestamp(14),
  ticketid varchar(12) DEFAULT '' NOT NULL,
  address varchar(100),
  KEY ticketid (ticketid)
);

#
# Table structure for table 'tm_claimants'
#
CREATE TABLE tm_claimants (
  ts timestamp(14),
  ticketid varchar(12) DEFAULT '' NOT NULL,
  userid varchar(16),
  KEY ticketid (ticketid)
);

#
# Table structure for table 'tm_flags'
#
CREATE TABLE tm_flags (
  type varchar(10) DEFAULT '' NOT NULL,
  flag varchar(15) DEFAULT '' NOT NULL
);

#
# Table structure for table 'tm_groups'
#
CREATE TABLE tm_groups (
  groupid varchar(16) DEFAULT '' NOT NULL,
  userid varchar(16) DEFAULT '' NOT NULL
);

#
# Table structure for table 'tm_id'
#
CREATE TABLE tm_id (
  ticketid varchar(12) DEFAULT '' NOT NULL,
  PRIMARY KEY (ticketid)
);

#
# Table structure for table 'tm_log'
#
CREATE TABLE tm_log (
  ts timestamp(14),
  logid bigint(20) unsigned NOT NULL auto_increment,
  entry blob,
  userid varchar(16),
  ticketid varchar(12), # don't use
  objectid varchar(16), # use instead 
  objecttype varchar(1),# u, t, m, n, p, d
  PRIMARY KEY (logid)
);

#
# Table structure for table 'tm_messages'
#
CREATE TABLE tm_messages (
  ts timestamp(14),
  messageid bigint(20) unsigned NOT NULL auto_increment,
  ticketid varchar(12) DEFAULT '' NOT NULL,
  created datetime,
  follows bigint(20) unsigned DEFAULT '0' NOT NULL,
  author varchar(100),
  msgheader blob,
  msgbody blob,
  PRIMARY KEY (messageid),
  KEY ticketid (ticketid),
  KEY follows (follows)
);

#
# Table structure for table 'tm_notes'
#
CREATE TABLE tm_notes (
  ts timestamp(14),
  noteid bigint(20) unsigned NOT NULL auto_increment,
  ticketid varchar(12) DEFAULT '' NOT NULL,
  created datetime,
  ref bigint(20) unsigned,
  author varchar(16) DEFAULT '' NOT NULL,
  msgbody blob,
  msgheader blob,
  PRIMARY KEY (noteid),
  KEY ticketid (ticketid),
  KEY author (author)
);

#
# Table structure for table 'tm_tickets'
#
CREATE TABLE tm_tickets (
  ts timestamp(14),
  ticketid varchar(12) DEFAULT '' NOT NULL,
  created datetime,
  admingroup varchar(16) DEFAULT '' NOT NULL,
  status varchar(16) DEFAULT '' NOT NULL,
  subject varchar(100),
  sourceaddr varchar(100),
  destaddr varchar(100),
  severity varchar(16),
  category varchar(16),
  fixed varchar(16),
  version varchar(16),
  os varchar(16), 	# don't use
  osname varchar(16),  	# use instead
  PRIMARY KEY (ticketid),
  KEY admingroup (admingroup),
  KEY statusid (status)
);

#
# Table structure for table 'tm_users'
#
CREATE TABLE tm_users (
  userid varchar(16) DEFAULT '' NOT NULL,
  password varchar(16),
  address varchar(100),
  name varchar(50),
  match_address varchar(150),
  active varchar(1),
  PRIMARY KEY userid (userid)
);

# 
# Table structure for table 'tm_parent_child'
#
CREATE TABLE tm_parent_child ( 
  parentid varchar(12) DEFAULT '' NOT NULL, 
  childid varchar(12) DEFAULT '' NOT NULL
);

# 
# Table structure for table 'tm_(patches|changes|fixes)'
#
CREATE TABLE tm_patches ( 
  ts timestamp(14),
  created datetime,
  patchid bigint(20) unsigned NOT NULL auto_increment,
  subject varchar(100),		# convenience
  sourceaddr varchar(100),	# ditto
  toaddr varchar(100),		# ditto
  changeid varchar(16), 	# *
  fixed varchar(16), 		# in version
  msgheader blob,
  msgbody blob,			# :-)
  PRIMARY KEY(patchid)
);

# 
# Table structure for table 'tm_patch_ticket
#
CREATE TABLE tm_patch_ticket ( 
  ts timestamp(14),
  created datetime,
  patchid bigint(20) DEFAULT '' NOT NULL,
  ticketid varchar(12) DEFAULT '' NOT NULL
);  

#
# Table structure for table 'tm_tests'
#
CREATE TABLE tm_tests (
  created datetime,
  ts timestamp(14),
  testid bigint(20) unsigned NOT NULL auto_increment,
  ticketid varchar(12) DEFAULT '' NOT NULL,
  subject varchar(100),		# convenience
  sourceaddr varchar(100),	# ditto
  toaddr varchar(100),		# ditto
  version varchar(16),
  msgheader blob,
  msgbody blob,
  PRIMARY KEY (testid),
  KEY ticketid (ticketid)
);

# 
# Table structure for table 'tm_test_ticket
#
CREATE TABLE tm_test_ticket ( 
  ts timestamp(14),
  created datetime,
  testid bigint(20) DEFAULT '' NOT NULL,
  ticketid varchar(12) DEFAULT '' NOT NULL
);  
