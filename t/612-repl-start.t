use v6.c;
use Test;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::MDBConfig;

use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
subtest {

  my Str $host = 'localhost';
  my Hash $config = MongoDB::MDBConfig.instance.config;

  my Str $rs1-s1 = $config<mongod><s1><replicate1><replSet>;
  diag "\nStart server 1 in pre-init mode in replicaset $rs1-s1";
  my Int $p1 = $ts.server-control.get-port-number('s1');
  ok $ts.server-control.stop-mongod("s1"), "Server 1 stopped";
  ok $ts.server-control.start-mongod( "s1", 'replicate1'),
     "Server 1 started in replica set '$rs1-s1'";

  my Str $rs1-s3 = $config<mongod><s3><replicate1><replSet>;
  diag "Start server 2 pre-init in replicaset $rs1-s3";
  my Int $p3 = $ts.server-control.get-port-number('s3');
  ok $ts.server-control.stop-mongod("s3"), "Server 3 stopped";
  ok $ts.server-control.start-mongod( "s3", 'replicate1'),
     "Server 3 started in replica set '$rs1-s3'";


  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
  diag "Connect to server replica primary from of $rs1-s2";
  my Int $p2 = $ts.server-control.get-port-number('s2');
  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Server $server = $client.select-server;
  ok $server.defined, "Server $server.name() seleced";
  is $server.get-status, REPLICASET-PRIMARY, 'Server 2 is primary';

  diag "Get server info. Get the repl version and update version";
  my BSON::Document $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );
  $doc = $doc<documents>[0];
  my Int $new-version = $doc<setVersion> + 1;

  $doc = $server.raw-query(
    'admin.$cmd',
    BSON::Document.new( (
        replSetReconfig => (
          _id => $rs1-s2,
          version => $new-version,
          members => [ (
              _id => 0,
              host => "$host:$p2",
              tags => ( name => 'server2', )
            ),(
              _id => 1,
              host => "$host:$p1",
              tags => ( name => 'server1', )
            ),(
              _id => 2,
              host => "$host:$p3",
              tags => ( name => 'server3', )
            ),
          ]
        )
      )
    )
  );
#note "RSC: ", $doc.perl;

  $doc = $doc<documents>[0];
  ok ?$doc<ok>, 'Servers are added';

  sleep 2;
  $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );
  $doc = $doc<documents>[0];
  is-deeply $doc<hosts>.sort,
            ( "localhost:$p1", "localhost:$p2", "localhost:$p3"),
            "servers in replica: {$doc<hosts>}";

}, "Adding replica servers";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
