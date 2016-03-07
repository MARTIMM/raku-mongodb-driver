use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Client;
use MongoDB::Cursor;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
my MongoDB::Collection $collection;
my BSON::Document $req;
my BSON::Document $doc;

my Int $p2 = get-port-number(:server(2));
my Int $p3 = get-port-number(:server(3));

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p3"));
  $client.select-server;
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
  $db-admin.run-command: (shutdown => 1);

  info-message('insert same records again');
  $doc = $database.run-command($req);
  nok $doc.defined, 'Document not defined caused by server shutdown';
  is $client.nbr-servers, 1, 'Still one server found';
  is $client.server-status("localhost:$p3"),
     MongoDB::Down-server,
     "Status of server is " ~ $client.server-status("localhost:$p3");

}, "Shutdown server 3 before run-command";

done-testing();
exit(0);

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p2"));
  $client.select-server;
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

}, "Shutdown server 2 after find";

#-------------------------------------------------------------------------------
#subtest {
#
#  $client .= new(:uri('mongodb://:' ~ get-port-number(:server(1))));
#  is $client.nbr-servers, 1, 'One server found';
#  $client.shutdown-server($client.select-server());
#  is $client.nbr-servers, 0, 'No server found';
#
#}, "Server 1 stopped too";

#-------------------------------------------------------------------------------
# Cleanup
#
#for ^2 + 2 -> $server-number {
#  my $port-number = get-port-number(:server($server-number));
#  my Str $server-dir = "Sandbox/Server$server-number";
#  ok start-mongod( $server-dir, $port-number), "Server $server-number restarted";
#}

info-message("Test $?FILE stop");
done-testing();
exit(0);
