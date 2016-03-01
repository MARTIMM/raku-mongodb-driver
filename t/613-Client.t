use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
#my MongoDB::Collection $collection;
my BSON::Document $req;
my BSON::Document $doc;


# Stop any left over servers
#
for @$Test-support::server-range -> $server-number {

  my Str $server-dir = "Sandbox/Server$server-number";
  stop-mongod($server-dir);
#  ok stop-mongod($server-dir), "Server from $server-dir stopped";
}

my Str $rs1 = 'myreplset';
my Str $rs2 = 'mysecreplset';
my Str $host = 'localhost';
my Int $p1 = get-port-number(:server(1));
my Int $p2 = get-port-number(:server(2));
my Int $p3 = get-port-number(:server(3));

#-------------------------------------------------------------------------------
subtest {

  ok start-mongod( "Sandbox/Server1", $p1, :repl-set($rs2)),
     "Server 1 $p1 started in replica set '$rs2'";

  ok start-mongod( "Sandbox/Server2", $p2, :repl-set($rs1)),
     "Server 2 $p2 started in replica set '$rs1'";

  ok start-mongod( "Sandbox/Server3", $p3, :repl-set($rs2)),
     "Server 3 $p3 started in replica set '$rs2'";

}, "Servers start";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=$rs1"));
  while $client.nbr-left-actions -> $v { say "left $v"; sleep 1; }
  is $client.nbr-servers, 1, 'One server found';
  my $server = $client.select-server;
  is $server.name, "localhost:$p2", "Servername $server.name()";

  $client .= new(:uri("mongodb://:$p1,:$p3/?replicaSet=$rs2"));
  while $client.nbr-left-actions -> $v { say "left $v"; sleep 1; }
  is $client.nbr-servers, 2, 'Two servers found';
#  my $server = $client.select-server;
#  is $server.name, "localhost:$p2", "Servername $server.name()";

#`{{
  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=unknownRS"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 0, 'No server found';

  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=$rs1"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 1, 'One server found';
  $server = $client.select-server;
  is $server.name, "localhost:$p2", "Servername $server.name()";
}}
}, "Servers access";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
