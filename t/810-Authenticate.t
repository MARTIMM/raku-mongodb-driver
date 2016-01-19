use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB::Database;
use MongoDB::Users;
use MongoDB::Authenticate;

#`{{
  Testing;
    Authentication of a user
}}

#-------------------------------------------------------------------------------
# No sandboxing therefore authentication will not be tested as a precaution.
#
if %*ENV<NOSANDBOX> {
  plan 1;
  skip-rest('No sand-boxing requested, so authentication tests are skipped');
  exit(0);
}

plan 1;
skip-rest "Some modules needed for authentication are not yet supported in perl 6";
exit(0);

#-------------------------------------------------------------------------------
my Int $exit_code;

my MongoDB::Client $client = get-connection();
my MongoDB::Database $database .= new(:name<test>);
my MongoDB::Database $db-admin .= new(:name<admin>);
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;
my MongoDB::Users $users .= new(:$database);
my MongoDB::Authenticate $auth;

$database.run-command: (dropDatabase => 1);
$database.run-command: (dropAllUsersFromDatabase => 1);

#-------------------------------------------------------------------------------
subtest {
  $users.set-pw-security(
    :min-un-length(10), 
    :min-pw-length(8),
    :pw_attribs(MongoDB::Users::C-PW-OTHER-CHARS)
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
  $doc = $database.run-command: (usersInfo => 1);
  is $doc<users>.elems, 2, '2 users defined';
  is $doc<users>[0]<user>, 'site-admin', 'User site-admin';
  is $doc<users>[1]<user>, 'Dondersteen', 'User Dondersteen';
}, "User account preparation";

done-testing();
exit(0);

#---------------------------------------------------------------------------------
subtest {
  diag "Change server mode to authenticated mode";
  $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
  sleep 2;

  $exit_code = shell("mongod --auth --config '$*CWD/Sandbox/m-auth.conf'");
  $client = get-connection-try10();
#  diag "Changed server mode";
}, "Server changed to authentication mode";

#---------------------------------------------------------------------------------
subtest {
  # Must get a new database, users and authentication object because server
  # is restarted.
  #
  $database = $client.database('test');
  $users .= new(:$database);
  $auth .= new(:$database);

  try {
    $doc = $users.drop_all_users_from_database();
    ok $doc<ok>, 'All users dropped';
    
    CATCH {
      when X::MongoDB {
        ok .message ~~ m:s/not authorized on test to execute/, .error-text;
      }
    }
  }

  try {
    $doc = $auth.authenticate( :user('mt'), :password('mt++'));

    CATCH {
      when X::MongoDB {
        ok .message ~~ m:s/\w/, .error-text;
      }
    }
  }

  $doc = $auth.authenticate( :user('Dondersteen'), :password('w@tD8jeDan'));
  ok $doc<ok>, 'User Dondersteen logged in';

  $doc = $auth.logout(:user('Dondersteen'));
  ok $doc<ok>, 'User Dondersteen logged out';

}, "Authenticate tests";

#---------------------------------------------------------------------------------
subtest {
  diag "Change server mode back to normal mode";
  $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
  sleep 2;

  $exit_code = shell("mongod --config '$*CWD/Sandbox/m.conf'");
  $client = get-connection-try10();
#  diag "Changed server mode";

  # Must get a new database and user object because server is restarted.
  #
  $database = $client.database('test');
  $users .= new(:$database);

  $doc = $users.drop_all_users_from_database();
  ok $doc<ok>, 'All users dropped';
}, "Server changed to normal mode";

#-------------------------------------------------------------------------------
# Cleanup
#
$client.database('test').drop;

done-testing();
exit(0);
