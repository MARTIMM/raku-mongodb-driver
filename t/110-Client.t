use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;

#-------------------------------------------------------------------------------

set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my Int $p1 = $Test-support::server-control.get-port-number('s1');
my Int $p2 = $Test-support::server-control.get-port-number('s2');
my MongoDB::Client $client;
my MongoDB::Server $server;

#-------------------------------------------------------------------------------
subtest {

  my Str $server-name = 'non-existent-server.with-unknown.domain:65535';
  $client .= new(:uri("mongodb://$server-name"));
  is $client.^name, 'MongoDB::Client', "Client isa {$client.^name}";

  $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status($server-name ), MongoDB::C-NON-EXISTENT-SERVER,
     "Status of server is $client.server-status($server-name )";

}, 'Non existent server';

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://localhost:65535"));
  $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status('localhost:65535'), MongoDB::C-DOWN-SERVER,
     "Status of server is $client.server-status('localhost:65535')";

}, 'Down server';

#-------------------------------------------------------------------------------
subtest {
  $client .= new(:uri("mongodb://:$p1"));
  $server = $client.select-server;
  is $client.nbr-servers, 1, 'One server found';
  is $client.found-master, True, 'Found a master';
  is $client.server-status("localhost:$p1"),
     MongoDB::Master-server,
     "Status of server is $client.server-status('localhost:' ~ $p1)";

}, "Standalone server";

done-testing();
exit(0);

#-------------------------------------------------------------------------------
subtest {
  $client .= new(:uri("mongodb://localhost:$p1"));
  $server = $client.select-server;
  is $client.nbr-servers, 1, 'One server found';
  is $client.nbr-left-actions, 0, 'No actions left';
  is $client.found-master, True, 'Found a master';
  is $client.server-status("localhost:$p1"),
     MongoDB::Master-server,
     "Status of server is $client.server-status('localhost:' ~ $p1)";

  $client .= new(:uri("mongodb://localhost:$p1,localhost:$p1"));
  $server = $client.select-server;
  is $client.nbr-servers, 1, 'One server accepted, two were equal';

set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Debug);

  $client .= new(:uri("mongodb://localhost:$p1,localhost:$p2"));
  $server = $client.select-server;
  is $client.nbr-servers, 2,
     "Server $server.name() accepted, two servers were master";
  is $client.server-status($server.name()),
     MongoDB::Master-server,
     "Status of server is Master-server";


}, 'Independent servers';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
