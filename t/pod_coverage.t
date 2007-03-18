
use Test::More tests => 1;
eval "use Test::Pod::Coverage 1.00";

=pod
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;
all_pod_coverage_ok();

=cut

pass();