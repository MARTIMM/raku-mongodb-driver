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
#my MongoDB::Client $client = get-connection();
my Int $port-number = slurp('Sandbox/port-number').Int;
my MongoDB::Client $client .= new(:uri("mongodb://localhost:$port-number"));
my Str $server-ticket = $client.select-server;
my MongoDB::Server $server = get-stored-object($server-ticket);
ok $server.defined, 'Server defined';
#my MongoDB::Socket $socket = $server.get-socket;

diag "Wait for server to stop";
$server.shutdown; #(:force);

#my $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
#diag $exit_code ?? "Server already stopped" !! "Server stopped";
sleep 2;
diag "Server stopped";
diag "Remove sandbox data";

#`{{    TEMPORARY INHIBIT THE REMOVAL OF THE SANDBOX
for <Sandbox/m.data/journal Sandbox/m.data Sandbox> -> $path {
  next unless $path.IO ~~ :d;
  for dir($path) -> $dir-entry {
    if $dir-entry.IO ~~ :d {
#      diag "delete directory $dir-entry";
      rmdir $dir-entry;
    }

    else {
#      diag "delete file $dir-entry";
      unlink $dir-entry;
    }
  }
}

diag "delete directory Sandbox";
rmdir "Sandbox";
}}

try {
  $client .= new(:uri("mongodb://localhost:$port-number"));
  $server-ticket = $client.select-server;
  nok $server-ticket.defined, 'No servers selected';
}

#-----------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE start");
done-testing();
exit(0);
