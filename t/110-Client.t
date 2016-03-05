use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my $p1 = get-port-number(:server(1));
my $p2 = get-port-number(:server(2));
my MongoDB::Client $client;

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://localhost:65535"));
  is $client.^name, 'MongoDB::Client', "Client isa {$client.^name}";
  my MongoDB::Server $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status('localhost:65535'),
     MongoDB::Failed-server,
     "Status of server is $client.server-status('localhost:65535')";


  $client .= new(:uri("mongodb://localhost:$p1"));
  $server = $client.select-server;
  is $client.nbr-servers, 1, 'One server found';
  is $client.nbr-left-actions, 0, 'No actions left';
  is $client.found-master, True, 'Found a master';
  is $client.server-status("localhost:$p1"),
     MongoDB::Master-server,
     "Status of server is $client.server-status("localhost:$p1")";
     


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
