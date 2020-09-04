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
my Str $username = 'dondersteen';
my Str $password = 'w!tDo3jeDan';

my Str $uri = "mongodb://$username:$password@$host:$port/test";
my MongoDB::Client $client .= new(:$uri);
is $client.uri-obj.credential.username, $username, 'username parsed';
is $client.uri-obj.credential.password, $password, 'password parsed';
note $client.uri-obj.uri;

my MongoDB::Database $d = $client.database('test');
my MongoDB::Collection $c = $d.collection('cl1');

my BSON::Document $req .= new: (
  insert => $c.name,
  documents => [
    ( name => 'Jan Klaassen'),        ( name => 'Piet B'),
    ( name => 'Me T'),                ( :name('Di D'))
  ]
);

my BSON::Document $doc = $d.run-command($req);
note $doc.perl;
is $doc<ok>, 1, "Result is ok";
is $doc<n>, 4, "Inserted 4 documents";




#$username = 'site-admin';
#$password = 'B3n!Hurry';

#-------------------------------------------------------------------------------
# Cleanup
#restart-to-normal;
info-message("Test $?FILE stop");
done-testing();
