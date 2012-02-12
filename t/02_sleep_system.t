#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
if ( -f 't/bin/02_sleep_system.pl' ) { # Dist Directory.
    $file = "t/bin/02_sleep_system.pl";
    $ilib = "lib";
} elsif ( -f 'bin/02_sleep_system.pl' ) {
    $file = "bin/02_sleep_system.pl";
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

ok $out = get_command_output( "perl -I$ilib $file start" ), "Started system daemon";
ok $out =~ /Started/, "Daemon started.";
ok $out = get_command_output( "perl -I$ilib $file status" ), "Get status of system daemon.";
ok $out =~ /Running/, "Daemon running.";

sleep 10;

ok $out = get_command_output( "perl -I$ilib $file status" ), "Get status of system daemon.";
ok $out =~ /Not Running/;

done_testing;
