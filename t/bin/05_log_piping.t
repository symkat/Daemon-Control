#!/usr/bin/perl
use warnings;
use strict;
use Daemon::Control;

my ($pid_file, $stdout_temp_file, $stderr_temp_file);

if ( @ARGV == 4 ) {
  ($pid_file, $stdout_temp_file, $stderr_temp_file) = splice(@ARGV, -3);
}

die "bad stdout_temp_file [$stdout_temp_file]" unless $stdout_temp_file and -f $stdout_temp_file;
die "bad stderr_temp_file [$stderr_temp_file]" unless $stderr_temp_file and -f $stderr_temp_file;

Daemon::Control->new({
    name        => "My Daemon",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',

    program     => sub {
        print STDOUT "I am in here\n";
        print STDERR "Te Occidere Possunt Sed Te Edere Non Possunt Nefas Est\n";
    },

    pid_file    => $pid_file,
    stdout_pipe => "cat > $stdout_temp_file",
    stderr_pipe => "cat > $stderr_temp_file",

    fork        => 2,

})->run;
