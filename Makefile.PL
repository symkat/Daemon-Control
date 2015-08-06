use inc::Module::Install;

# Define metadata
name           'Daemon-Control';
all_from       'lib/Daemon/Control.pm';
license        'perl';

# uses Module::Install::Repository
auto_set_repository;

resources
    bugtracker => 'http://github.com/symkat/Daemon-Control/issues',
    IRC        => 'irc://irc.freenode.org/#perl-daemon-control';

# Specific dependencies
requires       'File::Spec'     => '0';
requires       'POSIX'          => '0';
requires       'Cwd'            => '0';
requires       'File::Path'     => '2.08';

test_requires  'Test::More'     => '0.88';
test_requires  'File::Temp'     => '0.14';

WriteAll;
