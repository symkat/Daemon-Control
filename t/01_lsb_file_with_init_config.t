#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

my ( $file, $ilib );

# Let's make it so people can test in t/ or in the dist directory.
if ( -f 't/bin/01_lsb_02.pl' ) { # Dist Directory.
    $file = "t/bin/01_lsb_02.pl";
    $ilib = "lib";
} elsif ( -f 'bin/01_lsb_02.pl' ) {
    $file = "bin/01_lsb_02.pl";
    $ilib = "../lib";
} else {
    die "Tests should be run in the dist directory or t/";
}


open my $lf, "-|", "perl", "-I$ilib", $file, "get_init_file"
    or die "Failed to open pipe to $file: $!";
my $content = do { local $/; <$lf> };
close $lf;

my $content_expected = do { local $/; <DATA> };

is $content, $content_expected, "LSB File Generation Works.";

done_testing;

__DATA__
#!/bin/sh

### BEGIN INIT INFO
# Provides:          My Daemon
# Required-Start:    $syslog $remote_fs
# Required-Stop:     $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: My Daemon Short
# Description:       My Daemon controls the My Daemon daemon.
### END INIT INFO`

[ -r /etc/default/my_program ] && . /etc/default/my_program

if [ -x /usr/sbin/mydaemon/init.pl ];
then
    /usr/sbin/mydaemon/init.pl $1
else
    echo "Required program /usr/sbin/mydaemon/init.pl not found!"
    exit 1;
fi
