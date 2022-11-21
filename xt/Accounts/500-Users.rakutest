use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::HL::Users;
use MongoDB::Database;
#use MongoDB::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/500-Users.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
set-filter(|<ObserverEmitter Timer Monitor Uri>);
#set-filter(|< Timer Socket SocketPool >);

info-message("Test $?FILE start");
#-------------------------------------------------------------------------------

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client = $ts.get-connection(:server-key<s1>);
my MongoDB::Database $database = $client.database('test');
#my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $doc;
my MongoDB::HL::Users $users .= new(:$database);
my Str $username = 'marcel';
my Str $password = 'additional-protection';

$database.run-command: (dropDatabase => 1,);
$database.run-command: (dropAllUsersFromDatabase => 1,);

#-------------------------------------------------------------------------------
subtest "Test user management", {
  $users.set-pw-security(
    :min-un-length(6), :min-pw-length(10), :pw-attribs(MongoDB::C-PW-LOWERCASE)
  );

  is $users.database.name, 'test', '.database()';
  is $users.min-un-length, 6, '.min-un-length()';
  is $users.min-pw-length, 10, '.min-pw-length()';
  is $users.pw-attribs, MongoDB::C-PW-LOWERCASE, '.pw-attribs()';

  $doc = $users.create-user(
    $username, $password,
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

#`{{
if $doc<ok> == 0 {
  $doc = $database.run-command: (getLastError => 1,);
  note $doc.perl;
}
}}
  is $doc<ok>, 1, "User $username created";

  $doc = $users.create-user(
    $username, $password,
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

  is $doc<ok>, 0, 'Request failed this time';
  is $doc<errmsg>, "User \"$username" ~ '@test" already exists', $doc<errmsg>;

  $doc = $database.run-command: (dropUser => $username,);
  is $doc<ok>, 1, "User $username deleted";

};

#-------------------------------------------------------------------------------
subtest "Test username and password checks", {
  $users.set-pw-security(
    :min-un-length(5),
    :min-pw-length(6),
    :pw_attribs(C-PW-OTHER-CHARS)
  );

  dies-ok( {
      $doc = $users.create-user(
        'mt', 'mt++',
        :custom-data((license => 'to_kill'),),
        :roles(['readWrite'])
      )
    }, 'Username too short'
  );

  dies-ok( {
      $users.set-pw-security(
        :min-un-length(4), :min-pw-length(4),
        :pw-attribs(MongoDB::C-PW-LOWERCASE)
      );
    },
    'password security is too meak'
  );


  dies-ok( {
      $doc = $users.create-user(
        'mt-and-another-few-chars', 'mt++',
        :custom-data((license => 'to_kill'),),
        :roles(['readWrite'])
      );
    }, "Password too short"
  );

  dies-ok( {
      $doc = $users.create-user(
        'mt-and-another-few-chars', 'mt++tdt',
        :custom-data((license => 'to_kill'),),
        :roles(['readWrite'])
      );
    }, 'Password does not have the right properties'
  );

  $doc = $users.create-user(
    'mt-and-another-few-chars', 'mt++tdt0A',
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

  ok $doc<ok>, 'User mt-and-another-few-chars created';

  $doc = $database.run-command: (dropUser => 'mt-and-another-few-chars',);
  ok $doc<ok>, 'User mt-and-another-few-chars deleted';

};

#-------------------------------------------------------------------------------
subtest 'account info and drop all users', {
  $password = 'pw-01At';
  $users.set-pw-security( :min-un-length(2), :min-pw-length(6));
  $doc = $users.create-user(
    $username, $password,
    :custom-data((license => 'to_kill'),),
    :roles(['readWrite'])
  );

  ok $doc<ok>, "User $username created";

  $doc = $database.run-command: (usersInfo => (
    user => $username, db => 'test'),
  );

  my $u = $doc<users>[0];
  is $u<_id>, "test.$username", $u<_id>;
  is $u<roles>[0]<role>, 'readWrite', $u<roles>[0]<role>;

  $password = 'pw-01At-06';
  $doc = $users.update-user(
    $username,
    :$password,
    :custom-data((license => 'to_heal'),),
    :roles( [
        ( role => 'readWrite', db => 'test1'),
        ( role => 'dbAdmin', db => 'test2')
      ]
    )
  );

  ok $doc<ok>, "User $username updated";

  $doc = $database.run-command: (
    usersInfo => ( user => $username, db => 'test'),
  );
  $u = $doc<users>[0];
  is $u<roles>[0]<role>, any(<readWrite dbAdmin>), $u<roles>[0]<role>;
  is $u<roles>[0]<db>, any(<test1 test2>), $u<roles>[0]<db>;
  is $u<roles>[1]<role>, any(<readWrite dbAdmin>), $u<roles>[1]<role>;
  is $u<roles>[1]<db>, any(<test1 test2>), $u<roles>[1]<db>;

  $doc = $database.run-command: (
    grantRolesToUser => $username,
    roles => (['dbOwner'])
  );
  ok $doc<ok>, "User roles $username updated";

  $doc = $database.run-command: (
    usersInfo => ( user => $username, db => 'test'),
  );
  $u = $doc<users>[0];
  is $u<roles>.elems, 3, 'Now 3 roles defined';
  is $u<roles>[2]<role>, any(<readWrite dbAdmin dbOwner>), $u<roles>[2]<role>;
  is $u<roles>[0]<role>, any(<readWrite dbAdmin dbOwner>), $u<roles>[0]<role>;


  $doc = $database.run-command: (
    revokeRolesFromUser => $username,
    roles => ([(role => 'dbAdmin', db => 'test2'),])
  );
  ok $doc<ok>, "User roles $username revoked";


  $doc = $database.run-command: (
    usersInfo => ( user => $username, db => 'test'),
  );
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

};

#-------------------------------------------------------------------------------
# Cleanup
$database.run-command: (dropDatabase => 1,);

info-message("Test $?FILE stop");
done-testing();
exit(0);
