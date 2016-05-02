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

#-------------------------------------------------------------------------------
subtest {

  my $p1 = $Test-support::server-control.get-port-number('s1');
  my MongoDB::Server $server .= new( :host<localhost>, :port($p1));

  my MongoDB::Server::Monitor $monitor .= new;
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
  sleep 2;

}, 'Monitor test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Server $server .= new(
    :host<an-unknown-server.with-unknown-domain>,
    :port(65535)
  );
  is $server.get-status, MongoDB::C-UNKNOWN-SERVER, "Status is Unknown";

  $server.server-init;
  $server.tap-monitor( {
      nok $_<ok>, 'Monitoring is not ok';
    }
  );

  sleep 2;

  is $server.get-status, MongoDB::C-NON-EXISTENT-SERVER,
     "Server is non existent";

  $server.stop-monitor;
}, 'Non existent server test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Server $server .= new( :host<localhost>, :port(65535));
  is $server.get-status, MongoDB::C-UNKNOWN-SERVER, "Status is unknown";

  $server.server-init;
  $server.tap-monitor( {
      nok $_<ok>, 'Monitoring is not ok';
    }
  );

  sleep 2;
  $server.stop-monitor;

  is $server.get-status, MongoDB::C-DOWN-SERVER, "Server is down";

}, 'Down server test';

#-------------------------------------------------------------------------------
subtest {

  my $p2 = $Test-support::server-control.get-port-number('s1');
  my MongoDB::Server $server .= new( :host<localhost>, :port($p2));
  is $server.get-status, MongoDB::C-UNKNOWN-SERVER, "Status is Unknown";

  $server.server-init;
  $server.tap-monitor( {
      ok $_<ok>, 'Monitoring is ok';
      ok $_<weighted-mean-rtt> > 0.0, "Weighted mean is $_<weighted-mean-rtt>";
      ok $_<monitor><ok>, 'Ok response from server';
      ok $_<monitor><ismaster>, 'Is master';
    }
  );

  sleep 2;
  $server.stop-monitor;

  is $server.get-status, MongoDB::C-MASTER-SERVER,
     "Status is standalone master";

}, 'Server test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
