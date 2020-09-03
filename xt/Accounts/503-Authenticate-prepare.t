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
my Str $name-user = 'dondersteen';
my Str $pw-user = 'w!tDo3jeDan';

my Str $name-admin = 'site-admin';
my Str $pw-admin = 'B3n!Hurry';

subtest "User account preparation", {
  $users.set-pw-security(
    :min-un-length(10),
    :min-pw-length(8),
    :pw_attribs(C-PW-OTHER-CHARS)
  );

  $doc = $users.create-user(
    $name-admin, $pw-admin,
    :custom-data((user-type => 'site-admin'),),
    :roles([(role => 'userAdminAnyDatabase', db => 'admin'),])
  );
  ok $doc<ok>, "User $name-admin created";

  $doc = $users.create-user(
    $name-user, $pw-user,
    :custom-data(
        license => 'to_kill',
        user-type => 'database-test-admin'
    ),
    :roles([(role => 'readWrite', db => 'test'),])
  );

  ok $doc<ok>, "User $name-user created";

  $doc = $database.run-command: (usersInfo => 1,);
#note $doc.perl;

  is $doc<users>.elems, 2, '2 users defined';
  is $doc<users>[0]<user>, any( $name-user, $name-admin), $doc<users>[0]<user>;
  is $doc<users>[0]<user>, any( $name-user, $name-admin), $doc<users>[1]<user>;
}

#-------------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE stop");
done-testing();
exit(0);
