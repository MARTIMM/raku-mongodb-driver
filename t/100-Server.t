use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Server;
use MongoDB::Server::Monitor;
use MongoDB::Socket;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my $p1 = $Test-support::server-control.get-port-number('s1');
my $data-channel = Channel.new;
my $command-channel = Channel.new;

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Server $server .= new( :host<localhost>, :port($p1));
  ok $server.defined, 'Connection server available';

  my MongoDB::Server::Monitor $server-monitor = $server.server-monitor;
  $server-monitor.monitor-looptime = 1;
  is $server-monitor.monitor-looptime, 1, 'Monitor loop time changed';
  $server-monitor.monitor-server( $data-channel, $command-channel);

  sleep 2;
  my Hash $monitor-data = $data-channel.poll // Hash.new;
  ok $monitor-data<monitor>:exists, 'Data is set';
  ok $monitor-data<monitor><ismaster>, 'This server is master';

  $command-channel.send('stop');
  sleep 2;
  is $command-channel.receive, 'stopped', 'Monitoring stopped';

}, 'Server monitoring tests';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
