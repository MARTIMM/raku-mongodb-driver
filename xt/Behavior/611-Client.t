use v6;
use Test;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::MDBConfig;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;
my @serverkeys = $ts.serverkeys.sort;

my MongoDB::Client $client;
my MongoDB::Server $server;
#my BSON::Document $doc;

my Hash $config = MongoDB::MDBConfig.instance.config;

my Str $rs1-s2 = $config<mongod>{@serverkeys[1]}<replicate1><replSet>;
my Str $host = 'localhost';
my Int $p1 = $ts.server-control.get-port-number(@serverkeys[0]);
my Int $p2 = $ts.server-control.get-port-number(@serverkeys[1]);

#-------------------------------------------------------------------------------
subtest "Client behaviour with a replicaserver and standalone mix", {

  # Wait long enough to settle in proper end state
  my @options = <serverSelectionTimeoutMS=5000>;
  my Str $uri = "mongodb://$host:$p2,$host:$p1/?" ~ @options.join('&');
  diag $uri;
  $client .= new(:$uri);

  $server = $client.select-server;
  nok $server.defined, 'Cannot select a server';
  is $client.topology, TT-Unknown, 'Unknown topology';
}

#-------------------------------------------------------------------------------
subtest "Client behaviour with one replicaserver", {

  my @options = <serverSelectionTimeoutMS=5000 heartbeatFrequencyMS=500>;
  my Str $uri = "mongodb://$host:$p2/?" ~ @options.join('&');
  diag $uri;
  $client .= new(:$uri);

  $server = $client.select-server;
  is $server.get-status<status>, SS-RSPrimary,
     "Replicaset primary server";
  is $client.topology, TT-Single, 'Single topology';
}

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing;
exit(0);
