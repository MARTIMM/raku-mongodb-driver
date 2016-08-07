use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::MDBConfig;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
#my MongoDB::Collection $collection;
my BSON::Document $req;
my BSON::Document $doc;

my Hash $config = MongoDB::MDBConfig.instance.config;

my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
my Str $host = 'localhost';
my Int $p1 = $ts.server-control.get-port-number('s1');
my Int $p2 = $ts.server-control.get-port-number('s2');

#-------------------------------------------------------------------------------
subtest {

  diag "mongodb://:$p2,:$p1";
  $client .= new(:uri("mongodb://:$p2,:$p1"));
  my $server = $client.select-server;
#  is $client.nbr-servers, 2, 'Two servers found';
  is $server.name, "localhost:$p1", "Server localhost:$p1 accepted";
  is $client.server-status('localhost:' ~ $p2), MongoDB::C-REJECTED-SERVER,
     "Server localhost:$p2 rejected";

  diag "mongodb://:$p2";
  $client .= new(:uri("mongodb://:$p2"));
  $server = $client.select-server(:2check-cycles);
#  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status('localhost:' ~ $p2), MongoDB::C-REJECTED-SERVER,
     "Server localhost:$p2 rejected";

  diag "mongodb://:$p1,:$p2/?replicaSet=unknownRS";
  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=unknownRS"));
  $server = $client.select-server(:2check-cycles);
#  is $client.nbr-servers, 2, 'Two servers found';
  is $client.server-status('localhost:' ~ $p1), MongoDB::C-REJECTED-SERVER,
     "Server localhost:$p1 rejected";
  is $client.server-status('localhost:' ~ $p2), MongoDB::C-REJECTED-SERVER,
     "Server localhost:$p2 rejected";

  diag "mongodb://:$p1,:$p2/?replicaSet=$rs1-s2";
  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=$rs1-s2"));
  $server = $client.select-server;
#  is $client.nbr-servers, 2, 'Two servers found';
  is $server.name, "localhost:$p2", "Server localhost:$p2 returned";
  is $client.server-status('localhost:' ~ $p1), MongoDB::C-REJECTED-SERVER,
     "Server localhost:$p1 rejected";
  is $client.server-status('localhost:' ~ $p2), MongoDB::C-REPLICASET-PRIMARY,
     "Server localhost:$p2 replicaset primary";

}, "Client behaviour";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
