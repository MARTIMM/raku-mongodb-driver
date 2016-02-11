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
    my MongoDB::Server $server = $client.store.get-stored-object($server-ticket);
    ok $server.defined, "Server $server-number defined";

    diag "Wait for server $server-number to stop";
    $server.shutdown; #(:force);
  }

  $client .= new(:uri("mongodb://localhost:$port-number"));
  is $client.nbr-servers, 0, "No servers for localhost:$port-number";
}

sleep 2;
diag "Servers stopped";

#`{{
diag "Remove sandbox data";
my $dir = 'Sandbox';
my $cleanup-dir = sub ( ) {
  
}



    if $dir-entry.IO ~~ :d {
#      diag "delete directory $dir-entry";
      rmdir $dir-entry;
    }

    else {
#      diag "delete file $dir-entry";
      unlink $dir-entry;
    }

diag "delete directory Sandbox";
rmdir "Sandbox";
}}

#-----------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE start");
done-testing();
exit(0);
