use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Config;

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

  ok $Test-support::server-control.stop-mongod("s$server-number"),
     "Server $server-number stopped";
}

my Hash $config = MongoDB::Config.instance.config;
my Str $rs2-s1 = $config<mongod><s1><replicate2><replSet>;
my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
my Str $rs2-s3 = $config<mongod><s3><replicate2><replSet>;
my Str $host = 'localhost';
my Int $p1 = $Test-support::server-control.get-port-number('s1');
my Int $p2 = $Test-support::server-control.get-port-number('s2');
my Int $p3 = $Test-support::server-control.get-port-number('s3');

#-------------------------------------------------------------------------------
subtest {

  ok $Test-support::server-control.start-mongod( 's1', 'replicate2'),
     "Server 1 $p1 started in replica set '$rs2-s1'";

  ok $Test-support::server-control.start-mongod( 's2', 'replicate1'),
     "Server 2 $p2 started in replica set '$rs1-s2'";

  ok $Test-support::server-control.start-mongod( 's3', 'replicate2'),
     "Server 3 $p3 started in replica set '$rs2-s3'";

}, "Servers start";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=$rs1-s2"));
  while $client.nbr-left-actions -> $v { say "left $v"; sleep 1; }
  is $client.nbr-servers, 1, 'One server found';
  my $server = $client.select-server;
  is $server.name, "localhost:$p2", "Servername $server.name()";

  $client .= new(:uri("mongodb://:$p1,:$p3/?replicaSet=$rs2-s1"));
  while $client.nbr-left-actions -> $v { say "left $v"; sleep 1; }
  is $client.nbr-servers, 2, 'Two servers found';
#  my $server = $client.select-server;
#  is $server.name, "localhost:$p2", "Servername $server.name()";

#`{{
  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=unknownRS"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 0, 'No server found';

  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=$rs1-s2"));
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
