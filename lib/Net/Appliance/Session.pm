package Net::Appliance::Session;

use strict;
use warnings FATAL => 'all';

use base qw(
    Net::Appliance::Session::Transport
    Net::Appliance::Session::Engine
    Net::Telnet
    Class::Accessor::Fast::Contained
); # eventually, would Moosify this ?

our $VERSION = 0.06;

use Net::Appliance::Session::Exceptions;
use Net::Appliance::Phrasebook;
use UNIVERSAL::require;
use Carp;

__PACKAGE__->mk_ro_accessors('pb');
__PACKAGE__->mk_accessors(qw(
    logged_in
    in_configure_mode
    in_privileged_mode
));
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(
    username
    password
));

# ===========================================================================

sub new {
    my $class = shift @_;
    my %args;

    # interpret params into hash so we can augment safely
    if (scalar @_ == 1) {
        $args{Host} = shift @_;
    }
    elsif (! scalar @_ % 2) {
        %args = @_;
    }
    else {
        raise_error "Error: odd number of paramters supplied to new()";
    }

    # our primary base is Net::Telnet, and it's quite sensitive to
    # unrecognized args, so take them out. this also prevents auto-connect

    my $tprt = exists $args{Transport} ? delete $args{Transport} : 'SSH';
    my $host = exists $args{Host}      ? delete $args{Host}      : undef;

    my %pbargs = (); # arguments to Net::Appliance::Phrasebook->load
    $pbargs{platform} =
        exists $args{Platform} ? delete $args{Platform} : 'IOS';
    $pbargs{source} = delete $args{Source} if exists $args{Source};

    # load up the transport, which is a wrapper for Net::Telnet

    my $transport = 'Net::Appliance::Session::Transport::' . $tprt;
    $transport->require or
        raise_error "Couldn't load transport '$transport' (maybe you forgot to install it?)";

    my $self = $transport->new( %args );
    bless ($self, $class);  # reconsecrate into __PACKAGE__
    unshift @Net::Appliance::Session::ISA, $transport;

    # a bit of a double-backflip, but that's what you get for using MI :-}
    $self = $self->Class::Accessor::Fast::Contained::setup({
        pb => Net::Appliance::Phrasebook->load( %pbargs )
    });

    # $self will now respond to Net::Telnet methods, and ->pb->fetch()

    # restore the Host argument
    $self->host( $host ) if defined $host;

    # set Net::Telnet prompt from platform's phrasebook
    $self->prompt( $self->pb->fetch('prompt') );

    return $self;
}

# need to override Net::Telnet::close to make sure we back out
# of any nested modes correctly
sub close {
    my $self = shift;

    my $caller = ( caller(1) )[3];

    # close() is called from other things like fhopen, so we only want
    # to act on real closes -- a bit hacky really
    if ((! defined $caller) or ($caller !~ m/fhopen/)) {
        $self->end_configure if $self->in_configure_mode;
        $self->end_privileged if $self->in_privileged_mode;

        # re-enable paging
        $self->enable_paging;
    }

    $self->SUPER::close(@_);
}

# need to override Net::Telnet::fhopen because it would obliterate our
# private attributes otherwise.
sub fhopen {
    my ($self, $fh) = @_;
    
    ## Save our private data.
    my $s = *$self->{ref $self};

    my $r = $self->SUPER::fhopen($fh); # does not return $self

    ## Restore our private data.
    *$self->{ref $self} = $s;

    return $r;
}

# override Net::Telnet::error(), which is a little tricky...
# Normally error() is kind of polymorphic, changing depending on the state of
# the Errmode parameter, and we still want that to be the case. However
# locally we want ->error to work because it's more straighforward, so we'll
# just filter for calls from our own namespace versus everything else.
sub error {
    my $self = shift;

    return $self->SUPER::error(@_) if scalar caller !~ m/^Net::Appliance::Session/;

    Net::Appliance::Session::Exception->throw(
        message  => join (', ', @_). Carp::shortmess,
        errmsg   => $self->errmsg,
        lastline => $self->lastline,
    );

    return $self; # but hopefully not, because we died
}

# override Net::Telnet::cmd() to check responses against error strings in
# phrasebook for each platform. also check for response sanity to save client
# effort.
sub cmd {
    my $self = shift;

    my (%args, $string, $output);
    if (scalar @_ == 1) {
        %args = ();
        $string = shift @_;
    }
    else {
        %args = @_;
        ($string, $output) = @args{'String', 'Output'};
        %args = (exists $args{Timeout} ? (Timeout => $args{Timeout}) : ());
    }

    $self->print($string)
        or $self->error('Incomplete command write: only '.
                        $self->print_length .' bytes have been sent');

    my @retvals = $self->waitfor( Match => $self->prompt, %args );

    $self->error('Timeout, EOF or other failure waiting for command response')
        if scalar @retvals == 0; # empty list

    my $errstr = $self->pb->fetch('err_str');
    $self->error('Command response matched device error string')
        if $retvals[0] =~ m/$errstr/;

    my @output;
    my $irs = $self->input_record_separator || "\n";
    @output = map { $_ . $irs } split m/$irs/, $retvals[0];
    @output = splice @output, $self->cmd_remove_mode;

    if (ref $output) {
        if (ref $output eq 'SCALAR') {
            $$output = join '', @output;
        }
        else {
            @$output = @output;
        }
    }

    return @output if wantarray;
    return $self;
}

# ===========================================================================

1;

=head1 NAME

Net::Appliance::Session - Run command-line sessions to network appliances

=head1 VERSION

This document refers to version 0.06 of Net::Appliance::Session.

=head1 SYNOPSIS

 use Net::Appliance::Session;
 my $s = Net::Appliance::Session->new('hostname.example');

 eval {
     $s->connect(Name => 'username', Password => 'loginpass');
     $s->begin_privileged('privilegedpass');
     print $s->cmd('show access-list');
     $s->end_privileged;
 };
 if ($@) {
     $e = Exception::Class->caught();
     ref $e ? $e->rethrow : die $e;
 }

 $s->close;

=head1 DESCRIPTION

Use this module to establish an interactive command-line session with a
network appliance. There is special support for moving into C<privileged>
mode and C<configure> mode, with all other commands being sent through a
generic call to your session object.

There are other CPAN modules that cover similar ground, including Net::SSH and
Net::Telnet::Cisco, but they are less robust or do not handle SSH properly.
Objects created by this module are based upon Net::Telnet so the majority of
your interaction will be with methods in that module. It is recommended that
you read the Net::Telnet manual page for further details.

In this early release of C<Net::Appliance::Session>, only SSH connections
to Cisco devices are supported, but it is hoped that further trasports (for
example serial line access) and target device engines (e.g. Juniper) will be
developed.

=head1 METHODS

Objects created by this module are based upon Net::Telnet so the majority of
your interaction will be with methods in that module.

=head2 C<< Net::Appliance::Session->new >>

Like Net::Telnet you can supply either a single parameter to this method which
is used for the target device hostname, or a list of named parameters as
listed in the Net::Telnet documentation. Do not use C<Net::Telnet>'s
C<Errmode> parameter, because it will be overridden by this module.

The significant difference with this module is that the actual connection to
the remote device is delayed until you C<connect()>.

Further named arguments to those in Net::Telnet are accepted, to control
behaviour specific to this module. This is discussed in L</"CONFIGURATION">,
below.

This method returns a new C<Net::Appliance::Session> object.

=head2 C<connect>

When you instantiate a new Net::Appliance::Session object the module does not
actually establish a connection with the target device. This behaviour is
slightly different to Net::Telnet and is because the module also needs to have
login credentials. Use this method to establish that interactive session.

This method requires two arguments: the login username and password. Either
provide them as a pair of parameters to C<connect> in that order, or as a
list of named parameters using the key names C<Name> and C<Password>
respectively. For example:

 $s->connect('username', 'password');
 # or
 $s->connect(Name => 'username', Password => 'password');

In addition to logging in, C<connect> will also disable paging in the
output for its interactive session. This means that unlike Net::Telnet::Cisco
no special page scraping logic is required in this module's code.

It is recommended that the named parameter format is used for passing
arguments to C<connect>. Each connection I<transport> is implemented by an
addon module, which may be set up to take additional named parameters. See
L<Net::Appliance::Session::Transport> for details of available transports.

=head2 C<begin_privileged>

To enter privileged mode on the device use this method. Of course you must be
connected to the device using the C<connect> method, first.

All parameters are optional, and if none are given then the login password
will be used as the privileged password.

If one parameter is given then it is assumed to be the privileged password.

If two parameters are given then they are assumed to be the privileged
username and password, respectively.

If more than two parameters are given then they are interepreted as a list of
named parameters using the key names C<Name> and C<Password> for the
privileged username and password, respectively.

=head2 C<end_privileged>

To leave privileged mode and return to the unpriviledged shell then use this
method.

=head2 C<in_privileged_mode>

This method will return True if your interactive session is currently in
privileged (or configure) mode, and False if it is not.

=head2 C<begin_configure>

In order to enter configure mode, you must first have entered privileged mode,
using the C<begin_privileged> method described above.

To enter configure mode on the device use this method.

=head2 C<end_configure>

To leave configure mode and return to privileged mode the use this method.

=head2 C<in_configure_mode>

This method will return True if your interactive session is currently in
configure mode, and False if it is not.

=head2 C<cmd>

Ordinarily, you might use this C<Net::Telnet> method in scalar context to
observe whether the command was successful on the target appliance. However,
this module's version C<die>s if it doesn't think everything went well. See
L</"DIAGNOSTICS"> for tips on managing this using an C<eval{}> construct.

The following error conditions are checked on your behalf:

=over 4

=item *

Incomplete command output, it was cut short for some reason

=item *

Timeout waiting for command response

=item *

EOF or other anomaly received in the command response

=item *

Error message from your appliance in the response

=back

If any of these occurs then you will get an exception with apropriately
populated fields. Otherwise, in array context this method returns the command
response, just as C<Net::Telnet> would. In scalar context the object itself
returned.

Being overridden in this way means you should have no need for the C<print()>
and C<waitfor()> methods of C<Net::Telnet>, although they are of course still
available should you want them. The only usable method arguments are
C<String>, C<Output> and C<Timeout>.

=head2 C<close>

This C<Net::Telnet> method has been overridden to automatically back
out of configure and/or privilege mode, as well as re-enable paging mode on
your behalf, as necessary.

=head2 C<error>

Rather than following the C<Net::Telnet> documentation, this method now
creates and throws an exception, setting the field values for you. See
L</"DIAGNOSTICS"> below for more information, however under most circumstances
it will be called automatically for you by the overridden C<cmd()> method.

=head1 CONFIGURATION

Occasionally there is a configuration setting that is implemented through
different commands on different models of device. To cope with this,
Net::Appliance::Session makes use of a phrasebook in which it stores
alternative syntax for various operating system platforms.

The default operation of Net::Appliance::Session is to assume that the target
is running a form of Cisco's IOS. Support is also available, via the C<<
Net::Appliance::Phrasebook >> module, for the following operating systems:

 IOS     # the default
 Aironet # currently the same as the default

 PIXOS   # for PIX OS-based devices (including FWSM Release 2.x)
 FWSM    # currently the same as 'PIXOS'
 FWSM3   # for FWSM Release 3.x devices (slightly different to FWSM 2.x)

To select a phrasebook, pass an optional parameter to the C<new> method
like so:

 my $s = Net::Appliance::Session->new(
     Host     => 'hostname.example',
     Platform => 'FWSM3',
     Source   => '/path/to/file.yml', # optional
 );

If you want to add a new phrasebook, or edit an exiting one, there are two
options. Either submit a patch to the maintaner of the C<<
Net::Appliance::Phrasebook >> module, or read the manual page for that module
to find out how to use a local phrasebook rather than the builtin one via the
C<Source> parameter.

=head1 DIAGNOSTICS

Firstly, if you want to see a copy of everything sent to and received from the
appliance, then something like the following will probably do what you want:

 $s->input_log(*STDOUT);

All errors returned from Net::Appliance::Session methods are Perl exceptions,
meaning that in effect C<die()> is called and you will need to use C<<
eval {} >>. The rationale behind this is that you should have taken care to
script interactive sessions robustly, and tested them thoroughly, so if a
prompt is not returned or you supply incorrect parameters then it's an
exceptional error.

Recommended practice is to wrap your interactive session in an eval block like
so:

 eval {
     $s->begin_privileged('password');
     print $s->cmd('show version');
     # and so on...
 };
 if ( UNIVERSAL::isa($@,'Net::Appliance::Session::Exception') ) {
     print $@->message, "\n";  # fault description from Net::Appliance::Session
     print $@->errmsg, "\n";   # message from Net::Telnet
     print $@->lastline, "\n"; # last line of output from your appliance
     # perform any other cleanup as necessary
 }
 $s->close;

Exceptions belong to the C<Net::Appliance::Session::Exception> class if
they result from errors internal to Net::Telnet such as lack of returned
prompts, command timeouts, and so on.

Alternatively exceptions will belong to C<Net::Appliance::Session::Error>
if you have been silly (for example missed a method parameter or tried to
enter configure mode without having first entered privileged mode).

All exception objects are created from C<Exception::Class> and so
stringify correctly and support methods as described in the manual page for
that module.

C<Net::Appliance::Session::Exception> exception objects have two
additional methods (a.k.a. fields), C<errmsg> and C<lastline> which
contain output from Net::Telnet diagnostics.

=head1 INTERNALS

The guts of this module are pretty tricky, although I would also hope elegant,
in parts ;-) In particular, the following C<Net::Telnet> method has been
overridden to modify behaviour:

=head2 C<fhopen>

The killer feature in C<Net::Telnet> is that it allows you to swap out the
builtin I/O target from a standard TELNET connection, to another filehandle of
your choice. However, it does so in a rather intrusive way to the poor object,
so this method is overridden to safeguard the instance's private data.

=head1 DEPENDENCIES

Other than the contents of the standard Perl distribution, you will need the
following:

=over 4

=item *

Exception::Class

=item *

Net::Telnet

=item *

IO::Pty

=item *

UNIVERSAL::require

=item *

Class::Accessor >= 0.25

=item *

Class::Accessor::Fast::Contained

=item *

Net::Appliance::Phrasebook

=back

=head1 AUTHOR

Oliver Gorwits C<< <oliver.gorwits@oucs.ox.ac.uk> >>

=head1 ACKNOWLEDGEMENTS

Parts of this module are based on the work of Robin Stevens and Roger Treweek.
The SSH command spawning code was based on that in C<Expect.pm> and is
copyright Roland Giersig and/or Austin Schutz.

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
