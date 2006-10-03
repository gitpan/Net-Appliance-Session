package Net::Appliance::Session::Engine;

use strict;
use warnings FATAL => 'all';

use Net::Appliance::Session::Exceptions;

# ===========================================================================

sub enable_paging {
    my $self = shift;
    
    return 0 unless $self->logged_in;

    $self->cmd($self->pb->fetch('paging') .' 24')
        or $self->error('Failed to enable paging');

    return $self;
}

sub disable_paging {
    my $self = shift;

    return 0 unless $self->logged_in;

    $self->cmd($self->pb->fetch('paging') .' 0')
        or $self->error('Failed to disable paging');

    return $self;
}

# ===========================================================================

# method to enter privileged mode on the remote device.
# optionally, use a different username and password to those
# used at login time. if using a different username then we'll
# explicily login rather than privileged.

sub begin_privileged {
    my $self = shift;
    my $match;

    return $self if $self->in_privileged_mode;

    raise_error 'Must connect before you can begin_privileged'
        unless $self->logged_in;

    # default is to reuse login credentials
    my $username = $self->get_username;
    my $password = $self->get_password;

    # interpret params
    if (scalar @_ == 1) {
        $password = shift;
    }
    elsif (scalar @_ == 2) {
        ($username, $password) = @_;
    }
    elsif (scalar @_ == 4) {
        my %args = @_;
        $username = $args{Name};
        $password = $args{Password};
    }

    # decide whether to explicitly login or just enable
    if ($username ne $self->get_username) {
        $self->print('login');
    }
    else {
        $self->print('enable');
    }

    # whether login or privileged, we still must be prepared for username:
    # prompt because it may appear even with privileged

    (undef, $match) = $self->waitfor('/(?:[Uu]sername|[Pp]assword): ?$/')
        or $self->error('Failed to get first privileged prompt');

    if ($match =~ m/[Uu]sername/) {
        $self->print($username);
        $self->waitfor('/[Pp]assword: ?$/')
            or $self->error('Failed to get privileged password prompt');
    }

    # XXX: don't try to optimise away this print() and waitfor() into a cmd()
    # because they are needed to get the $match back!

    $self->print($password);
    (undef, $match) = $self->waitfor($self->prompt)
        or $self->error('Failed to get prompt after entering privileged mode');

    # fairly dumb check to see that we're actually in privileged and
    # not back at a regular prompt

    $self->error('Failed to enter privileged mode')
        if $match !~ m/# ?$/;

    $self->in_privileged_mode(1);

    return $self;
}

sub end_privileged {
    my $self = shift;
    
    return $self unless $self->in_privileged_mode;

    raise_error 'Must leave configure mode before leaving privileged mode'
        if $self->in_configure_mode;

    # XXX: don't try to optimise away this print() and waitfor() into a cmd()
    # because they are needed to get the $match back!

    $self->print('disable');
    my (undef, $match) = $self->waitfor($self->prompt)
        or $self->error('Failed to get prompt after leaving privileged mode');

    # fairly dumb check to see that we're actually out of privileged
    # and back at a regular prompt

    $self->error('Failed to leave privileged mode')
        if $match !~ m/> ?$/;

    $self->in_privileged_mode(0);

    return $self;
}

# ===========================================================================

# login and enable in cisco-land are actually versions of privileged
foreach (qw( login enable )) {
    *{Symbol::qualify_to_ref($_)} = \&begin_privileged;
}

# ===========================================================================

sub begin_configure {
    my $self = shift;

    return $self if $self->in_configure_mode;

    raise_error 'Must enter privileged mode before configure mode'
        unless $self->in_privileged_mode;

    # XXX: don't try to optimise away this print() and waitfor() into a cmd()
    # because they are needed to get the $match back!

    $self->print('configure terminal');
    my (undef, $match) = $self->waitfor($self->prompt)
        or $self->error('Failed to get prompt after entering configure mode');

    # fairly dumb check to see that we're actually in configure and
    # not still at a regular privileged prompt

    $self->error('Failed to enter configure mode')
        if $match !~ m/\(config\)# ?$/;

    $self->in_configure_mode(1);

    return $self;
}

sub end_configure {
    my $self = shift;

    return $self unless $self->in_configure_mode;

    # XXX: don't try to optimise away this print() and waitfor() into a cmd()
    # because they are needed to get the $match back!

    $self->print('exit');
    my (undef, $match) = $self->waitfor($self->prompt)
        or $self->error('Failed to get prompt after leaving configure mode');

    # fairly dumb check to see that we're actually out of configure
    # and back at a privileged prompt

    $self->error('Failed to leave configure mode')
        if $match =~ m/\(config\)# ?$/;

    $self->in_configure_mode(0);

    return $self;
}

# ===========================================================================

1;

=head1 NAME

Net::Appliance::Session::Engine

=head1 DESCRIPTION

This package contains the default engine that controls login and switching
privilege mode on your target appliance. It currently supports Cisco
equipment, but it's expected that a future version of this distribution will
factor this into another module, leaving a base class here.

=head1 AUTHOR

Oliver Gorwits C<< <oliver.gorwits@oucs.ox.ac.uk> >>

=head1 COPYRIGHT & LICENSE

Copyright (c) The University of Oxford 2006. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of version 2 of the GNU General Public License as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
St, Fifth Floor, Boston, MA 02110-1301 USA

=cut

