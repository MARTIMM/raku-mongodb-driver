use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
#use MongoDB::Collection;

#-------------------------------------------------------------------------------
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
#my MongoDB::Collection $collection;
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

   $client .= new(:uri('mongodb://'));
   is $client.nbr-servers, 0, 'No servers found';

}, "Matching server test";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri('mongodb:///?replicaSet=myreplset'));
  is $client.nbr-servers, 1, 'One server found';

  $database = $client.database('test');
  $db-admin = $client.database('admin');
#  $collection = $database.collection('repl-test');

  $doc = $database.run-command: (isMaster => 1);
  if $doc<setName>:exists and $doc<setName> eq 'myreplset' {
    my Int $new-version = $doc<setVersion> + 1;
    $doc = $db-admin.run-command: (
      replSetReconfig => (
        _id => 'myreplset',
        version => $new-version,
        members => [ (
            _id => 0,
            host => 'localhost:27017',
            tags => (
              name => 'default-server',
              use => 'testing'
            )
          ),
        ]
      ),
      force => False
    );

#say "Doc: ", $doc.perl unless $doc<ok>;
  }

  else {
    $doc = $db-admin.run-command: (
      replSetInitiate => (
        _id => 'myreplset',
        members => [ (
            _id => 0,
            host => 'localhost:27017',
            tags => (
              name => 'default-server',
              use => 'testing'
            )
          ),
        ]
      )
    );

#say "Doc: ", $doc.perl unless $doc<ok>;
  }

  $doc = $db-admin.run-command: (isMaster => 1);
#say "Doc: ", $doc.perl;
  is $doc<ok>, 1, 'is master request ok';
  is $doc<setName>, 'myreplset', "replication name = $doc<setName>";

}, "replication";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
