#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;

my $custom = $ARGV[0] eq 'custom' ? shift : undef;
my $stdout = shift;
my $stderr = shift;

Daemon::Control->new({
    name        => "My Daemon",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',

    program     => sub {
        print STDOUT "STDOUT output success\n";
        print STDERR "STDERR output success\n";
    },

    pid_file    => 'pid_tmp',
    stderr_file => ($custom ? [ '>', $stderr ] : $stderr),
    stdout_file => ($custom ? [ "> $stdout"  ] : $stdout),

    fork        => 2,
})->run;


