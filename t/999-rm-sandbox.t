use v6.c;
use lib 't';
use Test;
use Test-support;
use MongoDB;
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
    my MongoDB::Server $server = $client.select-server;
    diag "Wait for $server.name() to stop";
    $client.shutdown-server($server); #(:force);
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
