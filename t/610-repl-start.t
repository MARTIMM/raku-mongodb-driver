use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::MDBConfig;
use MongoDB::Cursor;
use BSON::Document;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my Hash $config = MongoDB::MDBConfig.instance.config;
my Str $host = 'localhost';

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  ok $ts.server-control.stop-mongod("s2"), "Server 2 stopped";
  ok $ts.server-control.start-mongod( 's2', 'replicate1'),
     "Start server 2 in replica set '$rs1-s2'";

  # Should not find a server, need replicaSet option
  my MongoDB::Client $client .= new(:uri("mongodb://:$p2"));
  my MongoDB::Server $server = $client.select-server(
    :needed-state(MongoDB::C-REJECTED-SERVER)
  );
#  nok $server.defined, 'No master server found';
  is $server.get-status, MongoDB::C-REJECTED-SERVER, "Server 2 is rejected";

}, "Replica server pre-init rejected";

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Database $database = $client.database('test');
  my MongoDB::Collection $collection = $database.collection('mycll');

  my MongoDB::Server $server = $client.select-server(:2check-cycles);
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

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Server $server = $client.select-server(
    :needed-state(MongoDB::C-REPLICA-PRE-INIT)
  );

  is $server.get-status, MongoDB::C-REPLICA-PRE-INIT,
     "Selected server is in replica initialization state";

  my MongoDB::Database $database = $client.database('test');
  my MongoDB::Database $db-admin = $client.database('admin');

  my BSON::Document $doc = $database.run-command: (isMaster => 1,), :$server;
  ok $doc<isreplicaset>, 'Is a pre-init replica set server';

  nok $doc<setName>:exists, 'Name not set';

  $doc = $db-admin.run-command( (
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
      ),
    ), :$server
  );

  sleep 10;

  $doc = $database.run-command: (isMaster => 1,), :$server;
  ok $doc<setName>:exists, 'Name now set';
  is $doc<setName>, $rs1-s2, 'Name ok';
  is $doc<setVersion>, 1, 'Repl set version 1';
  ok $doc<ismaster>, 'Server is master';
  nok $doc<secondary>, 'And not secondary';

}, "Replica server initialization and modification";

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Server $server = $client.select-server;
  is $client.server-status("localhost:$p2"), MongoDB::C-REPLICASET-PRIMARY,
     "Server is replica server primary";

  my MongoDB::Database $database = $client.database('test');
  my MongoDB::Database $db-admin = $client.database('admin');

  # Get server info, can now be done without server spec. Get the repl version
  my BSON::Document $doc = $database.run-command: (isMaster => 1,),;

  # Change server data and update version
  my Int $new-version = $doc<setVersion> + 1;
  $doc = $db-admin.run-command( (
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
    ),
  );

  $doc = $database.run-command: (isMaster => 1,),;
  is $doc<setVersion>, 2, 'Repl set version 2';
  is-deeply $doc<hosts>, ["localhost:$p2",],
            "servers in replica: {$doc<hosts>}";

}, "Replica servers update replica data";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
