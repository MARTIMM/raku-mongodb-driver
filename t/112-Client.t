use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::HL::Users;
use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;
my Int $p1 = $ts.server-control.get-port-number('s1');

# Cleanup all before tests
my MongoDB::Client $cl .= new(:uri("mongodb://localhost:$p1"));
my MongoDB::Database $db = $cl.database('test');
$db.run-command: (dropDatabase => 1,);
$db.run-command: (dropAllUsersFromDatabase => 1,);
$cl.cleanup;

#---------------------------------------------------------------------------------
sub restart-to-authenticate( ) {

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod( 's1', 'authenticate'),
     "Server 1 in authenticate mode";
  sleep 1.0;
};

#---------------------------------------------------------------------------------
sub restart-to-normal( ) {

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod('s1'), "Server 1 in normal mode";
  sleep 1.0;
}

#-------------------------------------------------------------------------------
subtest "User account preparation", {
  my MongoDB::Client $client .= new(:uri("mongodb://localhost:$p1"));
  my MongoDB::Database $database = $client.database('test');
  my MongoDB::HL::Users $users .= new(:$database);

  $users.set-pw-security(
    :min-un-length(10),
    :min-pw-length(8),
    :pw_attribs(C-PW-OTHER-CHARS)
  );

  my BSON::Document $doc = $users.create-user(
    'Dondersteen', 'w@tD8jeDan',
    :custom-data(
        license => 'to_kill',
        user-type => 'database-test-admin'
    ),
    :roles([(role => 'readWrite', db => 'test'),])
  );

  ok $doc<ok>, 'User Dondersteen created';
  $client.cleanup;
}

#-------------------------------------------------------------------------------
restart-to-authenticate;
subtest "mongodb url with username and password SCRAM-SHA-1", {

  diag "Try login user 'Dondersteen'";
  my MongoDB::Client $client;
  my Str $uri = "mongodb://Dondersteen:w%40tD8jeDan@localhost:$p1/test";
  $client .= new(:$uri);
  isa-ok $client, MongoDB::Client;

  diag "Try insert on test database";
  my MongoDB::Database $database = $client.database('test');
  my BSON::Document $doc = $database.run-command: (
    insert => 'famous_people',
    documents => [
      BSON::Document.new((
        name => 'Larry',
        surname => 'Wall',
      )),
    ]
  );

  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 1, "Inserted 1 document";

  diag "Try insert on other database";
  $database = $client.database('otherdb');
  $doc = $database.run-command: (
    insert => 'famous_people',
    documents => [
      BSON::Document.new((
        name => 'Larry',
        surname => 'Wall',
      )),
    ]
  );

  is $doc<ok>, 0, "Insert failure";
  ok $doc<errmsg> ~~ m:s/not authorized on otherdb to execute command/,
     $doc<errmsg>;

#  $client.cleanup;
}

#-------------------------------------------------------------------------------
# Cleanup
restart-to-normal;

info-message("Test $?FILE end");
done-testing();
exit(0);
