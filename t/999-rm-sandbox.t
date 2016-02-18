use v6;
use lib 't';
use Test;
use Test-support;
use MongoDB;
use MongoDB::Object-store;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Socket;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

#-----------------------------------------------------------------------------
#
for @$Test-support::server-range -> $server-number {

  my Str $server-dir = "Sandbox/Server$server-number";

  my Int $port-number = slurp("$server-dir/port-number").Int;
  my MongoDB::Client $client .= new(:uri("mongodb://localhost:$port-number"));
  ok $client.nbr-servers > 0, "One or more servers via localhost:$port-number";

  if $client.nbr-servers {
    my Str $server-ticket = $client.select-server;
#    my MongoDB::Server $server = $client.store.get-stored-object($server-ticket);
#    ok $server.defined, "Server $server-number defined";

    diag "Wait for server $server-number to stop";
    $client.shutdown-server(:$server-ticket); #(:force);
  }

  $client .= new(:uri("mongodb://localhost:$port-number"));
  is $client.nbr-servers, 0, "No servers for localhost:$port-number";

  undefine $client;
}

diag "Servers stopped";


my $cleanup-dir = sub ( Str $dir-entry ) {
  for dir($dir-entry) -> $entry {
    if $entry ~~ :d {
      $cleanup-dir(~$entry);
#say "delete directory $entry";
      rmdir ~$entry;
    }

    else {
#say "delete file $entry";
      unlink ~$entry;
    }
  }
}

#say "Remove sandbox data";
$cleanup-dir('Sandbox');

rmdir "Sandbox";

diag "Sandbox data deleted";


#-----------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE start");
done-testing();
exit(0);
