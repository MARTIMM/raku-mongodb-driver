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
say "st: $server-ticket";
  my MongoDB::Server $server = $client1.store.get-stored-object($server-ticket);
  ok $server.defined, 'Connection server 1 available';
  is $client1.nbr-servers, 1, 'Indeed one servers';
  is $server.max-sockets, 3, "Maximum sockets on {$server.name} is $server.max-sockets()";

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
    $server.max-sockets = 5;
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
    $server.max-sockets = 2;

    CATCH {
      default {
        ok .message ~~ m:s/Type check failed in assignment to '$!max-sockets'/,
           "Type check failed in assignment to \$!max-sockets";
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

#`{{
#-------------------------------------------------------------------------------
subtest {

  # Create databases with a collection and data to make sure the databases are
  # there
  #
  $client1 = get-connection();
  my MongoDB::Database $database .= $client1.database(:name<test>);
  isa-ok( $database, 'MongoDB::Database');

  my MongoDB::Collection $collection = $database.collection('abc');
  $req .= new: (
    insert => $collection.name,
    documents => [ (:name('MT'),), ]
  );

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Result is ok";

  # Drop database db2
  #
  $doc = $database.run-command: (dropDatabase => 1);
  is $doc<ok>, 1, 'Drop request ok';

}, "Create database, collection. Collect database info, drop data";
}}

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
