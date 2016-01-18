use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#`{{
  Testing;
    MongoDB::Client.new()               Define client
    MongoDB::Database.new()             Return database
}}

my MongoDB::Client $client;
my BSON::Document $req;
my BSON::Document $doc;

#set-logfile($*OUT);
#set-logfile($*ERR);
#say "Test of stdout";
#set-exception-throw-level(MongoDB::Severity::Trace);

#-------------------------------------------------------------------------------
subtest {

  $client .= instance( :host<localhost>, :port(65535));
  is $client.^name, 'MongoDB::Client', "Client isa {$client.^name}";
  my $server = $client.select-server;
  nok $server.defined, 'No servers found';

}, "Connect failure testing";

#-------------------------------------------------------------------------------
subtest {

  $client = get-connection();
  my $server = $client.select-server;
  ok $server.defined, 'Connection available';
  ok $server.status, 'Server found';
  is $server.max-sockets, 3, "Maximum socket $server.max-sockets()";

  my $socket = $server.get-socket;
  ok $socket.is-open, 'Socket is open';
  $socket.close;
  nok $socket.is-open, 'Socket is closed';

  try {
    my @skts;
    for ^10 {
#.say;
      my $s = $server.get-socket;

      # Still below max
      #
      @skts.push($s);

      CATCH {
        when X::MongoDB {
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
#.say;
      my $s = $server.get-socket;

      # Still below max
      #
      @skts.push($s);

      CATCH {
        when X::MongoDB {
          ok .message ~~ m:s/Too many sockets 'opened,' max is/,
             "Too many sockets opened, max is $server.max-sockets()";

          for @skts { .close; }
          last;
        }
      }
    }
  }  
}, 'Client, Server, Socket tests';

#-------------------------------------------------------------------------------
subtest {

  # Create databases with a collection and data to make sure the databases are
  # there
  #
  my MongoDB::Database $database .= new(:name<test>);
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

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
