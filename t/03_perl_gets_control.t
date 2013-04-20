#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
if ( -f 't/bin/03_perl_gets_control.pl' ) { # Dist Directory.
    $file = "t/bin/03_perl_gets_control.pl";
    $ilib = "lib";
} elsif ( -f 'bin/03_perl_gets_control.pl' ) {
    $file = "bin/03_perl_gets_control.pl";
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
unlike $out, qr/FAILED/, "Code ref gets Daemon::Control instance.";

done_testing;
