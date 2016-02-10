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
my Int $port-number1 = slurp('Sandbox/Server1/port-number').Int;
my MongoDB::Client $client1 .= new(:uri("mongodb://localhost:$port-number1"));
my Str $server-ticket1 = $client1.select-server;
my MongoDB::Server $server1 = $client1.store.get-stored-object($server-ticket1);
ok $server1.defined, 'Server 1 defined';

my Int $port-number2 = slurp('Sandbox/Server2/port-number').Int;
my MongoDB::Client $client2 .= new(:uri("mongodb://localhost:$port-number2"));
my Str $server-ticket2 = $client2.select-server;
my MongoDB::Server $server2 = $client2.store.get-stored-object($server-ticket2);
ok $server2.defined, 'Server 2 defined';

diag "Wait for servers to stop";
$server1.shutdown; #(:force);
$server2.shutdown; #(:force);

#my $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
#diag $exit_code ?? "Server already stopped" !! "Server stopped";
sleep 2;
diag "Servers stopped";
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
  }
}

diag "delete directory Sandbox";
rmdir "Sandbox";

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
