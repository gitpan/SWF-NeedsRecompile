use ExtUtils::MakeMaker;
WriteMakefile(
   'NAME'		=> 'SWF::NeedsRecompile',
   'VERSION_FROM'	=> 'lib/SWF/NeedsRecompile.pm',
   'PREREQ_PM'	=> {
      'File::Slurp' => 9999.09,
      'Test::More'               => '0.01',
   },
   'PL_FILES'        => {},
   ($] >= 5.005 ?
    (ABSTRACT_FROM => 'lib/SWF/NeedsRecompile.pm',
     AUTHOR     => 'Clotho Advanced Media Inc., <cpan@clotho.com>') : ()),
);
