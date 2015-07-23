use inc::Module::Install;
  
# Define metadata
name           'Daemon-Control';
all_from       'lib/Daemon/Control.pm';
license        'perl';

# uses Module::Install::Repository
build_requires 'Module::Install::Repository' => 0;
auto_set_repository;

# Specific dependencies
requires       'File::Spec'     => '0';
requires       'POSIX'          => '0';
requires       'Cwd'            => '0';
requires       'File::Path'     => '2.08';
recommends     'Role::Tiny'     => 0;

test_requires  'Test::More'     => '0.88';
WriteAll;
