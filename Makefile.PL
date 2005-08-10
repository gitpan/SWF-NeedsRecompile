use ExtUtils::MakeMaker;
WriteMakefile(
   'NAME'		=> 'SWF::NeedsRecompile',
   'VERSION_FROM'	=> 'lib/SWF/NeedsRecompile.pm',
   'PREREQ_PM'	=> {
      'Test::More'               => '0.01',
   },
   'PL_FILES'        => {},
   ($] >= 5.005 ?
    (ABSTRACT_FROM => 'lib/SWF/NeedsRecompile.pm',
     AUTHOR     => 'Clotho Advanced Media Inc., <cpan@clotho.com>') : ()),
);
