#
# Basic perlbug user
#

CREATE USER perlbug IDENTIFIED BY 'gublrep';

ALTER USER perlbug DEFAULT TABLESPACE perlbug; 

GRANT USER perlbug CONNECT, RESOURCE, DBA;

