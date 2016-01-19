use v6;
use lib 't';
use Test;
use Test-support;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Socket;

#-----------------------------------------------------------------------------
# Stop mongodb unless sandbox isn't found, no sandbox requested
#
if %*ENV<NOSANDBOX> or 'Sandbox/port-number'.IO !~~ :e {
  plan 1;
  skip-rest('No sand-boxing requested');
  exit(0);
}

#-----------------------------------------------------------------------------
#
my Int $port-number = slurp('Sandbox/port-number').Int;


my MongoDB::Client $client .= instance( :host<localhost>, :port($port-number));
my MongoDB::Server $server = $client.select-server;
ok $server.defined, 'Server defined';
#my MongoDB::Socket $socket = $server.get-socket;

diag "Wait for server to stop";
$server.shutdown; #(:force);

#my $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
#diag $exit_code ?? "Server already stopped" !! "Server stopped";
sleep 2;
diag "Server stopped";
diag "Remove sandbox data";

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

try {
  $client .= instance( :host<localhost>, :port($port-number));
  $server = $client.select-server;
  nok $server.defined, 'Server defined';
  CATCH {
    default {
      ok .message ~~ m:s/Failed to connect\: connection refused/,
         'Failed to connect: connection refused';
    }
  }
}

#-----------------------------------------------------------------------------
# Cleanup and close
#
done-testing();
exit(0);
