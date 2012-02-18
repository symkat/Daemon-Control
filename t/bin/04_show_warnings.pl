#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;

Daemon::Control->new({
    name        => "My Daemon",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',

    program     => sub { 1 }, 
    program_args => [ ],

    redirect_before_fork => 0,
    pid_file    => '/dev/null', # I don't want to leave tmp files for testing.

    fork        => 2,

})->run;
