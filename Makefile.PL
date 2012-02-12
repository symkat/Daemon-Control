use inc::Module::Install;
  
# Define metadata
name           'Daemon-Control';
all_from       'lib/Daemon/Control.pm';
license        'perl';

# Specific dependencies
requires       'File::Spec'     => '0';
requires       'POSIX'          => '0';

WriteAll;
