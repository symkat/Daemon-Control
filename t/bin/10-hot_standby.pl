#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;

my ($path) = $0 =~ m{(.*/)};
my $script = $path . '10-hot_standby_daemon.sh';

Daemon::Control->new({
    name        => "My Daemon",
    with_plugins => 'hot_standby',
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',

    program     => $script,
    program_args => [ 10 ],

    pid_file    => '/tmp/hotstandby_pid',

    stderr_file => '/tmp/test_hot_standby_err',
    stdout_file => '/tmp/test_hot_standby_out',

    fork        => 2,

})->run;
