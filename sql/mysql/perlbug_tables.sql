# MySQL dump 7.1
#
# Host: localhost    Database: perlbug
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'pb_address'
#
CREATE TABLE pb_address (
  created datetime,
  modified datetime,
  addressid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (addressid),
  UNIQUE address_name_i (name)
);

#
# Table structure for table 'pb_address_bug'
#
CREATE TABLE pb_address_bug (
  created datetime,
  modified datetime,
  bugid varchar(12),
  addressid int(20)
);

#
# Table structure for table 'pb_address_group'
#
CREATE TABLE pb_address_group (
  created datetime,
  modified datetime,
  groupid varchar(20),
  addressid int(20)
);

#
# Table structure for table 'pb_bug'
#
CREATE TABLE pb_bug (
  created datetime,
  modified datetime,
  bugid varchar(12) DEFAULT '' NOT NULL,
  subject varchar(255) DEFAULT '' NOT NULL,
  sourceaddr varchar(255) DEFAULT '' NOT NULL,
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (bugid),
  UNIQUE bug_id (bugid),
  KEY pb_bug_emailmsgid_i (email_msgid),
  KEY bugid (bugid),
  KEY subject (subject),
  KEY email_msgid (email_msgid),
  KEY sourceaddr (sourceaddr)
);

#
# Table structure for table 'pb_bug_change'
#
CREATE TABLE pb_bug_change (
  created datetime,
  modified datetime,
  bugid varchar(12),
  changeid bigint(20)
);

#
# Table structure for table 'pb_bug_child'
#
CREATE TABLE pb_bug_child (
  created datetime,
  modified datetime,
  bugid varchar(12),
  childid varchar(12)
);

#
# Table structure for table 'pb_bug_fixed'
#
CREATE TABLE pb_bug_fixed (
  created datetime,
  modified datetime,
  bugid varchar(12),
  fixedid smallint(5)
);

#
# Table structure for table 'pb_bug_group'
#
CREATE TABLE pb_bug_group (
  created datetime,
  modified datetime,
  groupid varchar(12) DEFAULT '' NOT NULL,
  bugid varchar(12) DEFAULT '' NOT NULL
);

#
# Table structure for table 'pb_bug_message'
#
CREATE TABLE pb_bug_message (
  created datetime,
  modified datetime,
  bugid varchar(12) DEFAULT '' NOT NULL,
  messageid bigint(20) unsigned DEFAULT '0' NOT NULL
);

#
# Table structure for table 'pb_bug_message_count'
#
CREATE TABLE pb_bug_message_count (
  bugid varchar(12),
  messagecount int(5)
);

#
# Table structure for table 'pb_bug_note'
#
CREATE TABLE pb_bug_note (
  created datetime,
  modified datetime,
  bugid varchar(12) DEFAULT '' NOT NULL,
  noteid bigint(20) unsigned DEFAULT '0' NOT NULL
);

#
# Table structure for table 'pb_bug_osname'
#
CREATE TABLE pb_bug_osname (
  created datetime,
  modified datetime,
  bugid varchar(12),
  osnameid smallint(5)
);

#
# Table structure for table 'pb_bug_parent'
#
CREATE TABLE pb_bug_parent (
  created datetime,
  modified datetime,
  bugid varchar(12),
  parentid varchar(12)
);

#
# Table structure for table 'pb_bug_patch'
#
CREATE TABLE pb_bug_patch (
  created datetime,
  modified datetime,
  bugid varchar(12) DEFAULT '' NOT NULL,
  patchid bigint(20) unsigned DEFAULT '0' NOT NULL
);

#
# Table structure for table 'pb_bug_project'
#
CREATE TABLE pb_bug_project (
  created datetime,
  ts timestamp(14),
  projectid smallint(5),
  bugid varchar(16)
);

#
# Table structure for table 'pb_bug_range'
#
CREATE TABLE pb_bug_range (
  created datetime,
  ts timestamp(14),
  rangeid bigint(20),
  bugid varchar(16)
);

#
# Table structure for table 'pb_bug_severity'
#
CREATE TABLE pb_bug_severity (
  created datetime,
  modified datetime,
  bugid varchar(12),
  severityid smallint(5)
);

#
# Table structure for table 'pb_bug_status'
#
CREATE TABLE pb_bug_status (
  created datetime,
  modified datetime,
  bugid varchar(12),
  statusid smallint(5)
);

#
# Table structure for table 'pb_bug_test'
#
CREATE TABLE pb_bug_test (
  created datetime,
  modified datetime,
  bugid varchar(12) DEFAULT '' NOT NULL,
  testid bigint(20) unsigned DEFAULT '0' NOT NULL
);

#
# Table structure for table 'pb_bug_user'
#
CREATE TABLE pb_bug_user (
  created datetime,
  modified datetime,
  userid varchar(16) DEFAULT '' NOT NULL,
  bugid varchar(12) DEFAULT '' NOT NULL
);

#
# Table structure for table 'pb_bug_version'
#
CREATE TABLE pb_bug_version (
  created datetime,
  modified datetime,
  bugid varchar(12),
  versionid smallint(5)
);

#
# Table structure for table 'pb_bugid'
#
CREATE TABLE pb_bugid (
  created datetime,
  modified datetime,
  bugid varchar(12) DEFAULT '' NOT NULL
);

#
# Table structure for table 'pb_change'
#
CREATE TABLE pb_change (
  created datetime,
  modified datetime,
  changeid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(16) DEFAULT '' NOT NULL,
  PRIMARY KEY (changeid),
  UNIQUE change_name_i (name)
);

#
# Table structure for table 'pb_change_patch'
#
CREATE TABLE pb_change_patch (
  created datetime,
  modified datetime,
  patchid varchar(20),
  changeid bigint(20)
);

#
# Table structure for table 'pb_group'
#
CREATE TABLE pb_group (
  created datetime,
  modified datetime,
  groupid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(25) DEFAULT '' NOT NULL,
  description varchar(150) DEFAULT '' NOT NULL,
  PRIMARY KEY (groupid)
);

#
# Table structure for table 'pb_group_user'
#
CREATE TABLE pb_group_user (
  created datetime,
  modified datetime,
  groupid varchar(12) DEFAULT '' NOT NULL,
  userid varchar(16) DEFAULT '' NOT NULL
);

#
# Table structure for table 'pb_log'
#
CREATE TABLE pb_log (
  created datetime,
  modified datetime,
  logid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  entry blob,
  userid varchar(16),
  objectid varchar(16),
  objectkey varchar(16),
  PRIMARY KEY (logid)
);

#
# Table structure for table 'pb_message'
#
CREATE TABLE pb_message (
  created datetime,
  modified datetime,
  messageid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(255) DEFAULT '' NOT NULL,
  sourceaddr varchar(255) DEFAULT '' NOT NULL,
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (messageid),
  UNIQUE message_id (messageid),
  KEY pb_message_emailmsgid_i (email_msgid),
  KEY subject (subject),
  KEY email_msgid (email_msgid),
  KEY sourceaddr (sourceaddr),
  KEY messageid (messageid)
);

#
# Table structure for table 'pb_note'
#
CREATE TABLE pb_note (
  created datetime,
  modified datetime,
  noteid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(255) DEFAULT '' NOT NULL,
  sourceaddr varchar(255) DEFAULT '' NOT NULL,
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (noteid),
  KEY pb_note_emailmsgid_i (email_msgid),
  KEY email_msgid (email_msgid),
  KEY sourceaddr (sourceaddr),
  KEY noteid (noteid)
);

#
# Table structure for table 'pb_object'
#
CREATE TABLE pb_object (
  created datetime,
  ts timestamp(14),
  objectid smallint(5),
  type char(16),
  name char(25) DEFAULT '' NOT NULL,
  description char(150)
);

#
# Table structure for table 'pb_osname'
#
CREATE TABLE pb_osname (
  created datetime,
  modified datetime,
  osnameid smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(16) DEFAULT '' NOT NULL,
  PRIMARY KEY (osnameid),
  UNIQUE osname_name_i (name)
);

#
# Table structure for table 'pb_patch'
#
CREATE TABLE pb_patch (
  created datetime,
  modified datetime,
  patchid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(255) DEFAULT '' NOT NULL,
  sourceaddr varchar(255) DEFAULT '' NOT NULL,
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (patchid),
  KEY pb_patch_emailmsgid_i (email_msgid),
  KEY email_msgid (email_msgid),
  KEY sourceaddr (sourceaddr),
  KEY sourceaddr_2 (sourceaddr),
  KEY sourceaddr_3 (sourceaddr),
  KEY patchid (patchid)
);

#
# Table structure for table 'pb_patch_version'
#
CREATE TABLE pb_patch_version (
  created datetime,
  modified datetime,
  patchid bigint(20),
  versionid smallint(5)
);

#
# Table structure for table 'pb_project'
#
CREATE TABLE pb_project (
  created datetime,
  ts timestamp(14),
  projectid smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(25) DEFAULT '' NOT NULL,
  description varchar(150),
  PRIMARY KEY (projectid),
  UNIQUE project_name_i (name)
);

#
# Table structure for table 'pb_range'
#
CREATE TABLE pb_range (
  created datetime,
  modified datetime,
  rangeid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  processid varchar(12),
  range blob,
  PRIMARY KEY (rangeid)
);

#
# Table structure for table 'pb_severity'
#
CREATE TABLE pb_severity (
  created datetime,
  modified datetime,
  severityid smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(16) DEFAULT '' NOT NULL,
  PRIMARY KEY (severityid),
  UNIQUE severity_name_i (name)
);

#
# Table structure for table 'pb_status'
#
CREATE TABLE pb_status (
  created datetime,
  modified datetime,
  statusid smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(16) DEFAULT '' NOT NULL,
  PRIMARY KEY (statusid),
  UNIQUE status_name_i (name)
);

#
# Table structure for table 'pb_template'
#
CREATE TABLE pb_template (
  created datetime,
  ts timestamp(14),
  templateid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  object varchar(16),
  type varchar(16) DEFAULT '',
  format char(1) DEFAULT '' NOT NULL,
  wrap int(11),
  repeat int(11),
  description varchar(255),
  header blob,
  body blob,
  PRIMARY KEY (templateid)
);

#
# Table structure for table 'pb_template_user'
#
CREATE TABLE pb_template_user (
  created datetime,
  modified datetime,
  templateid bigint(20),
  userid varchar(16) DEFAULT '' NOT NULL
);

#
# Table structure for table 'pb_test'
#
CREATE TABLE pb_test (
  created datetime,
  modified datetime,
  testid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(255) DEFAULT '' NOT NULL,
  sourceaddr varchar(255) DEFAULT '' NOT NULL,
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (testid),
  KEY pb_test_emailmsgid_i (email_msgid),
  KEY email_msgid (email_msgid),
  KEY sourceaddr (sourceaddr),
  KEY testid (testid),
  KEY testid_2 (testid)
);

#
# Table structure for table 'pb_test_version'
#
CREATE TABLE pb_test_version (
  created datetime,
  modified datetime,
  testid bigint(20),
  versionid smallint(5)
);

#
# Table structure for table 'pb_thing'
#
CREATE TABLE pb_thing (
  created datetime,
  ts timestamp(14),
  thingid smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  type varchar(16),
  name varchar(25) DEFAULT '' NOT NULL,
  description varchar(150),
  PRIMARY KEY (thingid),
  UNIQUE thing_name_i (name)
);

#
# Table structure for table 'pb_user'
#
CREATE TABLE pb_user (
  created datetime,
  modified datetime,
  userid varchar(16) DEFAULT '' NOT NULL,
  password varchar(16),
  address varchar(100),
  name varchar(50),
  match_address varchar(150),
  active char(1),
  p5p_key blob,
  PRIMARY KEY (userid)
);

#
# Table structure for table 'pb_version'
#
CREATE TABLE pb_version (
  created datetime,
  modified datetime,
  versionid smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(16) DEFAULT '' NOT NULL,
  PRIMARY KEY (versionid),
  UNIQUE version_name_i (name)
);

