use Module::Build;
Module::Build->new(
   module_name => 'SWF::NeedsRecompile',
   dist_author => 'Clotho Advanced Media, Inc. <cpan@clotho.com>',
   license => 'perl',
   build_requires => {
      'Test::More' => 0,
   },
   add_to_cleanup => [ 'SWF-NeedsRecompile-*' ],
)->create_build_script;
