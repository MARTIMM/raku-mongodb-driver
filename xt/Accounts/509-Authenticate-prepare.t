use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Database;
use MongoDB::Users;
use MongoDB::Authenticate;
use BSON::Document;

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

# Cleanup all before tests
$database.run-command: (dropDatabase => 1,);
$database.run-command: (dropAllUsersFromDatabase => 1,);

#-------------------------------------------------------------------------------
subtest {
  $users.set-pw-security(
    :min-un-length(10), 
    :min-pw-length(8),
    :pw_attribs(C-PW-OTHER-CHARS)
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

  my MongoDB::Collection $u = $db-admin.collection('system.users');
  my MongoDB::Cursor $uc = $u.find( :criteria( user => 'site-admin',));
  $doc = $uc.fetch;
say $doc.perl;

}, "User account preparation";

#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
