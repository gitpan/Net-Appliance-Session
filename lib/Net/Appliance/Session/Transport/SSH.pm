package Net::Appliance::Session::Transport::SSH;

use strict;
use warnings FATAL => 'all';

use base 'Net::Appliance::Session::Transport';
use Net::Appliance::Session::Exceptions;
use IO::Pty;
use POSIX;

# ===========================================================================

sub new {
    my $class = shift;
    my %args  = @_;

    my $self = $class->SUPER::new(
        %args,
        Binmode                 => 1,
        Cmd_remove_mode         => 1,
        Output_record_separator => "\r",
        Telnetmode              => 0,
    );

    return $self;
}

# pre-declared 'private' subroutine
sub _spawn_command;

# sets up new pseudo terminal connected to ssh client running in
# a child process.

sub _connect_core {
    my $self = shift;
    my %args = @_;
    $args{SHKC} = 1 if !exists $args{SHKC};

    # start the SSH session, and get a pty for it
    my $pty = _spawn_command(
        '/usr/bin/ssh', '-o',
        ($args{SHKC} ? 'StrictHostKeyChecking=yes'
                     : 'StrictHostKeyChecking=no'),
        '-l', $args{Name},
        $self->host,
    )
        or raise_error 'Unable to launch ssh subprocess';

    # set new pty as Net::Telnet's IO
    $self->fhopen($pty);

    $self->waitfor('/[Pp]assword: ?$/')
        or $self->error('Failed to get login password prompt');

    # cannot cmd() here because sometimes there's a "helpful" login banner
    $self->print($args{Password});
    $self->waitfor($self->prompt)
        or $self->error('Login failed to remote host');

    return $self;
}

# 
# === end of class methods, rest is just support subroutines ===
# 

# unfortunately this is true "Cargo Cult Programming", but I don't have the
# time to work out why this code from Expect.pm works just fine and other
# attempts using IO::Pty or Proc::Spawn do not.
#
# minor alterations to use CORE::close and raise_error

sub _spawn_command {
    my @command = @_;
    my $pty = IO::Pty->new();

    # set up pipe to detect childs exec error
    pipe(STAT_RDR, STAT_WTR) or raise_error "Cannot open pipe: $!";
    STAT_WTR->autoflush(1);
    eval {
        fcntl(STAT_WTR, F_SETFD, FD_CLOEXEC);
    };

    my $pid = fork;

    if (! defined ($pid)) {
        raise_error "Cannot fork: $!" if $^W;
        return undef;
    }

    if($pid) { # parent
        my $errno;

        CORE::close STAT_WTR;
        $pty->close_slave();
        $pty->set_raw();

        # now wait for child exec (eof due to close-on-exit) or exec error
        my $errstatus = sysread(STAT_RDR, $errno, 256);
        raise_error "Cannot sync with child: $!" if not defined $errstatus;
        CORE::close STAT_RDR;
        
        if ($errstatus) {
            $! = $errno+0;
            raise_error "Cannot exec(@command): $!\n" if $^W;
            return undef;
        }
    }
    else { # child
        CORE::close STAT_RDR;

        $pty->make_slave_controlling_terminal();
        my $slv = $pty->slave()
            or raise_error "Cannot get slave: $!";

        $slv->set_raw();
        
        CORE::close($pty);

        CORE::close(STDIN);
        open(STDIN,"<&". $slv->fileno())
            or raise_error "Couldn't reopen STDIN for reading, $!\n";
 
        CORE::close(STDOUT);
        open(STDOUT,">&". $slv->fileno())
            or raise_error "Couldn't reopen STDOUT for writing, $!\n";

        CORE::close(STDERR);
        open(STDERR,">&". $slv->fileno())
            or raise_error "Couldn't reopen STDERR for writing, $!\n";

        { exec(@command) };
        print STAT_WTR $!+0;
        raise_error "Cannot exec(@command): $!\n";
    }

    return $pty;
}

1;

# ===========================================================================

=head1 NAME

Net::Appliance::Session::Transport::SSH

=head1 DESCRIPTION

This package sets up a new pseudo terminal, connected to an SSH client running
in a spawned process, which is then bound into C<< Net::Telnet >> for IO
purposes.

=head1 CONFIGURATION

Via the call to C<connect>, the following additional named arguments are
available:

=over 4

=item C<SHKC>

Setting the value for this key to any False value will disable C<openssh>'s
Strict Host Key Checking. See the C<openssh> documentation for further
details. This might be useful where you are connecting to appliances for which
an entry does not yet exist in your C<known_hosts> file, and you do not wish
to be interactively prompted to add it.

 $s->connect(
    Name     => 'username',
    Password => 'password',
    SHKC     => 0,
 );

The default operation is to enable Strict Host Key Checking.

=back

=head1 ACKNOWLEDGEMENTS

The SSH command spawning code was based on that in C<Expect.pm> and is
copyright Roland Giersig and/or Austin Schutz.

=head1 AUTHOR

Oliver Gorwits C<< <oliver.gorwits@oucs.ox.ac.uk> >>

=head1 COPYRIGHT & LICENSE

Copyright (c) The University of Oxford 2006. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51
Franklin
St, Fifth Floor, Boston, MA 02110-1301 USA

=cut
