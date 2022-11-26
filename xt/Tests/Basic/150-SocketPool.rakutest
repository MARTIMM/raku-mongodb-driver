use v6;
use lib 't', 'lib';
use Test;

use Test-support;

use BSON::Document;

use MongoDB;
use MongoDB::Database;
use MongoDB::MDBConfig;
use MongoDB::SocketPool::Socket;
use MongoDB::SocketPool;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/150-SocketPool.log".IO.open(
  :mode<wo>, :create, :truncate
);
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);
set-filter(|<ObserverEmitter Timer Client Monitor>);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my Hash $clients = $ts.create-clients;
my MongoDB::Client $client = $clients<s1>;


my MongoDB::SocketPool $sockets;

my Str $host = $client.uri-obj.servers[0]<host>;
my Int $port = $client.uri-obj.servers[0]<port>.Int;

#-------------------------------------------------------------------------------
subtest "SocketPool creation", {
  dies-ok( { $sockets .= new; }, '.new() not allowed');

  $sockets .= instance;
  isa-ok $sockets, MongoDB::SocketPool;
}

#-------------------------------------------------------------------------------
subtest "SocketPool manipulations", {
  my MongoDB::MDBConfig $mdbcfg .= instance(
    :locations(['Sandbox',]), :config-name<config.toml>
  );
#note "$host, $port, $client.uri-obj().client-key()";

  # Must use the connection to have a socket in the pool
  my MongoDB::Database $database = $client.database('mt-test');
  my BSON::Document $doc = $database.run-command: (getLastError => 1,);
  is $doc<ok>, 1, 'No last errors';

  # get a socket without uri object -> mimic Monitor
  my MongoDB::SocketPool::Socket $s = $sockets.get-socket(
    $host, $port, :uri-obj($client.uri-obj)
  );

  isa-ok $s, MongoDB::SocketPool::Socket;

  # cleanup Monitor sockets
  #ok $sockets.cleanup( '__MONITOR__CLIENT_KEY__', "host:$port"), '.cleanup()';
  #ok $sockets.cleanup( $client.uri-obj.client-key, "$host:$port"), '.cleanup()';
}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
