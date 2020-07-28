use v6;
use lib 't', 'lib';

use Test;

use Test-support;

use BSON::Document;

use MongoDB;
use MongoDB::ServerPool;
use MongoDB::ServerPool::Server;

use Base64;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/170-ServerPool.log".IO.open(
  :mode<wo>, :create, :truncate
);
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my Hash $clients = $ts.create-clients;
my Str $host = $clients<s1>.uri-obj.servers[0]<host>;
my Int $port = $clients<s1>.uri-obj.servers[0]<port>.Int;
my Str $client-key = encode-base64( "s1 $host $port", :str);

my MongoDB::ServerPool $servers;

#-------------------------------------------------------------------------------
subtest "ServerPool creation", {
  dies-ok( { $servers .= new; }, '.new() not allowed');

  $servers .= instance;
  isa-ok $servers, MongoDB::ServerPool;
}

#-------------------------------------------------------------------------------
subtest "ServerPool manipulations", {
  $servers.add-server( $client-key, $host, $port);
#note $servers.get-server-pool-key( $host, $port);

  my Array $topology-description = [];
  $topology-description[Topo-type] = TT-Single;
  my MongoDB::ServerPool::Server $server = $servers.select-server(
    BSON::Document.new, $client-key, $topology-description,
    $clients<s1>.uri-obj
  );

  isa-ok $server, MongoDB::ServerPool::Server;

#  is $servers.get-server-pool-key( $host, $port), $client-key,
#    '.add-server() / .get-server-topology()';
}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
