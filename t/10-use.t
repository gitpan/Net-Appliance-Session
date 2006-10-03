#!/usr/bin/perl -w
use strict;
use Test::More tests => 13;

# ------------------------------------------------------------------------

my $class;
BEGIN {
    $class = 'Net::Appliance::Session';
    use_ok($class);
}

# ------------------------------------------------------------------------

my $obj = undef;

eval {$obj = $class->new()};
isa_ok($obj => $class, 'new without Host' );

eval {$obj = $class->new('testhost.example')};
isa_ok( $obj => $class, 'new with Host' );

foreach (qw(
    connect
    begin_privileged
    end_privileged
    in_privileged_mode
    begin_configure
    end_configure
    in_configure_mode
    logged_in
    close
    pb
)) {
    ok( $obj->can($_), "can do method $_");
}

