use v6.c;
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
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
subtest {

  my Int $p1 = $ts.server-control.get-port-number('s1');
  my MongoDB::Client $client .= new( :uri("mongodb://:$p1"), :loop-time(1));
  my MongoDB::Server $server = $client.select-server;

  is $client.server-status("localhost:$p1"), MongoDB::C-MASTER-SERVER,
     "Status of server is master";

  # Bring server down to see what Client does...
  ok $ts.server-control.stop-mongod('s1'), "Server 1 is stopped";
  $server = $client.select-server(:needed-state(MongoDB::C-DOWN-SERVER));
  is $server.get-status, MongoDB::C-DOWN-SERVER, "Status of server is down";

  # Bring server up again to see ift Client recovers...
  ok $ts.server-control.start-mongod("s1"), "Server 1 started";

  $server = $client.select-server;
  ok $server.defined, 'Server is defined';
  is $client.server-status("localhost:$p1"), MongoDB::C-MASTER-SERVER,
     "Status of server is master again";

  $client = Nil;
}, "Shutdown and start server";

#-------------------------------------------------------------------------------
subtest {

  my Int $p3 = $ts.server-control.get-port-number('s3');
  my MongoDB::Client $client .= new( :uri("mongodb://:$p3"), :loop-time(3));
  my MongoDB::Server $server = $client.select-server;
  is $client.server-status("localhost:$p3"), MongoDB::C-MASTER-SERVER,
     "Server is master";

  # Drop database test
  my MongoDB::Database $database = $client.database('test');
  my $doc = $database.run-command: (dropDatabase => 1,);
  ok $doc<ok>, "Database test dropped";

  # Write untill it goes wrong because we'll shutdown the server
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
      while $c-- {
        my BSON::Document $doc = $database.run-command($req);
        my Str $msg = 'no document';
        $msg = $doc<ok> ?? 'doc returned ok' !! 'doc returned not ok' if ?$doc;
        info-message($msg);
        sleep 1;
      }

      CATCH {
        default {
          .say;
        }
      }

      True;
    }
  );

  # Let it write at least once
  sleep 2;

  # Bring server down to see what Client does...
  info-message('shutdown server');
  ok $ts.server-control.stop-mongod('s3'), "Server 3 is stopped";

  $server = $client.select-server(:needed-state(MongoDB::C-DOWN-SERVER));
  is $server.get-status, MongoDB::C-DOWN-SERVER, "Server is down";

  # Bring server up again to see ift Client recovers...
  info-message('start server');
  ok $ts.server-control.start-mongod("s3"), "Server 1 started";

  # Wait for inserts to finish
  $p.result;

}, "Shutdown/restart server 3 while inserting records";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
