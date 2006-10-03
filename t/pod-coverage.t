#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok(
    {also_private => [ qr/^close/, qr/^error/, qr/^fhopen/, qr/^begin_/, qr/^end_/, qr/^enable/, qr/^login/, qr/^disable/, qr/^new/, qr/^connect/ ]}
);
