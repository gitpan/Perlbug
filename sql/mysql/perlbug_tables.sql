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
  subject varchar(100) DEFAULT '' NOT NULL,
  sourceaddr varchar(100) DEFAULT '' NOT NULL,
  toaddr varchar(100) DEFAULT '' NOT NULL,
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (bugid),
  UNIQUE tm_bug_id_i (bugid),
  KEY tm_bug_subject (subject),
  KEY tm_bug_sourceaddr_i (sourceaddr),
  KEY tm_bug_toaddr_i (toaddr),
  KEY pb_bug_emailmsgid_i (email_msgid)
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
# counting the replies (no sub selects in mysql :-()
#
CREATE TABLE pb_bug_message_count (
        bugid VARCHAR(12),
        messagecount INT(5)
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
  UNIQUE tm_change_name_u (name),
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
  PRIMARY KEY (groupid),
  UNIQUE tm_group_id_i (groupid),
  UNIQUE group_name_i (name)
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
  PRIMARY KEY (logid),
  UNIQUE tm_log_id_i (logid)
);

#
# Table structure for table 'pb_message'
#
CREATE TABLE pb_message (
  created datetime,
  modified datetime,
  messageid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(100) DEFAULT '' NOT NULL,
  sourceaddr varchar(100) DEFAULT '' NOT NULL,
  toaddr varchar(100) DEFAULT '' NOT NULL,
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (messageid),
  UNIQUE tm_message_id_i (messageid),
  KEY tm_message_subject_i (subject),
  KEY tm_message_sourceaddr_i (sourceaddr),
  KEY tm_message_toaddr_i (toaddr),
  KEY pb_message_emailmsgid_i (email_msgid)
);

#
# Table structure for table 'pb_note'
#
CREATE TABLE pb_note (
  created datetime,
  modified datetime,
  noteid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(100),
  sourceaddr varchar(100),
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (noteid),
  UNIQUE tm_note_id_i (noteid),
  KEY pb_note_emailmsgid_i (email_msgid)
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
  UNIQUE tm_osname_name_u (name),
  UNIQUE osname_name_i (name)
);

#
# Table structure for table 'pb_patch'
#
CREATE TABLE pb_patch (
  created datetime,
  modified datetime,
  patchid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(100),
  sourceaddr varchar(100),
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (patchid),
  UNIQUE tm_patch_id_i (patchid),
  KEY pb_patch_emailmsgid_i (email_msgid)
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
  description varchar(150) DEFAULT '' NOT NULL,
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
  UNIQUE tm_severity_name_u (name),
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
  UNIQUE tm_status_name_u (name),
  UNIQUE status_name_i (name)
);

#
# Table structure for table 'pb_template'
#
CREATE TABLE pb_template (
  created datetime,
  ts timestamp(14),
  templateid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  name varchar(16),
  description varchar(150),
  subject varchar(100),
  sourceaddr varchar(100),
  toaddr varchar(100),
  header blob,
  body blob,
  PRIMARY KEY (templateid)
);

#
# Table structure for table 'pb_test'
#
CREATE TABLE pb_test (
  created datetime,
  modified datetime,
  testid bigint(20) unsigned DEFAULT '0' NOT NULL auto_increment,
  subject varchar(100),
  sourceaddr varchar(100),
  toaddr varchar(100),
  header blob,
  body blob,
  email_msgid varchar(100) DEFAULT '' NOT NULL,
  PRIMARY KEY (testid),
  UNIQUE tm_test_id_i (testid),
  KEY pb_test_emailmsgid_i (email_msgid)
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
# Table structure for table 'pb_type'
#
CREATE TABLE pb_type (
  created datetime,
  ts timestamp(14),
  typeid smallint(5) unsigned DEFAULT '0' NOT NULL auto_increment,
  type varchar(16),
  name varchar(25) DEFAULT '' NOT NULL,
  description varchar(150),
  PRIMARY KEY (typeid)
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
  PRIMARY KEY (userid),
  UNIQUE tm_user_id_i (userid)
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
  UNIQUE tm_version_name_u (name),
  UNIQUE version_name_i (name)
);

