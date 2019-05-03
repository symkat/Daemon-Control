#!/usr/bin/perl
use warnings;
use strict;

use Errno qw(EAGAIN);
use File::Temp qw(tempfile);
use Test::More;

# Simulate failing forks in the Daemon::Control package only
BEGIN {
    *CORE::GLOBAL::fork = sub {
	if ((caller)[0] eq 'Daemon::Control') {
	    $! = EAGAIN;
	    undef;
	} else {
	    CORE::fork;
	}
    };
}

my(undef,$pidfile) = tempfile(SUFFIX => '_Daemon_Control.pid', UNLINK => 1);
my(undef,$outfile) = tempfile(SUFFIX => '_Daemon_Control.txt', UNLINK => 1);
unlink $outfile;

use_ok 'Daemon::Control';

eval {
    Daemon::Control->new(
        name => "failing_fork_test",
        program => "/bin/sh",
        program_args => ['-c', "echo this should not happen > $outfile"],
        pid_file => $pidfile,
        fork => 1,
    )->run_command('start');
};
like $@, qr{Cannot fork};

ok !-e $outfile, 'daemon was not called';

done_testing;
