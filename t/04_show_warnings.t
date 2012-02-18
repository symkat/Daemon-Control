#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
my $stub = "04_show_warnings.pl";

if ( -f "t/bin/$stub" ) { # Dist Directory.
    $file = "t/bin/$stub";
    $ilib = "lib";
} elsif ( -f "bin/$stub" ) {
    $file = "bin/$stub";
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

ok $out = get_command_output( "perl -I$ilib $file show_warnings 2>&1" ), "Get warnings";

ok $out eq do { local $/; <DATA> }, "Got warnings.";

done_testing;
__DATA__
stdout_file undefined.  Will not redirect file handle.
stderr_file undefined.  Will not redirect file handle.
