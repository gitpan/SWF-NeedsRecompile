use Module::Build;
Module::Build->new(
   module_name => 'SWF::NeedsRecompile',
   license => 'perl',
   build_requires => {
      'Test::More'               => 0,
   },
)->create_build_script;
