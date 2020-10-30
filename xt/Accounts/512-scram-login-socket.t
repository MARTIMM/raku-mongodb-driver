use v6.c;
use lib 't'; #, '../Auth-SCRAM/lib';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::HL::Users;
use MongoDB::Database;
use MongoDB::Collection;

use BSON::Document;
use Auth::SCRAM;
use OpenSSL::Digest;
use Base64;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/512-scram-login-socket.log".IO.open(
  :mode<wo>, :create, :truncate
);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Monitor Uri>);
#set-filter(|< Timer Socket SocketPool >);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my Hash $clients = $ts.create-clients;

my Str $host = $clients<s1>.uri-obj.servers[0]<host>;
my Int $port = $clients<s1>.uri-obj.servers[0]<port>.Int;

my MongoDB::Client $client;
my MongoDB::Database $d;
my MongoDB::Collection $c;
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
my Str $username = 'dondersteen';
my Str $password = 'w!tDo3jeDan';
subtest 'uri object',  {
  my Str $uri = "mongodb://$username:$password@$host:$port/test";
  $client .= new(:$uri);
  is $client.uri-obj.credential.username, $username, "$username parsed";
  is $client.uri-obj.credential.password, $password, "$password parsed";
  #note $client.uri-obj.uri;
}

#-------------------------------------------------------------------------------
subtest "insert by $username in db test",  {
  $d = $client.database('test');
  $c = $d.collection('cl1');

  $req .= new: (
    insert => $c.name,
    documents => [
      ( name => 'Jan Klaassen'),        ( name => 'Piet B'),
      ( name => 'Me T'),                ( :name('Di D'))
    ]
  );

  $doc = $d.run-command($req);
  #note $doc.perl;
  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 4, "Inserted 4 documents";
}

#-------------------------------------------------------------------------------
subtest "insert by $username in db test2",  {
  $d = $client.database('test2');
  $c = $d.collection('cl1');

  $req .= new: (
    insert => $c.name,
    documents => [
      ( name => 'Jan Klaassen'),        ( name => 'Piet B'),
      ( name => 'Me T'),                ( :name('Di D'))
    ]
  );

  $doc = $d.run-command($req);
#  note $doc.perl;
  is $doc<ok>, 0, "Result is not ok";
  like $doc<errmsg>, /:s not authorized on test2 to execute command/;
}

#-------------------------------------------------------------------------------
$username = 'site-admin';
$password = 'B3n!Hurry';
subtest "insert by $username on test2",  {

  my Str $uri = "mongodb://$username:$password@$host:$port/?authSource=admin";
  $client = MongoDB::Client.new(:$uri);
  is $client.uri-obj.credential.username, $username, "$username parsed";
  is $client.uri-obj.credential.password, $password, "$password parsed";

  $d = $client.database('test2');
  $c = $d.collection('cl1');

  $req .= new: (
    insert => $c.name,
    documents => [
      ( name => 'Jan Klaassen'),        ( name => 'Piet B'),
      ( name => 'Me T'),                ( :name('Di D'))
    ]
  );

  $doc = $d.run-command($req);

  # site-admin has userAdminAnyDatabase but no readWrite! -->> fails
  is $doc<ok>, 0, "data not inserted";
  like $doc<errmsg>, /:s not authorized on test2 to execute command/;

  # try to get other role
  $req .= new: (
    :grantRolesToUser($username),
    roles => [
      ( :role<readWrite>, :db<test2>),
    ]
  );

  # ask for change role using wrong database
  $doc = $d.run-command($req);
  is $doc<ok>, 0, "Role not added";
  like $doc<errmsg>, /:s Could not find user 'site-admin@test2'/;

  # now try change role using proper database
  $d = $client.database('admin');
  $doc = $d.run-command($req);
  is $doc<ok>, 1, "Role added";

  # now change database again to insert data
  $d = $client.database('test2');
  $c = $d.collection('cl1');
  $req .= new: (
    insert => $c.name,
    documents => [
      ( name => 'Jan Klaassen'),        ( name => 'Piet B'),
      ( name => 'Me T'),                ( :name('Di D'))
    ]
  );

  $doc = $d.run-command($req);
  is $doc<ok>, 1, "Data inserted";
  is $doc<n>, 4, "Inserted 4 documents";

  # revoke the role
  $d = $client.database('admin');
  $req .= new: (
    :revokeRolesFromUser($username),
    roles => [
      ( :role<readWrite>, :db<test2>),
    ]
  );
  $doc = $d.run-command($req);
  is $doc<ok>, 1, "Role revoked";
}

#-------------------------------------------------------------------------------
$username = 'some-user';
$password = 'some-password';
subtest "insert by some unknown user on test2",  {

  my Str $uri = "mongodb://$username:$password@$host:$port/test";
  $client = MongoDB::Client.new(:$uri);
  is $client.uri-obj.credential.username, $username, "$username parsed";
  is $client.uri-obj.credential.password, $password, "$password parsed";

  $d = $client.database('test2');
  $c = $d.collection('cl1');

  $req .= new: (
    insert => $c.name,
    documents => [
      ( name => 'Jan Klaassen'),        ( name => 'Piet B'),
      ( name => 'Me T'),                ( :name('Di D'))
    ]
  );

  $doc = $d.run-command($req);
  nok $doc.defined, 'failed to insert data';
#  note $doc.perl;
#  is $doc<ok>, 1, "Result is ok";
#  is $doc<n>, 4, "Inserted 4 documents";
}

#-------------------------------------------------------------------------------
# Cleanup
#restart-to-normal;
info-message("Test $?FILE stop");
done-testing();
