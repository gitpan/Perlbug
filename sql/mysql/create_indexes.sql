# rjsf - optimize
#.................!!!!!
# select messageid from pb_message where subject like 'please%'; 
# 19 rows in set (38.74 sec)
# ----------------^^^^^
# ALTER TABLE pb_message MODIFY subject VARCHAR(255) NOT NULL;
# ALTER TABLE pb_message ADD INDEX(subject);
# 19 rows in set (0.23 sec)    
# ----------------^^^^
#................!!!!!

# Objects: 
ALTER TABLE pb_address ADD INDEX(addressid);
ALTER TABLE pb_address ADD INDEX(name);

ALTER TABLE pb_bug ADD INDEX(bugid);
ALTER TABLE pb_bug MODIFY subject VARCHAR(255) NOT NULL; 
ALTER TABLE pb_bug ADD INDEX(subject);
ALTER TABLE pb_bug ADD INDEX(email_msgid);  
ALTER TABLE pb_bug MODIFY sourceaddr VARCHAR(255) NOT NULL; 
ALTER TABLE pb_bug ADD INDEX(sourceaddr);

ALTER TABLE pb_message ADD INDEX(messageid);  
ALTER TABLE pb_message ADD INDEX(email_msgid);  
ALTER TABLE pb_message MODIFY subject VARCHAR(255) NOT NULL; 
ALTER TABLE pb_message MODIFY sourceaddr VARCHAR(255) NOT NULL; 
ALTER TABLE pb_message ADD INDEX(sourceaddr);

ALTER TABLE pb_note ADD INDEX(noteid);  
ALTER TABLE pb_note ADD INDEX(email_msgid);  
ALTER TABLE pb_note MODIFY subject VARCHAR(255) NOT NULL; 
ALTER TABLE pb_note MODIFY sourceaddr VARCHAR(255) NOT NULL; 
ALTER TABLE pb_note ADD INDEX(sourceaddr);

ALTER TABLE pb_patch ADD INDEX(patchid);  
ALTER TABLE pb_patch ADD INDEX(email_msgid);  
ALTER TABLE pb_patch MODIFY subject VARCHAR(255) NOT NULL; 
ALTER TABLE pb_patch MODIFY sourceaddr VARCHAR(255) NOT NULL; 
ALTER TABLE pb_patch ADD INDEX(sourceaddr);

ALTER TABLE pb_test ADD INDEX(testid);  
ALTER TABLE pb_test ADD INDEX(email_msgid);  
ALTER TABLE pb_test MODIFY subject VARCHAR(255) NOT NULL; 
ALTER TABLE pb_test MODIFY sourceaddr VARCHAR(255) NOT NULL; 
ALTER TABLE pb_test ADD INDEX(sourceaddr);

ALTER TABLE pb_fixed ADD INDEX(fixedid);  
ALTER TABLE pb_fixed ADD INDEX(name);  

ALTER TABLE pb_version ADD INDEX(versionid);  
ALTER TABLE pb_version ADD INDEX(name);  

# Relations:
ALTER TABLE pb_address_bug MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_address_bug MODIFY addressid INT(20) NOT NULL; 
ALTER TABLE pb_address_bug ADD INDEX(addressid);
ALTER TABLE pb_address_bug ADD INDEX(bugid);

ALTER TABLE pb_bug_change MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_change MODIFY changeid INT(5) NOT NULL; 
ALTER TABLE pb_bug_change ADD INDEX(bugid);
ALTER TABLE pb_bug_change ADD INDEX(changeid);

ALTER TABLE pb_bug_child MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_child MODIFY childid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_child ADD INDEX(bugid);
ALTER TABLE pb_bug_child ADD INDEX(childid);

ALTER TABLE pb_bug_fixed MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_fixed MODIFY fixedid INT(5) NOT NULL; 
ALTER TABLE pb_bug_fixed ADD INDEX(bugid);
ALTER TABLE pb_bug_fixed ADD INDEX(fixedid);

ALTER TABLE pb_bug_group MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_group MODIFY groupid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_group ADD INDEX(bugid);
ALTER TABLE pb_bug_group ADD INDEX(groupid);

ALTER TABLE pb_bug_message MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_message MODIFY messageid INT(20) NOT NULL; 
ALTER TABLE pb_bug_message ADD INDEX(bugid);
ALTER TABLE pb_bug_message ADD INDEX(messageid);

ALTER TABLE pb_bug_note MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_note MODIFY noteid INT(20) NOT NULL; 
ALTER TABLE pb_bug_note ADD INDEX(bugid);
ALTER TABLE pb_bug_note ADD INDEX(noteid);

ALTER TABLE pb_bug_osname MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_osname MODIFY osnameid INT(5) NOT NULL; 
ALTER TABLE pb_bug_osname ADD INDEX(bugid);
ALTER TABLE pb_bug_osname ADD INDEX(osnameid);

ALTER TABLE pb_bug_parent MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_parent MODIFY parentid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_parent ADD INDEX(bugid);
ALTER TABLE pb_bug_parent ADD INDEX(parentid);

ALTER TABLE pb_bug_patch MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_patch MODIFY patchid INT(20) NOT NULL; 
ALTER TABLE pb_bug_patch ADD INDEX(bugid);
ALTER TABLE pb_bug_patch ADD INDEX(patchid);

ALTER TABLE pb_bug_project MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_project MODIFY projectid INT(5) NOT NULL; 
ALTER TABLE pb_bug_project ADD INDEX(bugid);
ALTER TABLE pb_bug_project ADD INDEX(projectid);

ALTER TABLE pb_bug_range MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_range MODIFY rangeid INT(20) NOT NULL; 
ALTER TABLE pb_bug_range ADD INDEX(bugid);
ALTER TABLE pb_bug_range ADD INDEX(rangeid);
 
ALTER TABLE pb_bug_severity MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_severity MODIFY severityid INT(5) NOT NULL; 
ALTER TABLE pb_bug_severity ADD INDEX(bugid);
ALTER TABLE pb_bug_severity ADD INDEX(severityid);

ALTER TABLE pb_bug_status MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_status MODIFY statusid INT(5) NOT NULL; 
ALTER TABLE pb_bug_status ADD INDEX(bugid);
ALTER TABLE pb_bug_status ADD INDEX(statusid);

ALTER TABLE pb_bug_test MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_test MODIFY testid INT(20) NOT NULL; 
ALTER TABLE pb_bug_test ADD INDEX(bugid);
ALTER TABLE pb_bug_test ADD INDEX(testid);

ALTER TABLE pb_bug_version MODIFY bugid VARCHAR(12) NOT NULL; 
ALTER TABLE pb_bug_version MODIFY versionid INT(5) NOT NULL; 
ALTER TABLE pb_bug_version ADD INDEX(bugid);
ALTER TABLE pb_bug_version ADD INDEX(versionid);

ALTER TABLE pb_bug_user ADD INDEX(bugid);
ALTER TABLE pb_bug_user ADD INDEX(userid);

# done
