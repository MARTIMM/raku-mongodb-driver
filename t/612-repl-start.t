use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Config;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Client $client;
my MongoDB::Database $db-admin;
my BSON::Document $req;
my BSON::Document $doc;

# Stop any left over servers
#
for @$Test-support::server-range -> $server-number {

  ok $Test-support::server-control.stop-mongod("s$server-number"),
     "Server $server-number stopped";
}

my Hash $config = MongoDB::Config.instance.config;
my Str $rs2-s1 = $config<mongod><s1><replicate2><replSet>;
my Str $rs2-s3 = $config<mongod><s3><replicate2><replSet>;
my Str $host = 'localhost';
my Int $p1 = $Test-support::server-control.get-port-number('s1');
my Int $p3 = $Test-support::server-control.get-port-number('s3');

#-------------------------------------------------------------------------------
subtest {

  ok $Test-support::server-control.start-mongod( "s1", 'replicate2'),
     "Server 1 started in replica set '$rs2-s1'";

  ok $Test-support::server-control.start-mongod( "s3", 'replicate2'),
     "Server 3 started in replica set '$rs2-3'";

}, "Servers start";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1"));
  while $client.nbr-left-actions { sleep 1; }
  is $client.nbr-servers, 1, "Server at $p1 found";
  $db-admin = $client.database('admin');

  $doc = $db-admin.run-command: (isMaster => 1);
  ok $doc<isreplicaset>, 'Is a replica set server';
  nok $doc<setName>:exists, 'Name not set';

  $doc = $db-admin.run-command: (
    replSetInitiate => (
      _id => $rs2-s1,
      members => [ (
          _id => 0,
          host => "$host:$p1",
          tags => ( name => 'server1', )
        ),(
          _id => 1,
          host => "$host:$p3",
          tags => ( name => 'server3', )
        ),
      ]
    )
  );

#  sleep 1;
  $doc = $db-admin.run-command: (isMaster => 1);
say $doc.perl;

  ok $doc<setName>:exists, 'Name now set';
  is $doc<setName>, $rs2-s1, "Name $rs2-s1";
  is $doc<setVersion>, 1, 'Repl set version 1';

}, "Replica servers initialization and modification";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
