# 
# Basic perlbug administrator
# 
use perlbug;

INSERT INTO pb_user VALUES (
	now(),
	NULL,
	'perlbug', 
	 PASSWORD('gublrep'), 
	'perlbug\@rfi.net', 
	'Perlbug Administrator Dummy', 
	'perlbug\@rfi\.net', 
	'1',
	''
);
