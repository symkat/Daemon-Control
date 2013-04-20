package Daemon::Control;

use strict;
use warnings;
use POSIX qw(_exit setsid setuid setgid getuid getgid);
use File::Spec;
use File::Path qw( make_path );
use Cwd 'abs_path';
require 5.008001; # Supporting 5.8.1+

our $VERSION = '0.001000'; # 0.1.0
$VERSION = eval $VERSION;

my @accessors = qw(
    pid color_map name program program_args directory
    uid path gid scan_name stdout_file stderr_file pid_file fork data
    lsb_start lsb_stop lsb_sdesc lsb_desc redirect_before_fork init_config
    kill_timeout umask resource_dir help init_code
);

my $cmd_opt = "[start|stop|restart|reload|status|show_warnings|get_init_file|help]";

# Accessor building

for my $method ( @accessors ) {
    my $accessor = sub {
        my $self = shift;
        $self->{$method} = shift if @_;
        return $self->{$method};
    };
    {
        no strict 'refs';
        *$method = $accessor;
    }
}

# As a result of not using a real object system for
# this, I don't get after user => sub { } style things,
# so I'm making my own triggers for user and group.

sub user {
    my ( $self, $user ) = @_;

    if ( $user ) {
        $self->{user} = $user;
        $self->_set_uid_from_name( $user );
    }

    return $self->{user};
}

sub group {
    my ( $self, $group ) = @_;

    if ( $group ) {
        $self->{group} = $group;
        $self->_set_gid_from_name( $group );
    }

    return $self->{group};
}

sub new {
    my ( $class, $args ) = @_;

    # Create the object with defaults.
    my $self = bless {
        color_map               => { red => 31, green => 32 },
        redirect_before_fork    => 1,
        kill_timeout            => 1,
        umask                   => 0,
    }, $class;

    for my $accessor ( @accessors ) {
        if ( exists $args->{$accessor} ) {
            $self->{$accessor} = delete $args->{$accessor};
        }
    }

    # Set the user/groups.
    $self->user(delete $args->{user}) if exists $args->{user};
    $self->group(delete $args->{group}) if exists $args->{group};

    die "Unknown arguments to the constructor: " . join( " ", keys %$args )
        if keys( %$args );

    return $self;
}


# Set the uid, triggered from setting a user string.
sub _set_uid_from_name {
    my ( $self, $name ) = @_;
    my $uid = getpwnam( $name );
    die "Error: Couldn't get uid for non-existent user " . $self->user
        unless $uid;
    $self->trace( "Set UID => $uid" );
    $self->uid( $uid );
}

# Set the uid, triggered from setting a group string.
sub _set_gid_from_name {
    my ( $self, $name ) = @_;
    my $gid = getgrnam( $name );
    die "Error: Couldn't get gid for non-existent group " . $self->group
        unless $gid;
    $self->trace( "Set GID => $gid" );
    $self->gid( $gid );

}

sub redirect_filehandles {
    my ( $self ) = @_;

    if ( $self->stdout_file ) {
        my $file = $self->stdout_file;
        $file = $file eq '/dev/null' ? File::Spec->devnull : $file;
        open STDOUT, ">>", $file
            or die "Failed to open STDOUT to $file: $!";
        $self->trace( "STDOUT redirected to $file" );

    }
    if ( $self->stderr_file ) {
        my $file = $self->stderr_file;
        $file = $file eq '/dev/null' ? File::Spec->devnull : $file;
        open STDERR, ">>", $file
            or die "Failed to open STDERR to $file: $!";
        $self->trace( "STDERR redirected to $file" );
    }
}

sub _create_resource_dir {
    my ( $self ) = @_;
    $self->_create_dir($self->resource_dir);
}

sub _create_dir {
    my ( $self, $dir ) = @_;

    return 0 unless defined $dir;
    return 1 unless length($dir);

    if ( -d $dir ) {
        $self->trace( "Dir exists (" . $dir . ") - no need to create" );
        return 1;
    }

    my ( $created ) = make_path(
        $dir,
        {
            uid => $self->uid,
            group => $self->gid,
            error => \my $errors,
        }
    );

    if ( @$errors ) {
        for my $error ( @$errors ) {
            my ( $file, $msg ) = %$error;
            die "Error creating $file: $msg";
        }
    }

    if ( $created eq $dir ) {
        $self->trace( "Created dir (" . $dir . ")" );
        return 1;
    }

    $self->trace( "_create_dir() for $dir failed and I don't know why" );
    return 0;
}

sub _double_fork {
    my ( $self ) = @_;
    my $pid = fork();

    $self->trace( "_double_fork()" );
    if ( $pid == 0 ) { # Child, launch the process here.
        setsid(); # Become the process leader.
        my $new_pid = fork();
        if ( $new_pid == 0 ) { # Our double fork.

            if ( $self->gid ) {
                setgid( $self->gid );
                $self->trace( "setgid(" . $self->gid . ")" );
            }

            if ( $self->uid ) {
                setuid( $self->uid );

                $ENV{USER} = $self->user || getpwuid($self->uid);
                $ENV{HOME} = ((getpwuid($self->uid))[7]);

                $self->trace( "setuid(" . $self->uid . ")" );
                $self->trace( "\$ENV{USER} => " . $ENV{USER} );
                $self->trace( "\$ENV{HOME} => " . $ENV{HOME} );
            }

            if ( $self->umask ) {
                umask( $self->umask);
                $self->trace( "umask(" . $self->umask . ")" );
            }

            open( STDIN, "<", File::Spec->devnull );

            if ( $self->redirect_before_fork ) {
                $self->redirect_filehandles;
            }

            $self->_launch_program;
        } elsif ( not defined $new_pid ) {
            warn "Cannot fork: $!";
        } else {
            $self->pid( $new_pid );
            $self->trace("Set PID => $new_pid" );
            $self->write_pid;
            _exit 0;
        }
    } elsif ( not defined $pid ) { # We couldn't fork.  =(
        warn "Cannot fork: $!";
    } else { # In the parent, $pid = child's PID, return it.
        waitpid( $pid, 0 );
    }
    return $self;
}

sub _fork {
    my ( $self ) = @_;
    my $pid = fork();

    $self->trace( "_fork()" );
    if ( $pid == 0 ) { # Child, launch the process here.
        $self->_launch_program;
    } elsif ( not defined $pid ) {
        warn "Cannot fork: $!";
    } else { # In the parent, $pid = child's PID, return it.
        # Nothing
    }
    return $self;
}

sub _launch_program {
    my ($self) = @_;

    if ( $self->directory ) {
        chdir( $self->directory );
        $self->trace( "chdir(" . $self->directory . ")" );
    }

    my @args = @{$self->program_args || [ ]};

    if ( ref $self->program eq 'CODE' ) {
        $self->program->( $self, @args );
    } else {
        exec ( $self->program, @args )
            or die "Failed to exec " . $self->program . " "
                . join( " ", @args ) . ": $!";
    }
    exit 0;
}

sub write_pid {
    my ( $self ) = @_;

    # Create the PID file as the user we currently are,
    # and change the permissions to our target UID/GID.

    $self->_write_pid;

    if ( $self->uid && $self->gid ) {
        chown $self->uid, $self->gid, $self->pid_file;
        $self->trace("PID => chown(" . $self->uid . ", " . $self->gid .")");
    }
}

sub _write_pid {
    my ( $self ) = @_;

    my ($volume, $dir, $file) = File::Spec->splitpath($self->pid_file);
    return 0 if not $self->_create_dir($dir);

    open my $sf, ">", $self->pid_file
        or die "Failed to write " . $self->pid_file . ": $!";
    print $sf $self->pid;
    close $sf;
    $self->trace( "Wrote pid (" . $self->pid . ") to pid file (" . $self->pid_file . ")" );
    return $self;
}

sub read_pid {
    my ( $self ) = @_;

    # If we don't have a PID file, we're going to set it
    # to 0 -- this will prevent killing normal processes,
    # and make is_running return false.
    if ( ! -f $self->pid_file ) {
        $self->pid( 0 );
        return 0;
    }

    open my $lf, "<", $self->pid_file
        or die "Failed to read " . $self->pid_file . ": $!";
    my $pid = do { local $/; <$lf> };
    close $lf;
    $self->pid( $pid );
    return $pid;
}

sub pid_running {
    my ( $self ) = @_;

    $self->read_pid;

    return 0 unless $self->pid >= 1;
    return 0 unless kill 0, $self->pid;

    if ( $self->scan_name ) {
        open my $lf, "-|", "ps", "-p", $self->pid, "-o", "command="
            or die "Failed to get pipe to ps for scan_name.";
        while ( my $line = <$lf> ) {
            return 1 if $line =~ $self->scan_name;
        }
        return 0;
    }
    # Scan name wasn't used, testing normal PID.
    return kill 0, $self->pid;
}

sub pretty_print {
    my ( $self, $message, $color ) = @_;

    $color ||= "green"; # Green is no color.
    my $code = $self->color_map->{$color} ||= "32"; # Green is invalid.
    printf( "%-49s %30s\n", $self->name, "\033[$code" ."m[$message]\033[0m" );
}

# Callable Functions

sub do_start {
    my ( $self ) = @_;

    # Make sure the PID file exists.
    if ( ! -f $self->pid_file ) {
        $self->pid( 0 ); # Make PID invalid.
        $self->write_pid();
    }

    # Duplicate Check
    $self->read_pid;
    if ( $self->pid && $self->pid_running ) {
        $self->pretty_print( "Duplicate Running", "red" );
        exit 1;
    }

    $self->_create_resource_dir;

    $self->fork( 2 ) unless $self->fork;
    $self->_double_fork if $self->fork == 2;
    $self->_fork if $self->fork == 1;
    $self->pretty_print( "Started" );
}

sub do_show_warnings {
    my ( $self ) = @_;

    if ( ! $self->fork ) {
        warn "Fork undefined.  Defaulting to fork => 2.\n";
    }

    if ( ! $self->stdout_file ) {
        warn "stdout_file undefined.  Will not redirect file handle.\n";
    }

    if ( ! $self->stderr_file ) {
        warn "stderr_file undefined.  Will not redirect file handle.\n";
    }
}

sub do_stop {
    my ( $self ) = @_;

    $self->read_pid;

    if ( $self->pid && $self->pid_running ) {
        foreach my $signal ( qw(TERM TERM INT KILL) ) {
            $self->trace( "Sending $signal signal to pid ", $self->pid, "..." );
            kill $signal => $self->pid;

            for (1..$self->kill_timeout)
            {
                # abort early if the process is now stopped
                $self->trace('checking if pid ', $self->pid, ' is still running...');
                last if not $self->pid_running;
                sleep 1;
            }
            last unless $self->pid_running;
        }
        if ( $self->pid_running ) {
            $self->pretty_print( "Failed to Stop", "red" );
            exit 1;
        }
        $self->pretty_print( "Stopped" );
    } else {
        $self->pretty_print( "Not Running", "red" );
    }

    # Clean up the PID file on stop.
    unlink($self->pid_file) if $self->pid_file;
}

sub do_restart {
    my ( $self ) = @_;
    $self->read_pid;

    if ( $self->pid_running ) {
        $self->do_stop;
    }
    $self->do_start;
}

sub do_status {
    my ( $self ) = @_;
    $self->read_pid;

    if ( $self->pid && $self->pid_running ) {
        $self->pretty_print( "Running" );
    } else {
        $self->pretty_print( "Not Running", "red" );
    }
}

sub do_reload {
    my ( $self ) = @_;
    $self->read_pid;

    if ( $self->pid && $self->pid_running  ) {
        kill "SIGHUP", $self->pid;
        $self->pretty_print( "Reloaded" );
    } else {
        $self->pretty_print( "Not Running", "red" );
    }
}

sub do_get_init_file {
    shift->dump_init_script;
}

sub do_help {
    my ( $self ) = @_;

    print "Syntax: $0 $cmd_opt\n\n";
    print $self->help if $self->help;
}

sub dump_init_script {
    my ( $self ) = @_;
    if ( ! $self->data ) {
        my $data;
        while ( my $line = <DATA> ) {
            last if $line =~ /^__END__$/;
            $data .= $line;
        }
        $self->data( $data );
    }

    # So, instead of expanding run_template to use a real DSL
    # or making TT a dependancy, I'm just going to fake template
    # IF logic.
    my $init_source_file = $self->init_config
        ? $self->run_template(
            '[ -r [% FILE %] ] && . [% FILE %]',
            { FILE => $self->init_config } )
        : "";

    $self->data( $self->run_template(
        $self->data,
        {
            HEADER            => 'Generated at ' . scalar(localtime)
                . ' with Daemon::Control ' . ($self->VERSION || 'DEV'),
            NAME              => $self->name      ? $self->name      : "",
            REQUIRED_START    => $self->lsb_start ? $self->lsb_start : "",
            REQUIRED_STOP     => $self->lsb_stop  ? $self->lsb_stop  : "",
            SHORT_DESCRIPTION => $self->lsb_sdesc ? $self->lsb_sdesc : "",
            DESCRIPTION       => $self->lsb_desc  ? $self->lsb_desc  : "",
            SCRIPT            => $self->path      ? $self->path      : abs_path($0),
            INIT_SOURCE_FILE  => $init_source_file,
            INIT_CODE_BLOCK   => $self->init_code ? $self->init_code : "",
        }
    ));
    print $self->data;
}

sub run_template {
    my ( $self, $content, $config ) = @_;

    $content =~ s/\[% (.*?) %\]/$config->{$1}/g;

    return $content;
}

# Application Code.
sub run {
    my ( $self ) = @_;

    # Error Checking.
    if ( ! $self->program ) {
        die "Error: program must be defined.";
    }
    if ( ! $self->pid_file ) {
        die "Error: pid_file must be defined.";
    }
    if ( ! $self->name ) {
        die "Error: name must be defined.";
    }

    if ( $self->uid && ! $self->gid ) {
        my ( $gid ) = ( (getpwuid( $self->uid ))[3] );
        $self->gid( $gid );
        $self->trace( "Implicit GID => $gid" );
    }

    my $called_with;
    if (@ARGV) {
        $called_with = shift @ARGV;
        $called_with =~ s/^[-]+//g; # Allow people to do --command too.
    }

    my $action = "do_" . ($called_with ? $called_with : "" );

    my $allowed_actions = "Must be called with an action: $cmd_opt";

    if ( $self->can($action) ) {
        $self->$action;
    } elsif ( ! $called_with  ) {
        die $allowed_actions
    } else {
        die "Error: undefined action $called_with.  $allowed_actions";
    }
    exit 0;
}

sub trace {
    my ( $self, $message ) = @_;

    return unless $ENV{DC_TRACE};

    print "[TRACE] $message\n" if $ENV{DC_TRACE} == 1;
    print STDERR "[TRACE] $message\n" if $ENV{DC_TRACE} == 2;
}

1;

__DATA__
#!/bin/sh

# [% HEADER %]

### BEGIN INIT INFO
# Provides:          [% NAME %]
# Required-Start:    [% REQUIRED_START %]
# Required-Stop:     [% REQUIRED_STOP %]
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: [% SHORT_DESCRIPTION %]
# Description:       [% DESCRIPTION %]
### END INIT INFO`

[% INIT_SOURCE_FILE %]

[% INIT_CODE_BLOCK %]

if [ -x [% SCRIPT %] ];
then
    [% SCRIPT %] $1
else
    echo "Required program [% SCRIPT %] not found!"
    exit 1;
fi
__END__

=head1 NAME

Daemon::Control - Create init scripts in Perl

=head1 DESCRIPTION

Daemon::Control provides a library for creating init scripts in perl.
Your perl script just needs to set the accessors for what and how you
want something to run and the library takes care of the rest.

You can launch programs through the shell (C</usr/sbin/my_program>) or
launch Perl code itself into a daemon mode.  Single and double fork
methods are supported, and in double-fork mode all the things you would
expect such as reopening STDOUT/STDERR, switching UID/GID etc are supported.

=head1 SYNOPSIS

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

=head1 CONSTRUCTOR

The constructor takes the following arguments.

=head2 name

The name of the program the daemon is controlling.  This will be used in
status messages "name [Started]" and the name for the LSB init script
that is generated.

=head2 program

This can be a coderef or the path to a shell program that is to be run.

    $daemon->program( sub { ... } );

    $daemon->program( "/usr/sbin/http" );

=head2 program_args

This is an array ref of the arguments for the program.  In the context
of a coderef being executed this will be given to the coderef as @_,
the Daemon::Control instance that called the coderef will be passed
as the first arguments.  Your arguments start at $_[1].

In the context of a shell program, it will be given as arguments to
be executed.

    $daemon->program_args( [ 'foo', 'bar' ] );

    $daemon->program_args( [ '--switch', 'argument' ] );

=head2 user

When set, the username supplied to this accessor will be used to set
the UID attribute.  When this is used, C<uid> will be changed from
its initial settings if you set it (which you shouldn't, since you're
using usernames instead of UIDs).  See L</uid> for setting numerical
user ids.

    $daemon->user('www-data');

=head2 group

When set, the groupname supplied to this accessor will be used to set
the GID attribute.  When this is used, C<gid> will be changed from
its initial settings if you set it (which you shouldn't, since you're
using groupnames instead of GIDs).  See L</gid> for setting numerical
group ids.

    $daemon->group('www-data');

=head2 uid

If provided, the UID that the program will drop to when forked.  This is
ONLY supported in double-fork mode and will only work if you are running
as root. Accepts numeric UID.  For usernames please see L</user>.

    $daemon->uid( 1001 );

=head2 gid

If provided, the GID that the program will drop to when forked.  This is
ONLY supported in double-fork mode and will only work if you are running
as root. Accepts numeric GID, for groupnames please see L</group>.

    $daemon->gid( 1001 );

=head2 umask

If provided, the umask of the daemon will be set to the umask provided,
note that the umask must be in oct.  By default the umask will not be
changed.

    $daemon->umask( 022 );

Or:

    $daemon->umask( oct("022") );

=head2 directory

If provided, chdir to this directory before execution.

=head2 path

The path of the script you are using Daemon::Control in.  This will be used in
the LSB file generation to point it to the location of the script.  If this is
not provided, the absolute path of $0 will be used.

=head2 init_config

The name of the init config file to load.  When provided your init script will
source this file to include the environment variables.  This is useful for setting
a C<PERL5LIB> and such things.

    $daemon->init_config( "/etc/default/my_program" );

If you are using perlbrew, you probably want to set your init_config to
C<$ENV{PERLBREW_ROOT} . '/etc/bashrc'>.

=head2 init_code

When given, whatever text is in this field will be dumped directly into
the generated init file.

    $daemon->init_code( "Arbitrary code goes here." )

=head2 help

Any text in this accessor will be printed when the script is called
with the argument C<--help> or <help>.

    $daemon->help( "Read The Friendly Source." );

=head2 redirect_before_fork

By default this is set to true.  STDOUT will be redirected to C<stdout_file>,
and STDERR will be redirected to C<stderr_file>.  Setting this to 0 will disable
redirecting before a double fork.  This is useful when you are using a code
reference and would like to leave the filehandles alone until you're in control.

Call C<->redirect_filehandles> on the Daemon::Control instance your coderef is
passed to redirect the filehandles.

=head2 stdout_file

If provided stdout will be redirected to the given file.  This is only supported
in double fork mode.

    $daemon->stdout_file( "/tmp/mydaemon.stdout" );

=head2 stderr_file

If provided stderr will be redirected to the given file.  This is only supported
in double fork mode.

    $daemon->stderr_file( "/tmp/mydaemon.stderr" );

=head2 pid_file

The location of the PID file to use.  Warning: if using single-fork mode, it is
recommended to set this to the file which the daemon launching in single-fork
mode will put its PID.  Failure to follow this will most likely result in status,
stop, and restart not working.

    $daemon->pid_file( "/var/run/mydaemon/mydaemon.pid" );

=head2 resource_dir

This directory will be created, and chowned to the user/group provided in
C<user>, and C<group>.

    $daemon->resource_dir( "/var/run/mydaemon" );

=head2 fork

The mode to use for fork.  By default a double-fork will be used.

In double-fork, uid, gid, std*_file, and a number of other things are
supported.  A traditional double-fork is used and setsid is called.

In single-fork none of the above are called, and it is the responsibility
of whatever you're forking to reopen files, associate with the init process
and do all that fun stuff.  This mode is recommended when the program you want
to control has its own daemonizing code.  It is important to note that the PID
file should be set to whatever PID file is used by the daemon.

    $daemon->fork( 1 );

    $daemon->fork( 2 ); # Default

=head2 scan_name

This provides an extra check to see if the program is running.  Normally
we only check that the PID listed in the PID file is running.  When given
a regular expression, we will also match the name of the program as shown
in ps.

    $daemon->scan_name( qr|mydaemon| );

=head2 kill_timeout

This provides an amount of time in seconds between kill signals being
sent to the daemon.  This value should be increased if your daemon has
a longer shutdown period.  By default 1 second is used.

    $daemon->kill_timeout( 7 );

=head2 lsb_start

The value of this string is used for the 'Required-Start' value of
the generated LSB init script.  See L<http://wiki.debian.org/LSBInitScripts>
for more information.

    $daemon->lsb_start( '$remote_fs $syslog' );

=head2 lsb_stop

The value of this string is used for the 'Required-Stop' value of
the generated LSB init script.  See L<http://wiki.debian.org/LSBInitScripts>
for more information.

    $daemon->lsb_stop( '$remote_fs $syslog' );

=head2 lsb_sdesc

The value of this string is used for the 'Short-Description' value of
the generated LSB init script.  See L<http://wiki.debian.org/LSBInitScripts>
for more information.

    $daemon->lsb_sdesc( 'My program...' );

=head2 lsb_desc

The value of this string is used for the 'Description' value of
the generated LSB init script.  See L<http://wiki.debian.org/LSBInitScripts>
for more information.

    $daemon->lsb_desc( 'My program controls a thing that does a thing.' );

=head1 METHODS

=head2 run

This will make your program act as an init file, accepting input from
the command line.  Run will exit with either 1 or 0, following LSB files on
exiting.  As such no code should be used after ->run is called.  Any code
in your file should be before this.

=head2 do_start

Is called when start is given as an argument.  Starts the forking and
exits. Called by:

    /usr/bin/my_program_launcher.pl start

=head2 do_stop

Is called when stop is given as an argument.  Stops the running program
if it can. Called by:

    /usr/bin/my_program_launcher.pl stop

=head2 do_restart

Is called when restart is given as an argument.  Calls do_stop and do_start.
Called by:

    /usr/bin/my_program_launcher.pl restart

=head2 do_reload

Is called when reload is given as an argument.  Sends a HUP signal to the
daemon.

    /usr/bin/my_program_launcher.pl reload

=head2 do_status

Is called when status is given as an argument.  Displays the status of the
program, basic on the PID file. Called by:

    /usr/bin/my_program_launcher.pl status

=head2 do_get_init_file

Is called when get_init_file is given as an argument.  Dumps an LSB
compatible init file, for use in /etc/init.d/. Called by:

    /usr/bin/my_program_launcher.pl get_init_file

=head2 pretty_print

This is used to display status to the user.  It accepts a message and a color.
It will default to green text, if no color is explicitly given.  Only supports
red and green.

    $daemon->pretty_print( "My Status", "red" );

=head2 write_pid

This will write the PID to the file in pid_file.

=head2 read_pid

This will read the PID from the file in pid_file and set it in pid.

=head2 pid

An accessor for the PID.  Set by read_pid, or when the program is started.

=head2 dump_init_script

A function to dump the LSB compatible init script.  Used by do_get_init_file.

=head1 AUTHOR

=over 4

Kaitlyn Parkhurst (SymKat) I<E<lt>symkat@symkat.comE<gt>> ( Blog: L<http://symkat.com/> )

=back

=head2 CONTRIBUTORS

=over 4

=item * Matt S. Trout (mst) I<E<lt>mst@shadowcat.co.ukE<gt>>

=item * Mike Doherty (doherty) I<E<lt>doherty@cpan.orgE<gt>>

=item * Karen Etheridge (ether) I<E<lt>ether@cpan.orgE<gt>>

=back

=head2 SPONSORS

Parts of this code were paid for by

=over 4

=item (mt) Media Temple L<http://www.mediatemple.net>

=back

=head1 COPYRIGHT

Copyright (c) 2012 the Daemon::Control L</AUTHOR>, L</CONTRIBUTORS>, and L</SPONSORS> as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms as perl itself.

=head2 AVAILABILITY

The most current version of Daemon::Control can be found at L<https://github.com/symkat/Daemon-Control>
