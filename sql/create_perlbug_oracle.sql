# Oracle 8+ 
#
# Host: localhost    Database: perlbug
#--------------------------------------------------------
# Server version	3.23.2-alpha

connect internal;

#
# create db 
#
CREATE database perlbug
		controlfile reuse
		logfile
		group 1 ('/ora1/oradata/perlbugredo1a.log', '/ora1/oradata/perlbugredo1b.log') size 1m,
		group 2 ('/ora1/oradata/perlbugredo2a.log', '/ora1/oradata/perlbugredo2b.log') size 1m,
		maxlogfiles 3
		maxloghistory 1000
		datafile '/ora1/oradata/perlbug01.dat' size 30m autoextend 10m maxsize 100m,
		datafile '/ora1/oradata/perlbugindex01.dat' size 30m autoextend 10m maxsize 100m,
		datafile '/ora1/oradata/perlbugrollback01.dat' size 20m,
		datafile '/ora1/oradata/perlbugusers01.dat' size 10m,
		datafile '/ora1/oradata/perlbugtemp01.dat' size 10m maxdatafiles 20
		
;

#
# Basic perlbug user
#
CREATE USER perlbug identified by perlbug;
ALTER  USER perlbug default tablespace perlbug01 temporary tablespace perlbugtemp01;
GRANT  CONNECT, RESOURCE, DBA TO perlbug;

# run @admin/DB1T/pfile/creat_perlbug
# 
# .

