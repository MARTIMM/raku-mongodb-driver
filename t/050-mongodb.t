#`{{
  Testing;
    exception block
}}

use v6;
use Test;

use MongoDB::Connection;

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

my MongoDB::Connection $connection = get-connection();

# Drop database first then create new databases
#
$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');

#-------------------------------------------------------------------------------
subtest {
  my $e = X::MongoDB.new(
    :error-text('foutje, bedankt!'),
    :error-code('X007-a'),
    :oper-name('test-a'),
    :oper-data({ a => 1, b => 2}.perl),
#    :class-name         Nil,
#    :method             Nil,
    :database-name('test'),
#    :collection-name    Nil
  );
  
  ok ? $e, 'Defined exception';
  ok $e ~~ X::MongoDB, 'Proper class name';


}, "Exception block tests";


#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done-testing();
exit(0);
