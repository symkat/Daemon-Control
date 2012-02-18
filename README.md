# NAME

Daemon::Control - Create init scripts in Perl

# DESCRIPTION

Daemon::Control provides a library for creating init scripts in perl.
Your perl script just needs to set the accessors for what and how you
want something to run and the library takes care of the rest.

You can launch programs through the shell (/usr/sbin/my_program) or
launch Perl code itself into a daemon mode.  Single and double fork
methods are supported and in double-fork mode all the things you would
expect like reopening STDOUT/STDERR, switching UID/GID are supported.

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

You can also make an LSB compatable init script:

    /home/symkat/etc/init.d/program get_init_file > /etc/init.d/program

# CONSTRUCTURE

The constucture takes the following arguments.

## name

The name of the program the daemon is controlling.  This will be used in
status messages "name [Started]" and the name for the LSB init script
that is generated.

## program

This can be a coderef or the path to a shell program that is to be run.

$daemon->program( sub { ... } );

$daemon->program( "/usr/sbin/http" );

## program_args

This is an array ref of the arguments for the program.  In the context
of a coderef being executed this will be given to the coderef as @_,
the Daemon::Control instance that called the coderef will be passed
as the first arguments.  Your arguments start at $_[1].

In the context of a shell program, it will be given as arguments to
be executed.

$daemon->program_args( [ 'foo', 'bar' ] );

$daemon->program_args( [ '--switch', 'argument' ] );

## uid

If provided, the UID that the program will drop to when forked.  This is
ONLY supported in double-fork mode and will only work if you are running
as root.  This takes the numerical UID (grep user /etc/passwd )

$daemon->uid( 1001 );

## gid

If provided, the GID that the program will drop to when forked.  This is
ONLY supported in double-fork mode and will only work if you are running
as root.  This takes the numerical GID ( grep group /etc/groups )

$daemon->gid( 1001 );

## path

The path of the script you are using Daemon::Control in.  This will be used in 
the LSB file genration to point it to the location of the script.  If this is
not provided $0 will be used, which is likely to work only if you use the full
path to execute it when asking for the init script.

## redirect_before_fork

By default this is set true.  STDOUT will be redirected to stdout_file,
STDERR will be redirected to stderr_file.  Setting this to 0 will disable
redriecting before a double fork.  This is useful when you are using a code
ref and would like to leave the file handles alone until you're in control.

Call ->redirect_filehandles on the Daemon::Control instance your coderef is
passed to redirect the filehandles.

## stdout_file

If provided stdout will be redirected to the given file.  This is only supported
in double fork more.

$daemon->stdout_file( "/tmp/mydaemon.stdout" );

## stderr_file

If provided stderr will be redirected to the given file.  This is only supported
in double fork more.

$daemon->stderr_file( "/tmp/mydaemon.stderr" );

## pid_file

The location of the PID file to use.  Warning: if using single-fork mode, it is
recommended to set this to the file which the daemon launching in single-fork
mode will put it's PID.  Failure to follow this will most likely result in status,
stop, and restart not working.

$daemon->pid_file( "/tmp/mydaemon.pid" );

## fork

The mode to use for fork.  By default a double-fork will be used.

In double-fork, uid, gid, std*_file, and a number of other things are
supported.  A traditional double-fork is used and setsid is called.

In single-fork none of the above are called, and it is the responsiblity
of whatever you're forking to reopen files, associate with the init process
and do all that fun stuff.  This mode is recommended when the program you want
to control has it's own daemonizing code.  It is importand to note that the PID
file should be set to whatever PID file is used by the daemon.

$daemon->fork( 1 );

$daemon->fork( 2 ); # Default

## scan_name

This provides an extra check to see if the program is running.  Normally
we only check that the PID listed in the PID file is running.  When given
a regular expression, we will also match the name of the program as shown
in ps.

$daemon->scan_name( qr|mydaemon| );

## lsb_start

The value of this string is used for the 'Required-Start' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

$daemon->lsb_start( '$remote_fs $syslog' );

## lsb_stop

The value of this string is used for the 'Required-Stop' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

$daemon->lsb_stop( '$remote_fs $syslog' );

## lsb_sdesc

The value of this string is used for the 'Short-Description' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

$daemon->lsb_sdesc( 'Mah program...' );



## lsb_desc

The value of this string is used for the 'Description' value of
the generated LSB init script.  See [http://wiki.debian.org/LSBInitScripts](http://wiki.debian.org/LSBInitScripts)
for more information.

$daemon->lsb_desc( 'My program controls a thing that does a thing.' );

# METHODS

## run

This will make your program act as an init file, accepting input from
the command line.  Run will exit either 1 or 0, following LSB files on
exiting.  As such no code should be used after ->run is called.  Any code
in your file should be before this.

## do_start

Is called when start is given as an argument.  Starts the forking, and
exits.

/usr/bin/my_program_launcher.pl start

## do_stop

Is called when stop is given as an argument.  Stops the running program
if it can.

/usr/bin/my_program_launcher.pl stop

## do_restart

Is called when restart is given as an argument.  Calls do_stop and do_start.

/usr/bin/my_program_launcher.pl restart

## do_status

Is called when status is given as an argument.  Displays the status of the
program, basic on the PID file.

/usr/bin/my_program_launcher.pl status

## do_get_init_file

Is called when get_init_file is given as an argument.  Dumps an LSB
compatable init file, for use in /etc/init.d/

/usr/bin/my_program_launcher.pl get_init_file

## pretty_print

This is used to display status to the user.  It accepts a message, and a color.
It will default to green text, if no color is explictly given.  Only supports
red and green.

$daemon->pretty_print( "My Status", "red" );

## write_pid

This will write the PID to the file in pid_file.

## read_pid

This will read the PID from the file in pid_file and set it in pid.

## pid

An accessor for the PID.  Set by read_pid, or when the program is started.

## dump_init_script

A function to dump the LSB compatable init script.  Used by do_get_init_file.

# AUTHOR

SymKat _<symkat@symkat.com>_ ( Blog: [http://symkat.com/](http://symkat.com/) )

## CONTRIBUTORS

Matt S. Trout (mst) _<mst@mst@shadowcat.co.uk>_

# COPYRIGHT

Copyright (c) 2012 the Daemon::Control ["AUTHOR"](#AUTHOR) and ["CONTRIBUTORS"](#CONTRIBUTORS) as listed above.

# LICENSE 

This library is free software and may be distributed under the same terms as perl itself.

## AVAILABILITY

The most current version of Daemon::Control can be found at [https://github.com/symkat/Daemon-Control](https://github.com/symkat/Daemon-Control)