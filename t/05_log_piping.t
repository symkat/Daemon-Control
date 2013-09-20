#!/usr/bin/perl
use warnings;
use strict;

use Test::More;
use File::Temp;

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
if ( -f 't/bin/05_log_piping.t' ) { # Dist Directory.
    $file = "t/bin/05_log_piping.t";
    $ilib = "lib";
} elsif ( -f 'bin/05_log_piping.t' ) {
    $file = "bin/05_log_piping.t";
    $ilib = "../lib";
} else {
    die "Tests should be run in the dist directory or t/";
}

my $pid_temp_file    = File::Temp->new(UNLINK => 0);
my $stdout_temp_file = File::Temp->new(UNLINK => 0);
my $stderr_temp_file = File::Temp->new(UNLINK => 0);

my $pid_temp_filename    = $pid_temp_file->filename;
my $stdout_temp_filename = $stdout_temp_file->filename;
my $stderr_temp_filename = $stderr_temp_file->filename;

# diag "\$stdout_temp_filename: $stdout_temp_filename";
# diag "\$stderr_temp_filename: $stderr_temp_filename";

ok(system("$^X -I$ilib $file start $pid_temp_filename $stdout_temp_filename $stderr_temp_filename") == 0, "Started perl daemon");

# sleep 2 seconds, checking each 0.1 second for output from the daemon
# hopefully that's long enough to start up and finish. the alternative
# is that we actually use pid files, etc

my $pid;

foreach (1 .. 20) {
    # -f $stdout_temp_filename && -s _ and -f $stderr_temp_filename && -s _ and last;

    $pid_temp_file->seek(0, 0);

    chomp( $pid = <$pid_temp_file> );

    # diag "checking spawned pid $pid";

    if ($pid) {
        kill 0, $pid or last;
    }

    select undef, undef, undef, 0.1;
}

die "child process [$pid] still running, is it frozen?" if $pid and kill(0, $pid);

$stdout_temp_file->seek(0, 0);
$stderr_temp_file->seek(0, 0);

chomp(my $captured_stdout = <$stdout_temp_file>);
chomp(my $captured_stderr = <$stderr_temp_file>);

unlink $pid_temp_file->filename;
unlink $stdout_temp_file->filename;
unlink $stderr_temp_file->filename;

undef $pid_temp_file;
undef $stdout_temp_file;
undef $stderr_temp_file;

is( $captured_stdout, 'I am in here', 'test stdout_pipe' );
is( $captured_stderr, 'Te Occidere Possunt Sed Te Edere Non Possunt Nefas Est', 'test stderr_pipe' );

done_testing;
