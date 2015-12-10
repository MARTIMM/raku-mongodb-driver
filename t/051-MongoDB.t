#`{{
  Testing;
    exception block
}}

use v6;
use Test;

use MongoDB;
use MongoDB::Connection;

use lib 't';
use Test-support;

my MongoDB::Connection $connection;
my MongoDB::Database $database;

#-------------------------------------------------------------------------------
subtest {

  $connection = get-connection();
  say "Version: ", $MongoDB::version;

  # Drop database first then create new databases
  #
#  $connection.database('test').drop;

#  $database = $connection.database('test');
}

#-------------------------------------------------------------------------------
# Cleanup
#
#$connection.database('test').drop;

done-testing();
exit(0);
