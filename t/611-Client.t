use v6.c;
use Test;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::MDBConfig;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client;
my MongoDB::Server $server;
#my BSON::Document $doc;

my Hash $config = MongoDB::MDBConfig.instance.config;

my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
my Str $host = 'localhost';
my Int $p1 = $ts.server-control.get-port-number('s1');
my Int $p2 = $ts.server-control.get-port-number('s2');

#-------------------------------------------------------------------------------
subtest "Client behaviour with a replicaserver and standalone mix", {

  diag "\nmongodb://$host:$p2,$host:$p1";
  $client .= new(
    :uri("mongodb://$host:$p2,$host:$p1")
    :server-selection-timeout-ms(1_000),
    :heartbeat-frequency-ms(5_000),
  );

  $server = $client.select-server;
  nok $server.defined, 'Cannot select a server';
  is $client.topology, TT-Unknown, 'Unknown topology';
}

#-------------------------------------------------------------------------------
subtest "Client behaviour with a replicaserver and standalone mix", {

  diag "mongodb://$host:$p2";
  $client .= new(:uri("mongodb://$host:$p2"));
  $server = $client.select-server;
  is $server.get-status<status>, SS-Standalone, "Standalone server";
  is $client.topology, TT-Single, 'Single topology';
}

done-testing();
=finish

  diag "mongodb://:$p1,:$p2/?replicaSet=unknownRS";
  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=unknownRS"));
  $server = $client.select-server(:2check-cycles);
  is $client.server-status('localhost:' ~ $p1), REJECTED-SERVER,
     "Server localhost:$p1 rejected";
  is $client.server-status('localhost:' ~ $p2), REJECTED-SERVER,
     "Server localhost:$p2 rejected";

  diag "mongodb://:$p1,:$p2/?replicaSet=$rs1-s2";
  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=$rs1-s2"));
  $server = $client.select-server;
  is $server.name, "localhost:$p2", "Server localhost:$p2 returned";
  is $client.server-status('localhost:' ~ $p1), REJECTED-SERVER,
     "Server localhost:$p1 rejected";
  is $client.server-status('localhost:' ~ $p2), REPLICASET-PRIMARY,
     "Server localhost:$p2 replicaset primary";
}

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
