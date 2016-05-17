use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Users;
use MongoDB::Database;
use MongoDB::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client = $ts.get-connection();
my MongoDB::Database $database = $client.database('test');
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $doc;
my MongoDB::Users $users .= new(:$database);

$database.run-command: (dropDatabase => 1,);
$database.run-command: (dropAllUsersFromDatabase => 1,);

#-------------------------------------------------------------------------------
subtest {
  $doc = $users.create-user(
    'mt', 'mt++',
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

  is $doc<ok>, 1, 'User mt created';

  $doc = $users.create-user(
    'mt', 'mt++',
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

  is $doc<ok>, 0, 'Request failed this time';
  is $doc<errmsg>, 'User "mt@test" already exists', $doc<errmsg>;

  $doc = $database.run-command: (dropUser => 'mt',);
  is $doc<ok>, 1, 'User mt deleted';
  
}, "Test user management";

#-------------------------------------------------------------------------------
#
subtest {
  $users.set-pw-security(
    :min-un-length(5),
    :min-pw-length(6),
    :pw_attribs(MongoDB::C-PW-OTHER-CHARS)
  );

  try {
    $doc = $users.create-user(
      'mt', 'mt++',
      :custom-data((license => 'to_kill'),),
      :roles(['readWrite'])
    );

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/Username too 'short,' must be '>= 5'/,
           'Username too short';
      }
    }
  }

  try {
    $doc = $users.create-user(
      'mt-and-another-few-chars', 'mt++',
      :custom-data((license => 'to_kill'),),
      :roles(['readWrite'])
    );

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/Password too 'short,' must be '>= 6'/,
           'Password too short';
      }
    }
  }

  try {
    $doc = $users.create-user(
      'mt-and-another-few-chars', 'mt++tdt',
      :custom-data((license => 'to_kill'),),
      :roles(['readWrite'])
    );

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/Password does not have the right properties/,
           'Password does not have the right properties';
      }
    }
  }

  $doc = $users.create-user(
    'mt-and-another-few-chars', 'mt++tdt0A',
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

say $doc.perl;
  ok $doc<ok>, 'User mt-and-another-few-chars created';


  $doc = $database.run-command: (dropUser => 'mt-and-another-few-chars',);
  ok $doc<ok>, 'User mt-and-another-few-chars deleted';

}, "Test username and password checks";

#-------------------------------------------------------------------------------
subtest {
  $users.set-pw-security(:min-un-length(2), :min-pw-length(2));
  $doc = $users.create-user(
    'mt', 'mt++',
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

  ok $doc<ok>, 'User mt created';

  $doc = $database.run-command: (usersInfo => ( user => 'mt', db => 'test'),);

  my $u = $doc<users>[0];
  is $u<_id>, 'test.mt', $u<_id>;
  is $u<roles>[0]<role>, 'readWrite', $u<roles>[0]<role>;

  $doc = $users.update-user(
    'mt',
    :password<mt+++>,
    :custom-data((license => 'to_heal'),),
    :roles( [
        ( role => 'readWrite', db => 'test1'),
        ( role => 'dbAdmin', db => 'test2')
      ]
    )
  );

  ok $doc<ok>, 'User mt updated';

  $doc = $database.run-command: (usersInfo => ( user => 'mt', db => 'test'),);
  $u = $doc<users>[0];
  is $u<roles>[0]<role>, any(<readWrite dbAdmin>), $u<roles>[0]<role>;
  is $u<roles>[0]<db>, any(<test1 test2>), $u<roles>[0]<db>;
  is $u<roles>[1]<role>, any(<readWrite dbAdmin>), $u<roles>[1]<role>;
  is $u<roles>[1]<db>, any(<test1 test2>), $u<roles>[1]<db>;


  $doc = $database.run-command: (
    grantRolesToUser => 'mt',
    roles => (['dbOwner'])
  );
  ok $doc<ok>, 'User roles mt updated';

  $doc = $database.run-command: (usersInfo => ( user => 'mt', db => 'test'),);
  $u = $doc<users>[0];
  is $u<roles>.elems, 3, 'Now 3 roles defined';
  is $u<roles>[2]<role>, any(<readWrite dbAdmin dbOwner>), $u<roles>[2]<role>;
  is $u<roles>[0]<role>, any(<readWrite dbAdmin dbOwner>), $u<roles>[0]<role>;


  $doc = $database.run-command: (
    revokeRolesFromUser => 'mt',
    roles => ([(role => 'dbAdmin', db => 'test2'),])
  );
  ok $doc<ok>, 'User roles mt revoked';


  $doc = $database.run-command: (usersInfo => ( user => 'mt', db => 'test'),);
  $u = $doc<users>[0];
  is $u<roles>.elems, 2, 'Now 2 roles left';
  is $u<roles>[0]<role>, any(<readWrite dbOwner>), $u<roles>[0]<role>;


  $doc = $database.run-command: (usersInfo => 1,);
  is $doc<users>.elems, 1, 'Only one user defined';
#say "Doc: ", $doc.perl;


  $doc = $database.run-command: (dropAllUsersFromDatabase => 1,);
  ok $doc<ok>, 'All users dropped';
#say "Doc: ", $doc.perl;

  $doc = $database.run-command: (usersInfo => 1,);
  is $doc<users>.elems, 0, 'No users in database';

}, 'account info and drop all users';

#-------------------------------------------------------------------------------
# Cleanup
#
$database.run-command: (dropDatabase => 1,);

info-message("Test $?FILE start");
done-testing();
exit(0);
