use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Socket;
use MongoDB::Object-store;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://localhost:65535"));
  is $client.^name, 'MongoDB::Client', "Client isa {$client.^name}";
  my Str $server-ticket = $client.select-server;
  nok $server-ticket.defined, 'No servers selected';
  is $client.nbr-servers, 0, 'No servers found';

}, "No server";

#-------------------------------------------------------------------------------
subtest {

  my $p1 = get-port-number(:server(1));

  $client .= new(:uri("mongodb://localhost:$p1"));
  is $client.nbr-servers, 1, 'One server found';

}, 'One server';

#-------------------------------------------------------------------------------
subtest {

  my $p1 = get-port-number(:server(1));

  $client .= new(:uri("mongodb://localhost:$p1,localhost:$p1"));
  is $client.nbr-servers, 1, 'One server accepted, two were equal';

}, 'Two servers which are the same';

#-------------------------------------------------------------------------------
subtest {

set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);

  my $p1 = get-port-number(:server(1));
  my $p2 = get-port-number(:server(2));

  $client .= new(:uri("mongodb://localhost:$p1,localhost:$p2"));
  is $client.nbr-servers, 1, 'One server accepted, two servers were master';

}, 'Two different servers';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
