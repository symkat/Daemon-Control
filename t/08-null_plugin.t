#!/usr/bin/env perl
use warnings;
use strict;
package Daemon::Control::Plugin::Null;
use Role::Tiny;
1;

use Daemon::Control;
use Role::Tiny;
use Test::More;
for ('Null', '+Daemon::Control::Plugin::Null') {
  my $dc = Daemon::Control->new(plugins => $_);
  ok(Role::Tiny::does_role($dc, 'Daemon::Control::Plugin::Null'), 
     "Plugin role is appplied");
}
  done_testing;

