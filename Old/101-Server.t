use v6.c;
use lib 't';

use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Server::Socket;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client;
my MongoDB::Server $server;

#-------------------------------------------------------------------------------
subtest {

  $client = $ts.get-connection(:server(3));
  my MongoDB::Server $server = $client.select-server;
  ok $server.defined, 'Connection server available';

  my MongoDB::Server::Socket $socket = $server.get-socket;
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

}, 'max nbr sockets tests - default';

#-------------------------------------------------------------------------------
subtest {

  $client = $ts.get-connection(:server(3));
  my MongoDB::Server $server = $client.select-server;
  ok $server.defined, 'Connection server available';

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

}, 'max nbr sockets tests - 5';

#-------------------------------------------------------------------------------
subtest {

  $client = $ts.get-connection(:server(3));
  my MongoDB::Server $server = $client.select-server;
  ok $server.defined, 'Connection server available';

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

}, 'Client, Server, Socket tests - 2';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");

done-testing();

#exit(0);
