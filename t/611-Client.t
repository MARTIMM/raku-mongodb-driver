use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
#my MongoDB::Collection $collection;
my BSON::Document $req;
my BSON::Document $doc;


my Str $rs1 = 'myreplset';
my Str $host = 'localhost';
my Int $p1 = get-port-number(:server(1));
my Int $p2 = get-port-number(:server(2));

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p2,:$p1"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 1, 'One server found';
  my $server = $client.select-server;
  is $server.name, "localhost:$p1", "Servername $server.name()";

  $client .= new(:uri("mongodb://:$p2"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 0, 'No server found';

  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=unknownRS"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 0, 'No server found';

  $client .= new(:uri("mongodb://:$p1,:$p2/?replicaSet=$rs1"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 1, 'One server found';
  $server = $client.select-server;
  is $server.name, "localhost:$p2", "Servername $server.name()";

}, "Servers access";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
