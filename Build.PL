use Module::Build;
Module::Build->new(
   module_name => 'SWF::NeedsRecompile',
   dist_author => 'Clotho Advanced Media, Inc. <cpan@clotho.com>',
   license => 'perl',
   requires => {
      'File::Slurp' => 9999.09,
      'Regexp::Common' => 2.120,
   },
   build_requires => {
      'Test::More' => 0,
   },
   add_to_cleanup => [ 'SWF-NeedsRecompile-*' ],
)->create_build_script;
