use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Object-store;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Socket;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
my MongoDB::Collection $collection;
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri('mongodb://:' ~ get-port-number(:server(3))));
  is $client.nbr-servers, 1, 'One server found';

  $collection = $client.collection('test.myColl');
  $req .= new: (
    insert => $collection.name,
    documents => [
      BSON::Document.new((a => 1, b => 2),),
      BSON::Document.new((a => 11, b => 22),),
    ]
  );

  $db-admin = $client.database('admin');
  $db-admin.run-command: (shutdown => 1,);

  $database = $collection.database;
  $doc = $database.run-command($req);
  nok $doc.defined, 'Document not defined caused by server shutdown';
  is $client.nbr-servers, 0, 'No servers found';
#say $doc.perl;

}, "Shutdown server test";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
