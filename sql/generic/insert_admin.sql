# 
# Basic perlbug administrator
# 
use perlbug;

INSERT INTO tm_user VALUES (
	now(),
	NULL,
	'perlbug', 
	 PASSWORD('perlbug'), 
	'perlbug\@rfi.net', 
	'Perlbug Administrator Dummy', 
	'perlbug\@rfi\.net', 
	'0'
);
