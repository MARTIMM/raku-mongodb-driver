use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Server;
use MongoDB::Server::Monitor;
use MongoDB::Socket;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");


#-------------------------------------------------------------------------------
subtest {

  my $p1 = $Test-support::server-control.get-port-number('s1');
  my MongoDB::Server $server .= new( :host<localhost>, :port($p1));

  my MongoDB::Server::Monitor $monitor .= new;
  $monitor.monitor-looptime = 1;
  $monitor.monitor-init(:$server);
  $monitor.monitor-server;

  my Supply $s = $monitor.Supply;
  $s.act( {
      ok $_<ok>, 'Monitoring is ok';
      ok $_<weighted-mean-rtt> > 0.0, "Weighted mean is $_<weighted-mean-rtt>";
      ok $_<monitor><ok>, 'Ok response from server';
      ok $_<monitor><ismaster>, 'Is master';
    }
  );

  sleep 2;
  $monitor.done;
  say 'done monitoring';
  sleep 2;

}, 'Monitor test';

#-------------------------------------------------------------------------------
subtest {

  my $p2 = $Test-support::server-control.get-port-number('s1');
  my MongoDB::Server $server .= new( :host<localhost>, :port($p2));
  is  $server.server-status, MongoDB::C-UNKNOWN-SERVER, "Status is Unknown";

  $server.server-init;
  $server.server-monitor.monitor-looptime = 1;
  $server.tap-monitor( {
      ok $_<ok>, 'Monitoring is ok';
      ok $_<weighted-mean-rtt> > 0.0, "Weighted mean is $_<weighted-mean-rtt>";
      ok $_<monitor><ok>, 'Ok response from server';
      ok $_<monitor><ismaster>, 'Is master';
    }
  );

  sleep 2;
  $server.stop-monitor;

  is $server.server-status, MongoDB::C-MASTER-SERVER,
     "Status is standalone master";

}, 'Server test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);


=finish

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
