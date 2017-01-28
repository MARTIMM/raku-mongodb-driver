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
    :needed-state(REJECTED-SERVER)
  );
  is $server.get-status, REJECTED-SERVER, "Server 2 is rejected";

  $client.cleanup;
}, "Replica server pre-init rejected";

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Server $server = $client.select-server(:2check-cycles);
  nok $server.defined, 'No master server found';
  is $client.server-status('localhost:' ~ $p2), REPLICA-PRE-INIT,
     "Server is in replica initialization state";

  $server = $client.select-server: :needed-state(REPLICA-PRE-INIT);
  is $server.get-status, REPLICA-PRE-INIT,
     "Selected server is in replica initialization state";

  # Must use $server's raw query because otherwise a master would be
  # searched for which is not available
  #
  my BSON::Document $doc = $server.raw-query(
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

  $client.cleanup;
}, "Replica server pre-init";

#-------------------------------------------------------------------------------
subtest {

  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;

  my MongoDB::Client $client .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Server $server = $client.select-server(
    :needed-state(REPLICA-PRE-INIT)
  );

  my BSON::Document $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );
#note "IM: ", $doc.perl;

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
#note "SI: ", $doc.perl;

  sleep 10;

  $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );
#note "IM: ", $doc.perl;

  $doc = $doc<documents>[0];
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
  is $client.server-status("localhost:$p2"), REPLICASET-PRIMARY,
     "Server is replica server primary";

  # Get server info, can now be done without server spec. Get the repl version
  my BSON::Document $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );
#note "IM: ", $doc.perl;
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

  $doc = $server.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );
#note "IM: ", $doc.perl;
  $doc = $doc<documents>[0];
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
