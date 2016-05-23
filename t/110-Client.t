use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my Int $p1 = $ts.server-control.get-port-number('s1');
my Int $p2 = $ts.server-control.get-port-number('s2');
my MongoDB::Client $client;
my MongoDB::Server $server;

#-------------------------------------------------------------------------------
subtest {

  my Str $server-name = 'non-existent-server.with-unknown.domain:65535';
  $client .= new(:uri("mongodb://$server-name"));
  isa-ok $client, MongoDB::Client;

  $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.nbr-servers, 1, 'One server object set';
  is $client.server-status($server-name ), MongoDB::C-NON-EXISTENT-SERVER,
     "Status of server is non existent";

}, 'Non existent server';

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://localhost:65535"));
  $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.nbr-servers, 1, 'One server object set';
  is $client.server-status('localhost:65535'), MongoDB::C-DOWN-SERVER,
     "Status of server is down";

}, 'Down server';

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1"));
  $server = $client.select-server;

  todo 'Seems to finish processing too soon', 2;
  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status("localhost:$p1"), MongoDB::C-MASTER-SERVER,
     "Status of server is master";
  
}, "Standalone server";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://localhost:$p1,localhost:$p1"));
  $server = $client.select-server;
  is $client.nbr-servers, 1, 'One server accepted, two were equal';

}, "Two equal servers";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1,:$p2"));
  $server = $client.select-server;
  is $server.get-status, MongoDB::C-MASTER-SERVER,
     "Server $server.name() is master";

  if $server.name ~~ m/$p1/ {
    is $client.server-status('localhost:' ~ $p2), MongoDB::C-REJECTED-SERVER,
       "Server localhost:$p2 is rejected";
  }

  else {
    is $client.server-status('localhost:' ~ $p1), MongoDB::C-REJECTED-SERVER,
       "Server localhost:$p1 is rejected";
  }

  is $client.nbr-servers, 2, 'Two servers found';

}, "Two standalone servers";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
