#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;

my ($path) = $0 =~ m{(.*/)};
my $script = $path . '10-hot_standby_daemon.sh';
Daemon::Control->with_plugins('HotStandby')->new({
    name        => "My Daemon",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',
    program     => $script,
    pid_file    => $ENV{DC_TEST_TEMP_FILE} || '/tmp/daemon_control_manual_test_pid',
    stderr_file => '/tmp/test_hot_standby_err',
    stdout_file => '/tmp/test_hot_standby_out',

    fork        => 2,

})->run;
