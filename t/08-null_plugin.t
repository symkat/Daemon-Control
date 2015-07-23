#!/usr/bin/env perl
use warnings;
use strict;
BEGIN {
	use Test::More;
	eval 'use Role::Tiny';
	plan skip_all => 'Role::Tiny not installed' if $@;
}

package Daemon::Control::Plugin::Null;
use Role::Tiny;
1;

use Daemon::Control;

for ('Null', '+Daemon::Control::Plugin::Null') {
  my $dc = Daemon::Control->with_plugins($_)->new();
  Test::More::ok(Role::Tiny::does_role($dc, 'Daemon::Control::Plugin::Null'),
     "Plugin role is appplied");
}
Test::More::done_testing;

