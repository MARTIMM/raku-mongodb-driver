use v6.c;
use Test;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::MDBConfig;

use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my Hash $config = MongoDB::MDBConfig.instance.config;
my Str $host = 'localhost';

my Int $p2 = $ts.server-control.get-port-number('s2');
my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

my MongoDB::Client $client;
my MongoDB::Server $server;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest "Replica server pre initialization no option in uri", {

  ok $ts.server-control.stop-mongod("s2"), "Server 2 stopped";
  ok $ts.server-control.start-mongod( 's2', 'replicate1'),
     "Start server 2 in replica set '$rs1-s2'";

  my @options = <serverSelectionTimeoutMS=5000 heartbeatFrequencyMS=500>;

  # Should find a server but not the proper one, need replicaSet option
  $client .= new(
    :uri("mongodb://:$p2/?" ~ @options.join('&')),
  );

  sleep 2.0;
  $server = $client.select-server;
  is $server.get-status<status>, SS-RSGhost,
     "Server 2 is a ghost replica server, needs initialization";

  is $client.topology, TT-Single, "Topology $client.topology()";
  $client.cleanup;
}

#-------------------------------------------------------------------------------
subtest "Replica server pre initialization with option in uri", {

  my @options = |<serverSelectionTimeoutMS=5000 heartbeatFrequencyMS=500>,
                "replicaSet=$rs1-s2";

  $client .= new(
    :uri("mongodb://$host:$p2/?" ~ @options.join('&'))
  );

  $server = $client.select-server(:servername("$host:$p2"));
  ok $server.defined, 'server is defined';

  $doc = $server.raw-query(
    'test.mycl1',
    BSON::Document.new( (
        insert => 'mycl1',
        documents => [
          (a => 1876, b => 2, c => 20),
          (:p<data1>, :q(20), :2r, :s),
        ]
      ),
    ),
  );

  $doc = $doc<documents>[0];
  like $doc<$err>, /:s not master/, $doc<$err>,;
  is $doc<code>, 13435, 'error code 13435';
}

#-------------------------------------------------------------------------------
subtest "Replica server initialization and modification", {

  $server = $client.select-server(:servername("$host:$p2"));
  my BSON::Document $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );

  $doc = $doc<documents>[0];
  ok $doc<isreplicaset>, 'Is a pre-init replica set server';
  ok $doc<setName>:!exists, 'Name not set';

  $doc = $server.raw-query(
    'admin.$cmd',
    BSON::Document.new( (
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
      )
    )
  );

  sleep 10;

  $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );

  $doc = $doc<documents>[0];
  ok $doc<setName>:exists, 'Name now set';
  is $doc<setName>, $rs1-s2, 'Name ok';
  is $doc<setVersion>, 1, 'Repl set version 1';
  ok $doc<ismaster>, 'Server is master';
  nok $doc<secondary>, 'And not secondary';
}

#-------------------------------------------------------------------------------
subtest "Replica servers update replica data", {

  my MongoDB::Server $server = $client.select-server;
  is $server.get-status<status>, SS-RSPrimary,
     "Server is replica server primary";
  is $client.topology, TT-ReplicaSetWithPrimary,
     "Topology replicaset with primary";

  # Get server info, can now be done without server spec. Get the repl version
  my BSON::Document $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );

  $doc = $doc<documents>[0];
  is $doc<setVersion>, 1, 'version is 1';

  # Change server data and update version
  my Int $new-version = $doc<setVersion> + 1;
  $doc = $server.raw-query(
    'admin.$cmd',
    BSON::Document.new( (
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
    )
  );

  $doc = $server.raw-query( 'test.$cmd', BSON::Document.new((isMaster => 1,)));
  $doc = $doc<documents>[0];
  is $doc<setVersion>, 2, 'Repl set version 2';
  is-deeply $doc<hosts>, ["localhost:$p2",],
            "servers in replica: {$doc<hosts>}";
}

#-------------------------------------------------------------------------------
# Cleanup
info-message("Test $?FILE stop");
done-testing();
exit(0);
