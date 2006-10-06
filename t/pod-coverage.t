#!perl -T

use Test::More 'no_plan';

eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;

pod_coverage_ok('Net::Appliance::Session');
pod_coverage_ok('Net::Appliance::Session::Transport', {also_private => [ qr/^new/, qr/^connect/ ]});
pod_coverage_ok('Net::Appliance::Session::Transport::SSH', {also_private => [ qr/^new/ ]});

