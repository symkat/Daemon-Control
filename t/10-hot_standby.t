#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
if ( -f 't/bin/10-hot_standby.pl' ) { # Dist Directory.
    $file = "t/bin/10-hot_standby.pl";
    $ilib = "lib";
} elsif ( -f 'bin/10-hot_standby.pl' ) {
    $file = "bin/10-hot_standby.pl";
    $ilib = "../lib";
} else {
    die "Tests should be run in the dist directory or t/";
}
use lib $ilib;


sub get_command_output {
    my ( @command ) = @_;
    open my $lf, "-|", @command
        or die "Couldn't get pipe to '@command': $!";
    my $content = do { local $/; <$lf> };
    close $lf;
    return $content;
}

my $out;

ok $out = get_command_output( "$^X -I$ilib $file start" ), "Started system daemon";
like $out, qr/\[Started\]/, "Daemon started.";
ok $out = get_command_output( "$^X -I$ilib $file status" ), "Get status of system daemon.";
like $out, qr/\[Running\]/, "Daemon running.";
ok $? >> 8 == 0, "Exit Status = 0";
sleep 10;
ok $out = get_command_output( "$^X -I$ilib $file stop" ), "Stop daemon and get status.";
ok $out = get_command_output( "$^X -I$ilib $file status" ), "Get status of system daemon.";
like $out, qr/\[Not Running\]/, "Daemon not running.";
ok $? >> 8 == 3, "Exit Status = 3";

# Testing restart.
ok $out = get_command_output( "$^X -I$ilib $file start" ), "Started system daemon";
like $out, qr/\[Started\]/, "Daemon started for restarting";
ok $out = get_command_output( "$^X -I$ilib $file status" ), "Get status of system daemon.";
like $out, qr/\[Running\]/, "Daemon running for restarting.";
ok $out = get_command_output( "$^X -I$ilib $file restart" ), "Get status of system daemon.";
like $out, qr/\[Found existing.*\[Started\]/ms, "Daemon restarted.";
ok $out = get_command_output( "$^X -I$ilib $file status" ), "Get status of system daemon.";
like $out, qr/\[Running\]/, "Daemon running after restart.";
ok $out = get_command_output( "$^X -I$ilib $file stop" ), "Get status of system daemon.";
like $out, qr/\[Stopped\]/, "Daemon stopped after restart.";

done_testing;
