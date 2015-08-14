#`{{
  Testing;
    Authentication of a user
}}

use v6;
use Test;
use MongoDB::Connection;
use MongoDB::Database::Users;
use MongoDB::Database::Authenticate;

my MongoDB::Connection $connection .= new();

# Drop database first then create new databases
#
#$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');
my MongoDB::Database::Users $users .= new(:$database);
my MongoDB::Database::Authenticate $auth .= new(:$database);

#-------------------------------------------------------------------------------
subtest {

my Hash $doc;
 $doc = $users.create_user(
    :user('mt'),
    :password('mt++'),
    :custom_data({license => 'to_kill'}),
    :roles([{role => 'readWrite', db => 'test'}])
  );

  ok $doc<ok>, 'User mt created';

if 0 {
  $doc = $auth.login( :user('mt'), :password('mt++'));
  ok $doc<ok>, 'User mt logged in';

  $doc = $auth.logout(:user('mt'));
  ok $doc<ok>, 'User mt logged out';
}


  $doc = $users.drop_all_users_from_database();
  ok $doc<ok>, 'All users dropped';
}, "Authenticate tests";

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done();
exit(0);
