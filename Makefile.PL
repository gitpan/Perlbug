# 
# $Id: Makefile.PL,v 1.7 2001/04/21 20:48:48 perlbug Exp $
# 
# Perlbug Makefile.PL -> 'perl Makefile.PL'
# (C) 2000 Richard Foley RFI perlbug@rfi.net
#

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'dist'	   => {
	'CI' => 'ci -l',
    },
    'NAME'	   => 'Perlbug',
    'VERSION_FROM' => 'Perlbug.pm',
    # 'PREFIX'	   => 'Perlbug_installation',
    'PREREQ_PM'	   => {
		'Carp'          => 0,
		'CGI'           => 0,
		'DBI'           => 0,
		'Data::Dumper'  => 0,
		'Exporter'		=> 0,
		'FileHandle'    => 0,
		'File::Spec'	=> 0,
		'Getopt::Std'	=> 0,
		'HTML::Entities'=> 0,
		'IO::File'      => 0,
		'Mail::Address' => 0,
		'Mail::Header' 	=> 0,
		'Mail::Internet'=> 0,
		'Mail::Send'    => 0,
		'Mysql'         => 0,
		'Shell'         => 0,
		'Sys::Hostname' => 0,
		'Test'			=> 0,
		'URI::Escape'	=> 0,
    },
);
