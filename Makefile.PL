# Perlbug Makefile.PL -> 'perl Makefile.PL'
# (C) 2000 Richard Foley RFI perlbug@rfi.net
# $Id: Makefile.PL,v 1.4 2000/07/26 13:52:34 perlbug Exp $
#

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	'NAME'		=> 'Perlbug',
        'VERSION_FROM'	=> 'Perlbug.pm',
      # 'PREFIX'	=> 'Perlbug_installation',
        'PREREQ_PM'	=> {
                'Carp'          => 0,
                'CGI'           => 0,
                'DBI'           => 0,
                'Data::Dumper'  => 0,
                'FileHandle'    => 0,
                'File::Spec'	=> 0,
				'HTML::Entities'=> 0,
				'IO::File'      => 0,
                'Mail::Internet'=> 0,
                'Mail::Address' => 0,
                'Mail::Send'    => 0,
                'Mysql'         => 0,
                'Shell'         => 0,
                'Sys::Hostname' => 0,
        },
);
