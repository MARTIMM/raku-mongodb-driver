use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Client;
use MongoDB::Cursor;

#signal(Signal::SIGTERM).tap: {say "Hi"; die "Stopped by user"};

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Server $server;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
my MongoDB::Collection $collection;
my BSON::Document $req;
my BSON::Document $doc;

my Int $p2 = get-port-number(:server(2));
my Int $p3 = get-port-number(:server(3));

$client .= new(:uri("mongodb://:$p3"));

#-------------------------------------------------------------------------------
subtest {

  $client.select-server;

  $collection = $client.collection('test.myColl');
  $database = $collection.database;
  $doc = $database.run-command: (dropDatabase => 1);
  ok $doc<ok>, "Database test dropped";

  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status("localhost:$p3"),
     MongoDB::Master-server,
     "Status of server is " ~ $client.server-status("localhost:$p3");

  info-message('save 2 records');
  $collection = $client.collection('test.myColl');
  $req .= new: (
    insert => $collection.name,
    documents => [
      BSON::Document.new((a => 1, b => 2),),
      BSON::Document.new((a => 11, b => 22),),
    ]
  );

  $database = $collection.database;
  $database.run-command($req);

  info-message('shutdown server');
  $db-admin = $client.database('admin');
  is $client.nbr-servers, 1, 'Still one server found';
  $db-admin.run-command: (shutdown => 1);
  is $client.server-status("localhost:$p3"),
     MongoDB::Down-server,
     "Status of server is " ~ $client.server-status("localhost:$p3");

  info-message('insert same records again');
  $doc = $database.run-command($req);
  nok $doc.defined, 'Document not defined caused by server shutdown';

}, "Shutdown server 3 before run-command";

#-------------------------------------------------------------------------------
subtest {

  my $prms = Promise.start( {
      sleep 4;
      ok start-mongod( "Sandbox/Server3", $p3), "Server 3 restarted";
    }
  );
  
  while not ($server = $client.select-server).defined {
    info-message("Wait for localhost:$p3 to start");
    sleep 2;
  }

  await $prms;

  is $client.server-status("localhost:$p3"),
     MongoDB::Master-server,
     "Status of server 3 is " ~ $client.server-status("localhost:$p3");

  info-message('Retrying insert same records again');
  $req .= new: (
    insert => $collection.name,
    documents => [
      BSON::Document.new((a => 1, b => 2),),
      BSON::Document.new((a => 11, b => 22),),
    ]
  );
  $doc = $database.run-command($req);
  ok $doc.defined, "Document now defined after reviving localhost:$p3";

}, 'Reviving server 3';

#-------------------------------------------------------------------------------
$client .= new(:uri("mongodb://:$p2"));
subtest {

  $client.select-server;

  $collection = $client.collection('test.myColl');
  $database = $collection.database;
  $doc = $database.run-command: (dropDatabase => 1);
  ok $doc<ok>, "Database test dropped";

  is $client.nbr-servers, 1, 'One server found';

  info-message('insert 200 records');
  my Array $docs = [];
  for ^200 -> $i {
    $docs.push(BSON::Document.new: ( a => (rand * 2000).Int, b => $i));
  }

  $collection = $client.collection('test.myColl');
  $req .= new: (
    insert => $collection.name,
    documents => $docs
  );

  $database = $collection.database;
  $database.run-command($req);

  info-message("find records from collection");
  my MongoDB::Cursor $cursor = $collection.find;

  my $count = 1;
  while $cursor.fetch -> $doc {
    unless $doc.defined {
      info-message("record $count undefined due to server down");
      last;
    }

    info-message("record $count: $doc<a b>") unless $count % 5;
    $count++;

    # after the 20th doc a shutdown is performed
    #
    if $count == 20 {
      info-message("shutdown server after 20 records");
      $db-admin = $client.database('admin');
      $db-admin.run-command: (shutdown => 1,);
    }
  }

  ok $client.server-status("localhost:$p2") ~~
     any(MongoDB::Down-server|MongoDB::Recovering-server),
     "Status of server 2 is " ~ $client.server-status("localhost:$p2");

}, "Shutdown server 2 after find";

#-------------------------------------------------------------------------------
subtest {

  my $prms = Promise.start( {
      sleep 2;
      ok start-mongod( "Sandbox/Server2", $p2), "Server 2 restarted";
    }
  );

  while not ($server = $client.select-server).defined {
    info-message("Wait for localhost:$p2 to start");
    sleep 2;
  }

  await $prms;

  is $client.server-status("localhost:$p2"),
     MongoDB::Master-server,
     "Status of server 2 is " ~ $client.server-status("localhost:$p2");

  info-message("Try to find records from collection again");
  my MongoDB::Cursor $cursor = $collection.find(:number-to-return(50));

  my $count = 1;
  while $cursor.fetch -> $doc {
    info-message("record $count: $doc<a b>") unless $count % 10;
    $count++;
  }

}, 'Reviving server 2';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing;
exit(0);
