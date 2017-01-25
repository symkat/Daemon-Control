#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

# enable coverage for get_command_output() commands
$ENV{'PERL5OPT'} = '-MDevel::Cover';

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
if ( -f 't/bin/02_sleep_perl_foreground.pl' ) { # Dist Directory.
    $file = "t/bin/02_sleep_perl_foreground.pl";
    $ilib = "lib";
} elsif ( -f 'bin/02_sleep_perl_foreground.pl' ) {
    $file = "bin/02_sleep_perl_foreground.pl";
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

$out = get_command_output( "$^X -I$ilib $file foreground" );
like $out, qr//, "Daemon started quiet.";

sleep 10;

ok $out = get_command_output( "$^X -I$ilib $file status" ), "Get status of perl daemon.";
like $out, qr/\[Not Running\]/, "Daemon not running";

# Testing restart.
ok $out = get_command_output( "$^X -I$ilib $file start" ), "Started system daemon";
like $out, qr/\[Started\]/, "Daemon started for restarting.";

done_testing;
