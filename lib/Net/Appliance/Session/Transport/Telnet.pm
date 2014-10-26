package Net::Appliance::Session::Transport::Telnet;
BEGIN {
  $Net::Appliance::Session::Transport::Telnet::VERSION = '2.111080';
}

use strict;
use warnings FATAL => 'all';

use base 'Net::Appliance::Session::Transport';
use Net::Appliance::Session::Exceptions;

# ===========================================================================

sub new {
    my $class = shift;
    my %args  = @_;

    my $self = $class->SUPER::new(
        %args,
        Cmd_remove_mode         => 1,
        Output_record_separator => "\r",
    );

    return $self;
}

sub _connect_core {
    my $self = shift;
    my %args = @_;
    
    my $timeout = delete $args{timeout} || $self->timeout;

    if ($self->do_login and ! defined $args{password}) {
        raise_error "'Password' is a required parameter to Telnet connect"
                    . "when using active login";
    }

    if (! defined $self->host) {
        raise_error 'Cannot log in to an unspecified host!';
    }

    # connect to the remote host
    $self->open(Timeout => $timeout)
        or raise_error 'Unable to connect to remote host';

    # optionally, log in to the remote host
    if ($self->do_login) {

        # some systems prompt for username, others don't, so we do this
        # the long way around...

        my $match;
        (undef, $match) = $self->waitfor($self->pb->fetch('userpass_prompt'))
            or $self->error('Failed to get first prompt');

        if ($match =~ eval 'qr'. $self->pb->fetch('user_prompt')) {

            # delayed check, only at this point do we know if Name was required
            if (! defined $args{name}) {
                raise_error "'Name' is a required parameter to Telnet connect "
                            . "when connecting to this host";
            }

            $self->print($args{name});
            $self->waitfor($self->pb->fetch('pass_prompt'))
                or $self->error('Failed to get password prompt');
        }

        $self->print($args{password});
    }

    my $login_done;
    (undef, $login_done) = $self->waitfor(
        Match => $self->prompt,
        Match => $self->pb->fetch('userpass_prompt'),
    )
        or $self->error('Login failed to remote host');

    if ($login_done =~ eval 'qr' . $self->pb->fetch('userpass_prompt')) {
        $self->error('Authentication failed to remote host');
    }

    return $self;
}

# ===========================================================================

1;

# ABSTRACT: Connections using TELNET


__END__
=pod

=head1 NAME

Net::Appliance::Session::Transport::Telnet - Connections using TELNET

=head1 VERSION

version 2.111080

=head1 SYNOPSIS

 $s = Net::Appliance::Session->new(
    Host      => 'hostname.example',
    Transport => 'Telnet',
 );

 $s->connect(
    Name     => $username, # required if logging in
    Password => $password, # required if logging in
 );

=head1 DESCRIPTION

This package makes use of the native Telnet support in Net::Telnet, in order
to establish a connection to a remote host.

=head1 CONFIGURATION

This module hooks into Net::Appliance::Session via its C<connect()> method.
Parameters are supplied to C<connect()> in a hash of named arguments.

=head2 Prerequisites

Before calling C<connect()> you must have set the C<Host> key in your
Net::Appliance::Session object, either via the named parameter to C<new()> or
the C<host()> object method inherited from Net::Telnet.

=head2 Required Parameters

=over 4

=item C<Name>

If log-in is enabled (i.e. you have not disabled this via C<do_login()>),
I<and> the remote host requests a username, then you must supply a username in
the C<Name> parameter value. The username will be stored for possible later
use by C<begin_privileged()>.

=item C<Password>

If log-in is enabled (i.e. you have not disabled this via C<do_login()>) then
you must supply a password in the C<Password> parameter value. The password
will be stored for possible later use by C<begin_privileged()>.

=back

=head2 Optional Parameters

=over 4

=item C<Timeout>

This passes a value through to C<open()> in Net::Telnet, to override the
default connect timeout value of 10 seconds.

 $s->connect(
    Name     => $username,
    Password => $password,
    Timeout  => 30,
 );

The default operation is to time out after 10 seconds.

=back

=head1 AUTHOR

Oliver Gorwits <oliver@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by University of Oxford.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

