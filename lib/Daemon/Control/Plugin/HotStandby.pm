package Daemon::Control::Plugin::HotStandby;
use Role::Tiny;

=head2 NAME

Daemon::Control::Plugin::HotStandby

=head2 DESCRIPTION

This is a plugin basically for PSGI workers so that a standby worker
can be spun up prior to terminating the original worker.

Currently it doesn't work

=head2 AUTHOR

Kieren Diment <zarquon@cpan.org>

=cut


around do_restart => sub {
  my $orig = shift;
  my ($self) = @_;

  # check old running
  $self->read_pid;
  my $old_pid = $self->pid;
  if ($self->pid && $self->pid_running) {
    $self->pretty_print("Found existing process");
  }
  else {   #    warn if not
    $self->pretty_print("No process running for hot standby zero downtime", "red");
  }


  $self->_finish_start;
  # Start new get pid.
  $self->read_pid;
  my $new_pid = $self->pid;
  # check new came up.  Die if failed.
  sleep (($self->kill_timeout * 2) + 1);

  $self->do_stop($old_pid) if $old_pid;
  $self->_ensure_pid_file_exists;
  # zzz for a bit to ensure that new is actually up
  # kill old
  # replace old pid with new in pid file.

  

  return 0;
};

1;
