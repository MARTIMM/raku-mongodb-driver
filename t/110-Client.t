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
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
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
#  is $client.nbr-servers, 1, 'One server object set';
  is $client.server-status($server-name), NON-EXISTENT-SERVER,
     "Status of server is $client.server-status($server-name)";

  $client.cleanup;
}, 'Non existent server';

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://localhost:65535"));
  $server = $client.select-server(:2check-cycles);
  nok $server.defined, 'No servers selected';
#  is $client.nbr-servers, 1, 'One server object set';
  is $client.server-status('localhost:65535'), DOWN-SERVER,
     "Status of server is $client.server-status('localhost:65535')";

  $client.cleanup;
}, 'Down server';

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1"));
  $server = $client.select-server;

#  todo 'Seems to finish processing too soon', 2;
#  is $client.nbr-servers, 1, 'One server found';
  is $client.server-status("localhost:$p1"), MASTER-SERVER,
     "Status of server is $client.server-status("localhost:$p1")";

  my BSON::Document $result = $server.raw-query(
    'admin.$cmd', BSON::Document.new((isMaster => 1)), :!authentication
  );

  is $result<starting-from>, 0, 'start from beginning';
  is $result<number-returned>, 1, 'one document returned';
  ok $result<documents>[0]<ismaster>, 'isMaster returned master = true';

#  note $result.perl;

  $client.cleanup;
}, "Standalone server";

#-------------------------------------------------------------------------------
subtest {

  $client .= new(:uri("mongodb://:$p1,:$p2"));
  $server = $client.select-server;
  is $server.get-status, MASTER-SERVER,
     "Server $server.name() is $server.get-status()";

  # If server has port from $p1 than the other must have status rejected
  my $other-server = $client.select-server(:needed-state(REJECTED-SERVER));
  is $client.server-status( $other-server.name), REJECTED-SERVER,
     "Server $other-server.name() is $client.server-status($other-server.name)";

#  is $client.nbr-servers, 2, 'Two servers found';

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
