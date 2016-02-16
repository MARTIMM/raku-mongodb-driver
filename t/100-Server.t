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

my MongoDB::Client $client1;
my MongoDB::Client $client2;
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

  $client1 .= new(:uri('mongodb://localhost:' ~ 65535));
  is $client1.^name, 'MongoDB::Client', "Client isa {$client1.^name}";
  my Str $server-ticket = $client1.select-server;
  nok $server-ticket.defined, 'No servers selected';
  is $client1.nbr-servers, 0, 'Indeed no servers';

}, "Connect failure testing";

#-------------------------------------------------------------------------------
subtest {

  $client1 = get-connection();
  my Str $server-ticket = $client1.select-server;

  my MongoDB::Server $server = $client1.store.get-stored-object($server-ticket);
  ok $server.defined, 'Connection server 1 available';
  is $client1.nbr-servers, 1, 'Indeed one servers';
  is $server.max-sockets,
     3, "Maximum sockets on {$server.name} is $server.max-sockets()";

  my MongoDB::Socket $socket = $server.get-socket;
  ok $socket.is-open, 'Socket is open';
  $socket.close;
  nok $socket.is-open, 'Socket is closed';

  try {
    my @skts;
    for ^10 {
      my $s = $server.get-socket;

      # Still below max
      #
      @skts.push($s);

      CATCH {
        when MongoDB::Message {
          ok .message ~~ m:s/Too many sockets 'opened,' max is/,
             "Too many sockets opened, max is $server.max-sockets()";

          for @skts { .close; }
          last;
        }
      }
    }
  }

  try {
    $server.set-max-sockets(5);
    is $server.max-sockets, 5, "Maximum socket $server.max-sockets()";

    my @skts;
    for ^10 {
      my $s = $server.get-socket;

      # Still below max
      #
      @skts.push($s);

      CATCH {
        when MongoDB::Message {
          ok .message ~~ m:s/Too many sockets 'opened,' max is/,
             "Too many sockets opened, max is $server.max-sockets()";

          for @skts { .close; }
          last;
        }
      }
    }
  }

  try {
    $server.set-max-sockets(2);

    CATCH {
      default {
        is .message,
           "Constraint type check failed for parameter '\$max-sockets'",
           .message;
      }
    }
  }

  $client1.store.clear-stored-object($server-ticket);

  # Try second server
  #
  $client2 = get-connection(:2server);
  $server-ticket = $client2.select-server;
  $server = $client2.store.get-stored-object($server-ticket);
  ok $server.defined, 'Connection server 2 available';
  is $server.max-sockets, 3, "Maximum sockets on {$server.name} is $server.max-sockets()";

}, 'Client, Server, Socket tests';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
