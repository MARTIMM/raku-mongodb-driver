use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Database;
use MongoDB::HL::Users;
use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/503-Authenticate-prep.log".IO.open(
  :mode<wo>, :create, :truncate
);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
set-filter(|<ObserverEmitter Timer Monitor Uri>);
#set-filter(|< Timer Socket SocketPool >);

info-message("Test $?FILE start");
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my MongoDB::Client $client = $ts.get-connection(:server-key<s1>);
my MongoDB::Database $database;
#my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $doc;
my MongoDB::HL::Users $users;

# Cleanup all before tests
for <test admin> -> $db {
  $database = $client.database($db);
  $users .= new(:$database);
  $database.run-command: (dropDatabase => 1,);
  $database.run-command: (dropAllUsersFromDatabase => 1,);
}

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
my Array $accounts = [
  < dondersteen w!tDo3jeDan readWrite test database-test
    site-admin B3n!Hurry userAdminAnyDatabase,hostManager admin site-admin
  >
];

subtest "Add accounts", {
  $users.set-pw-security(
    :min-un-length(10), :min-pw-length(8), :pw_attribs(C-PW-OTHER-CHARS)
  );

  for @$accounts -> $username, $password, $rolespec, $db, $user-type {
    $database = $client.database($db);
    $users .= new(:$database);

    my Array $roles = [];
    for $rolespec.split(',') -> $role {
      $roles.push: ( :$role, :$db);
    }

    $doc = $users.create-user(
      $username, $password, :custom-data((:$user-type),), :$roles
    );
    ok $doc<ok>,
       "Create $username on database $db with roles: $roles.join(', ')";
    $doc = $database.run-command: (usersInfo => 1,);
    is $doc<users>[0]<user>, $username,
       "info of $doc<users>[0]<user> retrieved";
#note $doc.perl;
  }
}

#-------------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE stop");
done-testing();
exit(0);
