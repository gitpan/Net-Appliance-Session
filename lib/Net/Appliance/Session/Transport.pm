package Net::Appliance::Session::Transport;

use strict;
use warnings FATAL => 'all';

use Net::Appliance::Session::Exceptions;
use Net::Telnet;

# ===========================================================================
# base class for transports - just a Net::Telnet instance factory, really.

sub new {
    my $class = shift;
    return Net::Telnet->new(
        @_,
        Errmode => 'return',
    );
}

sub connect {
    my $self = shift;
    my %args;

    # interpret params into hash
    if (scalar @_ == 2) {
        @args{'Name', 'Password'} = @_;
    }
    elsif ((scalar @_ >= 4) and (! scalar @_ % 2)) {
        %args = @_;
    }
    else {
        raise_error 'Odd or too few arguments to connect()';
    }

    if (! defined $self->host) {
        raise_error 'Cannot log in to an unspecified host!';
    }

    $self->_connect_core( %args );

    $self->set_username($args{Name});
    $self->set_password($args{Password});
    $self->logged_in(1);
    $self->in_configure_mode(0);
    $self->in_privileged_mode(0);

    # disable paging... this is undone in our close() method
    $self->disable_paging;

    return $self;
}

sub _connect_core { 
    raise_error 'Incomplete Transport or there is no Transport loaded!';
}

1;

# ===========================================================================

=head1 NAME

Net::Appliance::Session::Transport

=head1 DESCRIPTION

This package is the base class for all C<< Net::Appliance::Session >>
transports. It is effectively a C<< Net::Telnet >> factory, which then calls
upon a derived class to do something with the guts of the TELNET connection
(perhaps rip it out and shove an SSH connection in there instead).

=head1 AVAILABLE TRANSPORTS

=over 4

=item *

L<Net::Appliance::Session::Trasnsport::SSH>

=back

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

