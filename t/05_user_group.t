#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

use Daemon::Control;

# Make sure the user and group don't exist
my $user = 'bogus1';
$user++ while getpwnam( $user );

my $group = 'bogus1';
$group++ while getgrnam( $group );

my $dc = eval { Daemon::Control->new({
    name        => "My Daemon",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'My Daemon Short',
    lsb_desc    => 'My Daemon controls the My Daemon daemon.',
    path        => '/usr/sbin/mydaemon/init.pl',

    program     => sub { sleep shift },
    program_args => [ 10 ],

    user        => $user,
    group       => $group,

    pid_file    => '/tmp/mydaemon.pid',
    stderr_file => '/dev/null',
    stdout_file => '/dev/null',

}) };

isa_ok( $dc, 'Daemon::Control' );

for my $method (qw(do_help do_show_warnings do_get_init_file)) {
    local( *STDOUT, *STDERR );
    my ($stdout, $stderr) = ("", "");
    open( STDOUT, '>', \$stdout ) or die "can't redirect stdout: $!";
    open( STDERR, '>', \$stderr ) or die "can't redirect stderr: $!";
    eval { $dc->$method };
    is( $@, "", "calling $method with bogus user + group lives" );
    isnt( $method =~ /warnings/ ? $stderr : $stdout, "",
          "calling $method with bogus user + group generates output" );
}

for my $method (qw(uid gid)) {
    eval { $dc->$method };
    like( $@, qr/Couldn't get $method for non-existent (?:user|group)/,
          "getting $method with bogus user + group dies" );
}

done_testing;
