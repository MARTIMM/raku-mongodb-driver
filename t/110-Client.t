use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;

use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my Int $p1 = $ts.server-control.get-port-number('s1');
my Int $p2 = $ts.server-control.get-port-number('s2');
my MongoDB::Client $client;
my MongoDB::Server $server;

#-------------------------------------------------------------------------------
subtest {

  my Str $server-name = 'non-existent-server.with-unknown.domain:65535';
  $client .= new(:uri("mongodb://$server-name"));
  isa-ok $client, MongoDB::Client;

  $server = $client.select-server(:3check-cycles);
  nok $server.defined, 'No servers selected';
  is $client.server-status($server-name), SS-Unknown,
     "Status of server is $client.server-status($server-name)";
  is $client.topology, TT-Unknown, "Topology $client.topology()";

  $server-name = "localhost:65535";
  $client .= new(:uri("mongodb://$server-name"));
  $server = $client.select-server(:3check-cycles);
  nok $server.defined, 'No servers selected';
  is $client.server-status($server-name), SS-Unknown,
     "Status of server is $client.server-status($server-name)";
  is $client.topology, TT-Unknown, "Topology $client.topology()";

}, 'Unknown server';

#-------------------------------------------------------------------------------
subtest {

  my Str $server-name = "localhost:$p1";
  $client .= new(:uri("mongodb://$server-name"));
  sleep(2);

  nok $server.defined, 'No servers selected';
  is $client.server-status($server-name), SS-Standalone,
     "Status of server is $client.server-status($server-name)";

  is $client.topology, TT-Single, "Topology $client.topology()";

}, "Standalone server";

#-------------------------------------------------------------------------------
subtest {

  my Str $server-name1 = "localhost:$p1";
  my Str $server-name2 = "localhost:$p2";
  $client .= new(:uri("mongodb://$server-name1,$server-name2"));
  sleep(2);

  nok $server.defined, 'No servers selected';
  is $client.server-status($server-name1), SS-Standalone,
     "Server $server-name1 is $client.server-status($server-name1)";

  is $client.server-status($server-name2), SS-Standalone,
     "Server $server-name2 is $client.server-status($server-name2)";

  is $client.topology, TT-Unknown, "Topology $client.topology()";
  $client.cleanup;
}, "Two equal standalone servers";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
sleep .2;
drop-all-send-to();
done-testing();
exit(0);



=finish


  my BSON::Document $result = $server.raw-query(
    'admin.$cmd', BSON::Document.new((isMaster => 1)), :!authentication
  );

  is $result<starting-from>, 0, 'start from beginning';
  is $result<number-returned>, 1, 'one document returned';
  ok $result<documents>[0]<ismaster>, 'isMaster returned master = true';
#  note $result.perl;
