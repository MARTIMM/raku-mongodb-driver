use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Database;
use MongoDB::HL::Users;
use BSON::Document;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my MongoDB::Client $client = $ts.get-connection(:server(1));
my MongoDB::Database $database = $client.database('test');
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $doc;
my MongoDB::HL::Users $users .= new(:$database);

# Cleanup all before tests
$database.run-command: (dropDatabase => 1,);
$database.run-command: (dropAllUsersFromDatabase => 1,);

#-------------------------------------------------------------------------------
# Mongodb user information of user Dondersteen
#
# BSON::Document.new((
#   _id => "test.Dondersteen",
#   user => "Dondersteen",
#   db => "test",
#   credentials => BSON::Document.new((
#     SCRAM-SHA-1 => BSON::Document.new((
#       iterationCount => 10000,
#       salt => "zJTEg2LGEif+tRUQf6zEXg==",
#       storedKey => "0uply8Ame1rdBv9/tPKBCXq7Qyg=",
#       serverKey => "prSURpQTk+RikdcuKLlX9D3mPXo=",
#     )),
#   )),
#   customData => BSON::Document.new((
#     license => "to_kill",
#     user-type => "database-test-admin",
#   )),
#   roles => [
#         BSON::Document.new((
#       role => "readWrite",
#       db => "test",
#     )),
#   ],
# ))
#
subtest {
  $users.set-pw-security(
    :min-un-length(10), 
    :min-pw-length(8),
    :pw_attribs(C-PW-OTHER-CHARS)
#    :pw_attribs(C-PW-LOWERCASE)
  );

  $doc = $users.create-user(
    'site-admin', 'B3n@Hurry',
#    'site-admin', 'B3nHurry',
    :custom-data((user-type => 'site-admin'),),
    :roles([(role => 'userAdminAnyDatabase', db => 'admin'),])
  );
  ok $doc<ok>, 'User site-admin created';

  $doc = $users.create-user(
    'Dondersteen', 'w@tD8jeDan',
#    'Dondersteen', 'watDo3jeDan',
    :custom-data(
        license => 'to_kill',
        user-type => 'database-test-admin'
    ),
    :roles([(role => 'readWrite', db => 'test'),])
  );

  ok $doc<ok>, 'User Dondersteen created';

  $doc = $database.run-command: (usersInfo => 1,);
  is $doc<users>.elems, 2, '2 users defined';
  is $doc<users>[0]<user>, 'site-admin', 'User site-admin';
  is $doc<users>[1]<user>, 'Dondersteen', 'User Dondersteen';

}, "User account preparation";

#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
