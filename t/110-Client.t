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
subtest 'Unknown server', {

  my Str $server-name = 'non-existent-server.with-unknown.domain:65535';
  my @options = <serverSelectionTimeoutMS=100 heartbeatFrequencyMS=300>;

  $client .= new(
    :uri("mongodb://$server-name/?" ~ @options.join('&')),
  );
  isa-ok $client, MongoDB::Client;

  $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.server-status($server-name), SS-Unknown,
     "Status of server is $client.server-status($server-name)";
  is $client.topology, TT-Unknown, "Topology $client.topology()";

  $server-name = "localhost:65535";
  $client .= new(
    :uri("mongodb://$server-name/?" ~ @options.join('&')),
  );
  $server = $client.select-server;
  nok $server.defined, 'No servers selected';
  is $client.server-status($server-name), SS-Unknown,
     "Status of server is $client.server-status($server-name)";
  is $client.topology, TT-Unknown, "Topology $client.topology()";
}

#-------------------------------------------------------------------------------
subtest "Standalone server", {

  my Str $server-name = "localhost:$p1";

  $client .= new(:uri("mongodb://$server-name"));

  # do select server before server status test because selection waits
  $server = $client.select-server;
  ok $server.defined, 'Server selected';

  is $client.server-status($server-name), SS-Standalone,
     "Status of server is $client.server-status($server-name)";

  is $client.topology, TT-Single, "Topology $client.topology()";
}

#-------------------------------------------------------------------------------
subtest "Two equal standalone servers", {

  my Str $server-name1 = "localhost:$p1";
  my Str $server-name2 = "localhost:$p2";
  my @options = <serverSelectionTimeoutMS=5000 heartbeatFrequencyMS=5000>;

  $client .= new(
    :uri("mongodb://$server-name1,$server-name2/?" ~  ~ @options.join('&'))
  );

  $server = $client.select-server;
  nok $server.defined, 'No servers selected';

  is $client.server-status($server-name1), SS-Standalone,
     "Server $server-name1 is $client.server-status($server-name1)";

  is $client.server-status($server-name2), SS-Standalone,
     "Server $server-name2 is $client.server-status($server-name2)";

  is $client.topology, TT-Unknown, "Topology $client.topology()";
  $client.cleanup;
}

#-------------------------------------------------------------------------------
# Cleanup
info-message("Test $?FILE end");
done-testing();
exit(0);
=finish
