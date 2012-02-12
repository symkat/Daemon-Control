#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

use_ok( $_ ) for qw| Daemon::Control File::Spec POSIX |;

done_testing;
