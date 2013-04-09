#!/usr/bin/env perl

use warnings;
use strict;
use Daemon::Control;

my $program_args = ['-r','/opt/pinto', '-p','3999'];

Daemon::Control->new({
    name        => "My Daemon",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',
    init_config => '/etc/default/my_program',

    program     => sub { sleep shift },
    program_args => $program_args,
    pid_file     => '/tmp/mydaemon.pid',
    stderr_file  => '/dev/null',
    stdout_file  => '/dev/null',
    fork         => 2,
})->run();
