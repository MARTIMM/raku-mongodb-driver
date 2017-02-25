use v6.c;
use Test;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::MDBConfig;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
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

  # Wait long enough to settle in proper end state
  my @options = <serverSelectionTimeoutMS=5000>;
  $client .= new(:uri("mongodb://$host:$p2,$host:$p1/?" ~ @options.join('&')));

  $server = $client.select-server;
  nok $server.defined, 'Cannot select a server';
  is $client.topology, TT-Unknown, 'Unknown topology';
}

#-------------------------------------------------------------------------------
subtest "Client behaviour with one replicaserver", {

  diag "mongodb://$host:$p2";
  my @options = <serverSelectionTimeoutMS=5000 heartbeatFrequencyMS=500>;
  $client .= new(:uri("mongodb://$host:$p2/?" ~ @options.join('&')));
  $server = $client.select-server;
  is $server.get-status<status>, SS-RSPrimary, "Replicaset primary server";
  is $client.topology, TT-Single, 'Single topology';
}

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing;
exit(0);
