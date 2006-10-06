package Net::Appliance::Session::Exceptions;

use strict;
use warnings FATAL => 'all';

use Symbol;

# ===========================================================================

sub import {

    # Exception::Class looks at caller() to insert raise_error into that
    # Namespace, so this hack means whoever use's us, they get a raise_error
    # of their very own.

    *{Symbol::qualify_to_ref('raise_error',caller())}
        = sub { Net::Appliance::Session::Error->throw(@_) };
}


# Rationale: normally tend to avoid exceptions in perl, because they're a
# little ugly to catch, however they are handy when we want to bundle extra
# info along with the usual die/croak string argument. Here, we're going to
# send some debugging from the SSH session along with exceptions.

use Exception::Class (
    'Net::Appliance::Session::Exception' => {
        description => 'Errors encountered during SSH sessions',
        fields      => ['errmsg', 'lastline'],
    },

    'Net::Appliance::Session::Error' => {
        description => 'Errors encountered during program execution',
#        alias       => 'raise_error',
    },
);

# just a wee hack to add newlines so we can miss them off in calls to
# raise_error -- overrides Exception::Class::full_message()
sub Net::Appliance::Session::Error::full_message {
    my $self = shift;
    
    my $msg = $self->message;
    $msg .= "\n" if $msg !~ /\n$/;
    
    return $msg;
}

1;

