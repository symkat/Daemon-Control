package Daemon::Control::Plugin::Help;

use strict;
use warnings;

use Class::Method::Modifiers qw();
use Role::Tiny;

around 'help' => sub {
    my $orig = shift;
    print ucfirst( $orig->(@_) );
    return 0;
};

1;
