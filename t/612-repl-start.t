use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $db-admin;
my BSON::Document $req;
my BSON::Document $doc;

# Stop any left over servers
#
for @$Test-support::server-range -> $server-number {

  my Str $server-dir = "Sandbox/Server$server-number";
  stop-mongod($server-dir);
#  ok stop-mongod($server-dir), "Server from $server-dir stopped";
}

#my Str $rs1 = 'myreplset';
my Str $rs2 = 'mysecreplset';
my Str $host = 'localhost';
my Int $p1 = get-port-number(:server(1));
#my Int $p2 = get-port-number(:server(2));
my Int $p3 = get-port-number(:server(3));

#-------------------------------------------------------------------------------
subtest {

  ok start-mongod( "Sandbox/Server1", $p1, :repl-set($rs2)),
     "Server 1 started in replica set '$rs2'";

  ok start-mongod( "Sandbox/Server3", $p3, :repl-set($rs2)),
     "Server 3 started in replica set '$rs2'";

}, "Servers start";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 1, "Server at $p1 found";
  $db-admin = $client.database('admin');

  $doc = $db-admin.run-command: (isMaster => 1);
  ok $doc<isreplicaset>, 'Is a replica set server';
  nok $doc<setName>:exists, 'Name not set';

  $doc = $db-admin.run-command: (
    replSetInitiate => (
      _id => $rs2,
      members => [ (
          _id => 0,
          host => "$host:$p1",
          tags => ( name => 'server1', )
        ),(
          _id => 1,
          host => "$host:$p3",
          tags => ( name => 'server3', )
        ),
      ]
    )
  );

  $doc = $db-admin.run-command: (isMaster => 1);
  ok $doc<setName>:exists, 'Name now set';
  is $doc<setName>, $rs2, "Name $rs2";
  is $doc<setVersion>, 1, 'Repl set version 1';



#  sleep 2;
#  $doc = $db-admin.run-command: (isMaster => 1);
#say $doc.perl;

}, "Replica servers initialization and modification";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
