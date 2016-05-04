use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Config;
use MongoDB::Cursor;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");


# Stop any left over servers
#
#for @$Test-support::server-range -> $server-number {

#  ok $Test-support::server-control.stop-mongod("s$server-number"),
#     "Server $server-number stopped";
#}

my Hash $config = MongoDB::Config.instance.config;
my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
my Str $host = 'localhost';
my Int $p1 = $Test-support::server-control.get-port-number('s1');
my Int $p2 = $Test-support::server-control.get-port-number('s2');

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $Test-support::server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  ok $Test-support::server-control.stop-mongod("s2"), "Server 2 stopped";
  ok $Test-support::server-control.start-mongod( 's2', 'replicate1'),
     "Start server 2 in replica set '$rs1-s2'";

  # Cannot find server now, need replicaSet option
  my MongoDB::Client $client .= new(:uri("mongodb://:$p2"));
  my MongoDB::Server $server = $client.select-server;
  nok $server.defined, 'No master server found';
  is $client.server-status('localhost:' ~ $p2), MongoDB::C-REJECTED-SERVER,
     "Server 2 is rejected";

}, "Replica server pre-init rejected";

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $Test-support::server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Database $database = $client.database('test');
  my MongoDB::Collection $collection = $database.collection('mycll');

  my MongoDB::Server $server = $client.select-server;
  nok $server.defined, 'No master server found';
  is $client.server-status('localhost:' ~ $p2), MongoDB::C-REPLICA-PRE-INIT,
     "Server is in replica initialization state";

  $server = $client.select-server: :needed-state(MongoDB::C-REPLICA-PRE-INIT);
  is $server.get-status, MongoDB::C-REPLICA-PRE-INIT,
     "Selected server is in replica initialization state";

  # Must use :$server because otherwise a master would be searched for
  # which is not available. The same goes for find later on
  #
  my BSON::Document $doc = $database.run-command( (
      insert => $collection.name,
      documents => [
        (a => 1876, b => 2, c => 20),
        (:p<data1>, :q(20), :2r, :s),
      ]
    ),
    :$server
  );

  ok !?$doc<ok>, 'Command not accepted';
  is $doc<errmsg>, 'not master', 'write to non-master';


  my MongoDB::Cursor $cursor = $collection.find(:$server);
#say "\nC: ", $cursor.perl;
  $doc = $cursor.fetch;
#say "DF: ", $doc.perl;
  is $doc{'$err'}, 'not master and slaveOk=false', $doc{'$err'};

}, "Replica server pre-init";


done-testing();
exit(0);

=finish



my MongoDB::Client $client;
my MongoDB::Server $server;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
my BSON::Document $req;
my BSON::Document $doc;
#-------------------------------------------------------------------------------
subtest {

  ok start-mongod('s1'), "Server 1 started";

  # The name is not set yet, so no replicat name found in monitor result!
  #
  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));

say "Type of localhost:$p2: $client.server-status('localhost:$p2')";
#  is $client.server-status('localhost:65535'),
#     MongoDB::Failed-server,
#     "Status of server is $client.server-status('localhost:65535')";
  

  # Get client without option
  #
  $client .= new(:uri("mongodb://:$p2"));
  while $client.nbr-left-actions {
    debug-message('Wait for server 2');
    sleep 1;
  }
  is $client.nbr-servers, 1, 'One server found';

  $database = $client.database('test');
  $db-admin = $client.database('admin');

  $doc = $database.run-command: (isMaster => 1);
  ok $doc<isreplicaset>, 'Is a replica set server';
  nok $doc<setName>:exists, 'Name not set';

  $doc = $db-admin.run-command: (
    replSetInitiate => (
      _id => $rs1-s2,
      members => [ (
          _id => 0,
          host => "$host:$p2",
          tags => (
            name => 'default-server',
            use => 'testing'
          )
        ),
      ]
    )
  );

  $doc = $database.run-command: (isMaster => 1);
  ok $doc<setName>:exists, 'Name now set';
  is $doc<setName>, $rs1-s2, 'Name ok';
  is $doc<setVersion>, 1, 'Repl set version 1';



  $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  while $client.nbr-left-actions {
    debug-message('Wait for server 2');
    sleep 1;
  }
  is $client.nbr-servers, 1, 'One server found';

  my Int $new-version = $doc<setVersion> + 1;
  $doc = $db-admin.run-command: (
    replSetReconfig => (
      _id => $rs1-s2,
      version => $new-version,
      members => [ (
          _id => 0,
          host => "$host:$p2",
          tags => (
            name => 'still-same-default-server',
            use => 'testing'
          )
        ),
      ]
    ),
    force => False
  );

  sleep 2;
  $doc = $database.run-command: (isMaster => 1);
  is $doc<setVersion>, 2, 'Repl set version 2';
  ok $doc<ismaster>, 'After some time server should become master';
  nok $doc<secondary>, 'And not secondary';
  is $doc<primary>, "$host:$p2", "Primary server name";

}, "Replica servers initialization and modification";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
