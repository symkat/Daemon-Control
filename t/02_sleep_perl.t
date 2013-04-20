#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
if ( -f 't/bin/02_sleep_perl.pl' ) { # Dist Directory.
    $file = "t/bin/02_sleep_perl.pl";
    $ilib = "lib";
} elsif ( -f 'bin/02_sleep_perl.pl' ) {
    $file = "bin/02_sleep_perl.pl";
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

my $out;

ok $out = get_command_output( "perl -I$ilib $file start" ), "Started perl daemon";
like $out, qr/\[Started\]/, "Daemon started.";
ok $out = get_command_output( "perl -I$ilib $file status" ), "Get status of perl daemon.";
like $out, qr/\[Running\]/, "Daemon running.";

sleep 10;

ok $out = get_command_output( "perl -I$ilib $file status" ), "Get status of perl daemon.";
like $out, qr/\[Not Running\]/, "Daemon not running";

# Testing restart.
ok $out = get_command_output( "perl -I$ilib $file start" ), "Started system daemon";
like $out, qr/\[Started\]/, "Daemon started for restarting.";
ok $out = get_command_output( "perl -I$ilib $file status" ), "Get status of system daemon.";
like $out, qr/\[Running\]/, "Daemon running for restarting.";
ok $out = get_command_output( "perl -I$ilib $file restart" ), "Get status of system daemon.";
like $out, qr/\[Stopped\].*\[Started\]/s, "Daemon restarted.";
ok $out = get_command_output( "perl -I$ilib $file status" ), "Get status of system daemon.";
like $out, qr/\[Running\]/, "Daemon running after restart.";
ok $out = get_command_output( "perl -I$ilib $file stop" ), "Get status of system daemon.";
like $out, qr/\[Stopped\]/, "Daemon stopped after restart.";

done_testing;
