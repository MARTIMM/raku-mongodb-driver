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
my MongoDB::Server $server;
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

  $client = get-connection();
  my Str $server-ticket = $client.select-server;

  my MongoDB::Server $server = $client.store.get-stored-object($server-ticket);
  ok $server.defined, 'Connection server available';

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

  $client.store.clear-stored-object($server-ticket);

}, 'Client, Server, Socket tests';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
