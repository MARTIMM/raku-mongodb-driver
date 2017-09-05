use v6;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;
my @serverkeys = $ts.serverkeys.sort;
my Int $p1 = $ts.server-control.get-port-number(@serverkeys[0]);

#-------------------------------------------------------------------------------
subtest "Client behaviour while shutdown and start server", {

  my @options = <serverSelectionTimeoutMS=5000 heartbeatFrequencyMS=500>;

  my MongoDB::Client $client .= new(
    :uri("mongodb://:$p1/?" ~ @options.join('&'))
  );

  my MongoDB::Server $server = $client.select-server;
  is $client.server-status("localhost:$p1"), SS-Standalone,
     "Status of server is SS-Standalone";

  # Bring server down to see what Client does...
  ok $ts.server-control.stop-mongod(@serverkeys[0]),
     "Server @serverkeys[0] is stopped";
  sleep 1.0;

  $server = $client.select-server;
  nok $server.defined, "Server is down";

  # Bring server up again to see if the Client recovers...
  ok $ts.server-control.start-mongod(@serverkeys[0]),
     "Server @serverkeys[0] started";
  sleep 0.8;

  $server = $client.select-server;
  ok $server.defined, 'Server is defined';
  is $client.server-status("localhost:$p1"), SS-Standalone,
     "Status of server is SS-Standalone again";

  $client.cleanup;
}

#-------------------------------------------------------------------------------
subtest "Shutdown/restart server while inserting records", {

  my @options = <serverSelectionTimeoutMS=5000 heartbeatFrequencyMS=500>;

  my MongoDB::Client $client .= new(
    :uri("mongodb://:$p1/?" ~ @options.join('&')),
  );

  my MongoDB::Server $server = $client.select-server;
  is $client.server-status("localhost:$p1"), SS-Standalone, "Standalone server";

  # Drop database test
  my MongoDB::Database $database = $client.database('test');
  my $doc = $database.run-command: (dropDatabase => 1,);
  ok $doc<ok>, "Database test dropped";

  # Write until it goes wrong because we'll shutdown the server
  my Promise $p .= start( {

      info-message('save several records');

      # Setup collection and database
      my MongoDB::Collection $collection = $client.collection('test.myColl');
      $database = $collection.database;

      # Setup document
      my BSON::Document $req .= new: (
        insert => $collection.name,
        documents => [
          BSON::Document.new((a => 1, b => 2),),
          BSON::Document.new((a => 11, b => 22),),
        ]
      );

      my Int $c = 8;
      for ^$c {
        my BSON::Document $doc = $database.run-command($req);
        my Str $msg = 'no document';
        $msg = $doc<ok> ?? 'doc returned ok' !! 'doc returned not ok' if ?$doc;
        info-message($msg);
        sleep 1;
      }

      CATCH {
        default {
          like .message, /:s Failed to connect\: connection refused/, .message
        }
      }

      "$c records inserted";
    }
  );

  # Let it write at least once
  sleep 2;

  # Bring server down to see what Client does...
  info-message('shutdown server');
  ok $ts.server-control.stop-mongod(@serverkeys[0]), "Server @serverkeys[0] is stopped";
  sleep 1.0;

  $server = $client.select-server;
  nok $server.defined, "Server is down";

  # Bring server up again to see ift Client recovers...
  info-message('start server');
  ok $ts.server-control.start-mongod(@serverkeys[0]), "Server @serverkeys[0] started";
  sleep 0.8;

  # Wait for inserts to finish
  is $p.result, "8 records inserted", "8 records inserted";

#  $client.cleanup;
}

#-------------------------------------------------------------------------------
# Cleanup
info-message("Test $?FILE end");
done-testing();
exit(0);
