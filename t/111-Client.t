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

my Int $p1 = $Test-support::server-control.get-port-number('s1');
my MongoDB::Client $client;
my MongoDB::Server $server;

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1"));
  $server = $client.select-server;

  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status("localhost:$p1"), MongoDB::C-MASTER-SERVER,
     "Status of server is master";

  # Bring server down to see what Client does...
  ok $Test-support::server-control.stop-mongod('s1'), "Server 1 is stopped";
  sleep 10;

  $server = $client.select-server;
  nok $server.defined, 'Server not defined';
  is $client.server-status("localhost:$p1"), MongoDB::C-DOWN-SERVER,
     "Status of server is down";

  # Bring server up again to see ift Client recovers...
  ok $Test-support::server-control.start-mongod("s1"), "Server 1 started";
  sleep 5;

  $server = $client.select-server;
  ok $server.defined, 'Server is defined';
  is $client.server-status("localhost:$p1"), MongoDB::C-MASTER-SERVER,
     "Status of server is master again";
  
}, "Shutdown and start server";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
