#!/usr/bin/perl
use warnings;
use strict;

use lib './t/lib';

use Daemon::Control;

Daemon::Control->with_plugins( qw( +Daemon::Control::Plugin::Help ) )->new({
    name        => "My Daemon",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',

    program     => sub { sleep $_[1] },
    program_args => [ 10 ],

    pid_file    => 'pid_tmp',
    stderr_file => '/dev/null',
    stdout_file => '/dev/null',

    fork        => 1,

    help        => 'some test help',

})->run;
