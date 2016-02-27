use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Socket;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://localhost:65535"));
  is $client.^name, 'MongoDB::Client', "Client isa {$client.^name}";
  my MongoDB::Server $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.nbr-servers, 0, 'No servers found';


  my $p1 = get-port-number(:server(1));

  $client .= new(:uri("mongodb://localhost:$p1"));
  while !$client.nbr-servers {
    is $client.nbr-servers, 1, 'One server found';
  }
  is $client.nbr-left-actions, 0, 'No actions left';
  is $client.found-master, True, 'Found a master';


  $client .= new(:uri("mongodb://localhost:$p1,localhost:$p1"));
  while !$client.nbr-servers { }
  is $client.nbr-servers, 1, 'One server accepted, two were equal';



#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);

  my $p2 = get-port-number(:server(2));

  $client .= new(:uri("mongodb://localhost:$p1,localhost:$p2"));
  while !$client.nbr-servers { }
  is $client.nbr-servers, 1,
     "Server $client.select-server.name() accepted, two servers were master";

}, 'Independent servers';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
