# NAME

Daemon::Control - Create init scripts in Perl

# DESCRIPTION

Daemon::Control provides a library for creating init scripts in perl.
Your perl script just needs to set the accessors for what and how you
want something to run and the library takes care of the rest.

You can launch programs through the shell (`/usr/sbin/my_program`) or
launch Perl code itself into a daemon mode.  Single and double fork
methods are supported, and in double-fork mode all the things you would
expect such as reopening STDOUT/STDERR, switching UID/GID etc are supported.

# SYNOPSIS

Write a program that describes the daemon:

    #!/usr/bin/perl
    use warnings;
    use strict;
    use Daemon::Control;

    Daemon::Control->new({
        name        => "My Daemon",
        lsb_start   => '$syslog $remote_fs',
        lsb_stop    => '$syslog',
        lsb_sdesc   => 'My Daemon Short',
        lsb_desc    => 'My Daemon controls the My Daemon daemon.',
        path        => '/home/symkat/etc/init.d/program',

        program     => '/home/symkat/bin/program',
        program_args => [ '-a', 'orange', '--verbose' ],

        pid_file    => '/tmp/mydaemon.pid',
        stderr_file => '/tmp/mydaemon.out',
        stdout_file => '/tmp/mydaemon.out',

        fork        => 2,

    })->run;

You can then call the program:

    /home/symkat/etc/init.d/program start

You can also make an LSB compatible init script:

    /home/symkat/etc/init.d/program get_init_file > /etc/init.d/program

# CONSTRUCTOR

The constuctor takes the following arguments.

## name

The name of the program the daemon is controlling.  This will be used in
status messages "name \[Started\]" and the name for the LSB init script
that is generated.

## program

This can be a coderef or the path to a shell program that is to be run.

    $daemon->program( sub { ... } );

    $daemon->program( "/usr/sbin/http" );

## program\_args

This is an array ref of the arguments for the program.  In the context
of a coderef being executed this will be given to the coderef as @\_,
the Daemon::Control instance that called the coderef will be passed
as the first arguments.  Your arguments start at $\_\[1\].

In the context of a shell program, it will be given as arguments to
be executed.

    $daemon->program_args( [ 'foo', 'bar' ] );

    $daemon->program_args( [ '--switch', 'argument' ] );

## user

When set, the username supplied to this accessor will be used to set
the UID attribute.  When this is used, `uid` will be changed from
its inital settings if you set it (which you shouldn't, since you're
using usernames instead of UIDs).  See ["uid"](#uid) for setting numerical
user ids.

    $daemon->user('www-data');

## group

When set, the groupname supplied to this accessor will be used to set
the GID attribute.  When this is used, `gid` will be changed from
its inital settings if you set it (which you shouldn't, since you're
using groupnames instead of GIDs).  See ["gid"](#gid) for setting numerical
group ids.

    $daemon->group('www-data');

## uid

If provided, the UID that the program will drop to when forked.  This is
ONLY supported in double-fork mode and will only work if you are running
as root. Accepts numeric UID.  For usernames please see ["user"](#user).

    $daemon->uid( 1001 );

## gid

If provided, the GID that the program will drop to when forked.  This is
ONLY supported in double-fork mode and will only work if you are running
as root. Accepts numeric GID, for groupnames please see ["group"](#group).

    $daemon->gid( 1001 );

## umask

If provided, the umask of the daemon will be set to the umask provided,
note that the umask must be in oct.  By default the umask will not be
changed.

    $daemon->umask( 022 );
    

Or:

    $daemon->umask( oct("022") );

## directory

If provided, chdir to this directory before execution.

## path

The path of the script you are using Daemon::Control in.  This will be used in 
the LSB file genration to point it to the location of the script.  If this is
not provided, the absolute path of $0 will be used.

## init\_config

The name of the init config file to load.  When provided your init script will
source this file to include the environment variables.  This is useful for setting
a `PERL5LIB` and such things.

    $daemon->init_config( "/etc/default/my_program" );

If you are using perlbrew, you probably want to set your init\_config to
`$ENV{PERLBREW_ROOT} . '/etc/bashrc'`.

## init\_code

When given, whatever text is in this field will be dumped directly into
the generated init file.

    $daemon->init_code( "Arbitrary code goes here." )

## help

Any text in this accessor will be printed when the script is called
with the argument `--help` or <help>.

    $daemon->help( "Read The Friendly Source." );

## redirect\_before\_fork

By default this is set to true.  STDOUT will be redirected to `stdout_file`,
and STDERR will be redirected to `stderr_file`.  Setting this to 0 will disable
redirecting before a double fork.  This is useful when you are using a code
reference and would like to leave the filehandles alone until you're in control.

Call `-`redirect\_filehandles> on the Daemon::Control instance your coderef is
passed to redirect the filehandles.

## stdout\_file

If provided stdout will be redirected to the given file.  This is only supported
in double fork mode.

    $daemon->stdout_file( "/tmp/mydaemon.stdout" );

## stderr\_file

If provided stderr will be redirected to the given file.  This is only supported
in double fork mode.

    $daemon->stderr_file( "/tmp/mydaemon.stderr" );

## pid\_file

The location of the PID file to use.  Warning: if using single-fork mode, it is
recommended to set this to the file which the daemon launching in single-fork
mode will put its PID.  Failure to follow this will most likely result in status,
stop, and restart not working.

    $daemon->pid_file( "/var/run/mydaemon/mydaemon.pid" );

## resource\_dir

This directory will be created, and chowned to the user/group provided in
`user`, and `group`.

    $daemon->resource_dir( "/var/run/mydaemon" );

## fork

The mode to use for fork.  By default a double-fork will be used.

In double-fork, uid, gid, std\*\_file, and a number of other things are
supported.  A traditional double-fork is used and setsid is called.

In single-fork none of the above are called, and it is the responsiblity
of whatever you're forking to reopen files, associate with the init process
and do all that fun stuff.  This mode is recommended when the program you want
to control has its own daemonizing code.  It is important to note that the PID
file should be set to whatever PID file is used by the daemon.

    $daemon->fork( 1 );

    $daemon->fork( 2 ); # Default

## scan\_name

This provides an extra check to see if the program is running.  Normally
we only check that the PID listed in the PID file is running.  When given
a regular expression, we will also match the name of the program as shown
in ps.

    $daemon->scan_name( qr|mydaemon| );

## kill\_timeout

This provides an amount of time in seconds between kill signals being
sent to the daemon.  This value should be increased if your daemon has
a longer shutdown period.  By default 1 second is used.

    $daemon->kill_timeout( 7 );

## lsb\_start

The value of this string is used for the 'Required-Start' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

    $daemon->lsb_start( '$remote_fs $syslog' );

## lsb\_stop

The value of this string is used for the 'Required-Stop' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

    $daemon->lsb_stop( '$remote_fs $syslog' );

## lsb\_sdesc

The value of this string is used for the 'Short-Description' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

    $daemon->lsb_sdesc( 'Mah program...' );

## lsb\_desc

The value of this string is used for the 'Description' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

    $daemon->lsb_desc( 'My program controls a thing that does a thing.' );

# METHODS

## run

This will make your program act as an init file, accepting input from
the command line.  Run will exit with either 1 or 0, following LSB files on
exiting.  As such no code should be used after ->run is called.  Any code
in your file should be before this.

## do\_start

Is called when start is given as an argument.  Starts the forking and
exits. Called by:

    /usr/bin/my_program_launcher.pl start

## do\_stop

Is called when stop is given as an argument.  Stops the running program
if it can. Called by:

    /usr/bin/my_program_launcher.pl stop

## do\_restart

Is called when restart is given as an argument.  Calls do\_stop and do\_start.
Called by:

    /usr/bin/my_program_launcher.pl restart

## do\_reload

Is called when reload is given as an argument.  Sends a HUP signal to the 
daemon.

    /usr/bin/my_program_launcher.pl reload

## do\_status

Is called when status is given as an argument.  Displays the status of the
program, basic on the PID file. Called by:

    /usr/bin/my_program_launcher.pl status

## do\_get\_init\_file

Is called when get\_init\_file is given as an argument.  Dumps an LSB
compatible init file, for use in /etc/init.d/. Called by:

    /usr/bin/my_program_launcher.pl get_init_file

## pretty\_print

This is used to display status to the user.  It accepts a message and a color.
It will default to green text, if no color is explictly given.  Only supports
red and green.

    $daemon->pretty_print( "My Status", "red" );

## write\_pid

This will write the PID to the file in pid\_file.

## read\_pid

This will read the PID from the file in pid\_file and set it in pid.

## pid

An accessor for the PID.  Set by read\_pid, or when the program is started.

## dump\_init\_script

A function to dump the LSB compatible init script.  Used by do\_get\_init\_file.

# AUTHOR

Kaitlyn Parkhurst (SymKat) _<symkat@symkat.com>_ ( Blog: [http://symkat.com/](http://symkat.com/) )

## CONTRIBUTORS

- Matt S. Trout (mst) \_<mst@shadowcat.co.uk>\_
- Mike Doherty (doherty) \_<doherty@cpan.org>\_
- Karen Etheridge (ether) \_<ether@cpan.org>\_

# COPYRIGHT

Copyright (c) 2012 the Daemon::Control ["AUTHOR"](#AUTHOR) and ["CONTRIBUTORS"](#CONTRIBUTORS) as listed above.

# LICENSE 

This library is free software and may be distributed under the same terms as perl itself.

## AVAILABILITY

The most current version of Daemon::Control can be found at [https://github.com/symkat/Daemon-Control](https://github.com/symkat/Daemon-Control)