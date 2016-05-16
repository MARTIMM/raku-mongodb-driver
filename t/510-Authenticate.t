use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Database;
use MongoDB::Users;
use MongoDB::Authenticate;
use BSON::Document;

plan 1;
skip-rest "Some modules needed for authentication are not yet supported in perl 6";
exit(0);

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
my Int $exit_code;
my Int $server-number = 1;

my MongoDB::Client $client = $ts.get-connection(:server($server-number));
my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;
my MongoDB::Users $users .= new(:$database);
my MongoDB::Authenticate $auth;

$database.run-command: (dropDatabase => 1,);
$database.run-command: (dropAllUsersFromDatabase => 1,);

#-------------------------------------------------------------------------------
subtest {
  $users.set-pw-security(
    :min-un-length(10), 
    :min-pw-length(8),
    :pw_attribs(MongoDB::C-PW-OTHER-CHARS)
  );

  $doc = $users.create-user(
    'site-admin', 'B3n@Hurry',
    :custom-data((user-type => 'site-admin'),),
    :roles([(role => 'userAdminAnyDatabase', db => 'admin'),])
  );

  ok $doc<ok>, 'User site-admin created';

  $doc = $users.create-user(
    'Dondersteen', 'w@tD8jeDan',
    :custom-data(
        license => 'to_kill',
        user-type => 'database-test-admin'
    ),
    :roles([(role => 'readWrite', db => 'test'),])
  );

  ok $doc<ok>, 'User Dondersteen created';

#say "Users: ", $doc.perl;
  $doc = $database.run-command: (usersInfo => 1,);
  is $doc<users>.elems, 2, '2 users defined';
  is $doc<users>[0]<user>, 'site-admin', 'User site-admin';
  is $doc<users>[1]<user>, 'Dondersteen', 'User Dondersteen';
}, "User account preparation";

#---------------------------------------------------------------------------------
subtest {

  ok $Test-support::server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $Test-support::server-control.start-mongod( 's1', 'authenticate'),
     "Server 1 in auth mode";

}, "Server changed to authentication mode";

#---------------------------------------------------------------------------------
subtest {
  # Must get a new database, users and authentication objects because server
  # is restarted.
  #
  $client = $ts.get-connection(:server($server-number));
  $database = $client.database('test');
  $users .= new(:$database);
  $auth .= new(:$database);

  try {
    $database.run-command: (dropAllUsersFromDatabase => 1,);
    ok $doc<ok>, 'All users dropped';

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/not authorized on test to execute/, .error-text;
      }
    }
  }

  try {
    $doc = $auth.authenticate( :user('mt'), :password('mt++'));

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/\w/, .error-text;
      }
    }
  }

  $doc = $auth.authenticate( :user('Dondersteen'), :password('w@tD8jeDan'));
  ok $doc<ok>, 'User Dondersteen logged in';

  $doc = $database.run-command: (logout => 1,);
  ok $doc<ok>, 'User Dondersteen logged out';

}, "Authenticate tests";

#---------------------------------------------------------------------------------
subtest {

  ok $Test-support::server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $Test-support::server-control.start-mongod('s1'),
     "Server 1 in normal mode";

}, "Server changed to normal mode";

#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
