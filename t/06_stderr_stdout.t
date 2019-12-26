#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use File::Temp;

# enable coverage for get_command_output() commands
$ENV{'PERL5OPT'} = '-MDevel::Cover';

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
my $daemon = '05_stderr_stdout.pl';
if ( -f "t/bin/$daemon" ) { # Dist Directory.
    $file = "t/bin/$daemon";
    $ilib = "lib";
} elsif ( -f "bin/$daemon" ) {
    $file = "bin/$daemon";
    $ilib = "../lib";
} else {
    die "Tests should be run in the dist directory or t/";
}

sub get_command_output {
    my ( @command ) = @_;
    open my $lf, "-|", @command
        or die "Couldn't get pipe to '@command': $!";
    my $content = do { local $/; <$lf> };
    close $lf;
    return $content;
}

{
    diag 'Test STDOUT and STDERR when we use plain strings as arguments';
    my $out;
    my $stdout = File::Temp->new; # object stringifies to the filename
    my $stderr = File::Temp->new;
    my $cmd = "$^X -I$ilib $file $stdout $stderr";

    ok $out = get_command_output("$cmd start"), "Started perl daemon";
    like $out, qr/\[Started\]/, "Daemon started.";

    sleep 2; # chill out for a bit, or we might miss writes to files

    ok $out
    = get_command_output("$cmd status" ), "Get status of system daemon.";
    like $out, qr/\[Not Running\]/, "Daemon is stopped.";

    # Check data written by the daemon
    open my $fh, '<', $stdout
        or die "Failed to open stdout file ($stdout) for inspection: $!";
    like do { local $/; <$fh>; }, qr/STDOUT output success/,
        "STDOUT file contains expected data";

    open $fh, '<', $stderr
        or die "Failed to open stderr file ($stderr) for inspection: $!";

    is do { local $/; <$fh>; }, "STDERR output success\n",
        "STDERR file contains expected data";

}

{
    diag 'Test STDOUT and STDERR when we use custom arrayrefs as arguments';
    # We're passing 'custom' argument so our daemon knows to use arrayrefs
    # Consult the code of the daemon for details

    my $out;
    my $stdout = File::Temp->new; # object stringifies to the filename
    my $stderr = File::Temp->new;
    my $cmd = "$^X -I$ilib $file custom $stdout $stderr";

    ok $out = get_command_output("$cmd start"), "Started perl daemon";
    like $out, qr/\[Started\]/, "Daemon started.";

    sleep 2; # chill out for a bit, or we might miss writes to files

    ok $out
    = get_command_output("$cmd status" ), "Get status of system daemon.";
    like $out, qr/\[Not Running\]/, "Daemon is stopped.";


    # Check daemon's first write
    open my $fh, '<', $stdout
        or die "Failed to open stdout file ($stdout) for inspection: $!";
    like do { local $/; <$fh>; }, qr/STDOUT output success/,
        "STDOUT file contains expected data";

    open $fh, '<', $stderr
        or die "Failed to open stderr file ($stderr) for inspection: $!";

    is do { local $/; <$fh>; }, "STDERR output success\n",
        "STDERR file contains expected data";


    # Restart so we'd get a second STD[OUT|ERR] write
    ok $out
    = get_command_output("$cmd start"), "Get status of system daemon.";
    like $out, qr/\[Started\]/s, "Daemon restarted.";

    sleep 2; # chill out for a bit, or we might miss writes to files

    ok $out
    = get_command_output("$cmd status" ), "Get status of system daemon.";
    like $out, qr/\[Not Running\]/, "Daemon is stopped.";

    # Check daemon's second write
    open $fh, '<', $stdout
        or die "Failed to open stdout file ($stdout) for inspection: $!";
    like do { local $/; <$fh>; },
        qr/^STDOUT output success(?!.*STDOUT output success)/s,
        "STDOUT file contains expected data";

    open $fh, '<', $stderr
        or die "Failed to open stderr file ($stderr) for inspection: $!";

    like do { local $/; <$fh>; },
        qr/^STDERR output success(?!.*STDERR output success)/s,
        "STDERR file contains expected data";
}

unlink 'pid_tmp';

done_testing;


