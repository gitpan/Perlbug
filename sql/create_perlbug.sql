# MySQL dump 6.0
#
# Host: localhost    Database: perlbug
#--------------------------------------------------------
# Server version	3.23.2-alpha

#
# create db 
#
CREATE database perlbug;

#
# Basic perlbug user
#
use mysql
INSERT INTO user VALUES ('localhost','perlbug',PASSWORD(password),'Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','N','Y','Y','Y');

# .

