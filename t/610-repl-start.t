use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $database;
my MongoDB::Database $db-admin;
my BSON::Document $req;
my BSON::Document $doc;

# Stop any left over servers
#
for @$Test-support::server-range -> $server-number {

  my Str $server-dir = "Sandbox/Server$server-number";
  stop-mongod($server-dir);
#  ok stop-mongod($server-dir), "Server from $server-dir stopped";
}

my Str $rs1 = 'myreplset';
my Str $host = 'localhost';
my Int $p1 = get-port-number(:server(1));
my Int $p2 = get-port-number(:server(2));

#-------------------------------------------------------------------------------
subtest {

  ok start-mongod( "Sandbox/Server1", $p1), "Server 1 started";

  ok start-mongod( "Sandbox/Server2", $p2, :repl-set($rs1)),
     "Server 2 started in replica set '$rs1'";

}, "Servers start";

#-------------------------------------------------------------------------------
subtest {

set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Debug);

  # The name is not set yet, so no replicat name found in monitor result!
  #
  $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1"));
  while $client.nbr-left-actions { sleep 1; }

say "Type of localhost:$p2: $client.server-status('localhost:$p2')";
#  is $client.server-status('localhost:65535'),
#     MongoDB::Failed-server,
#     "Status of server is $client.server-status('localhost:65535')";
  

  # Get client without option
  #
  $client .= new(:uri("mongodb://:$p2"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 1, 'One server found';

  $database = $client.database('test');
  $db-admin = $client.database('admin');

  $doc = $database.run-command: (isMaster => 1);
  ok $doc<isreplicaset>, 'Is a replica set server';
  nok $doc<setName>:exists, 'Name not set';

  $doc = $db-admin.run-command: (
    replSetInitiate => (
      _id => $rs1,
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
  is $doc<setName>, $rs1, 'Name ok';
  is $doc<setVersion>, 1, 'Repl set version 1';



  $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 1, 'One server found';

  my Int $new-version = $doc<setVersion> + 1;
  $doc = $db-admin.run-command: (
    replSetReconfig => (
      _id => $rs1,
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
