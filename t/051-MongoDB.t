#`{{
  Testing;
    exception block
}}

use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB::Connection;


my MongoDB::Connection $connection;
my MongoDB::Database $database;

#-------------------------------------------------------------------------------
subtest {

  $connection = get-connection();
  say "Version: ", $MongoDB::version;

  # Drop database first then create new databases
  #
  my BSON::Document $doc = $connection.database('test').run-command(
    BSON::Document.new: (dropDatabase => 1)
  );

  is $doc<ok>, 1, "Result is ok";

}, "Run command, single handed";

#-------------------------------------------------------------------------------
# Cleanup
#
#$connection.database('test').drop;

done-testing();
exit(0);
