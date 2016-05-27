use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Server;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
subtest {

  my $p3 = $ts.server-control.get-port-number('s3');
  my MongoDB::Server $server .= new(:server-name("localhost:$p3"));

  my MongoDB::Server::Monitor $monitor .= new(:$server);
  $monitor.start-monitor;

  my Supply $s = $monitor.get-supply;
  $s.act( -> Hash $mdata {
      ok $mdata<ok>, 'Monitoring is ok';
      ok $mdata<weighted-mean-rtt> > 0.0,
         "Weighted mean is $mdata<weighted-mean-rtt>";
      ok $mdata<monitor><ok>, 'Ok response from server';
      ok $mdata<monitor><ismaster>, 'Is master';
    }
  );

  sleep 2;
  $monitor.done;
  sleep 2;

}, 'Monitor test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Server $server .= new(
    :server-name("an-unknown-server.with-unknown-domain:65535")
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

  my MongoDB::Server $server .= new(:server-name("localhost:65535"));
  sleep 1;
  is $server.get-status, MongoDB::C-UNKNOWN-SERVER, "Status is unknown";

  $server.server-init;
  $server.tap-monitor( {
      nok $_<ok>, 'Monitoring is not ok';
    }
  );

  sleep 2;
  $server.stop-monitor;

  # Race conditions
  sleep 2;
  is $server.get-status, MongoDB::C-DOWN-SERVER, "Server is down";

}, 'Down server test';

#-------------------------------------------------------------------------------
subtest {

  my $p3 = $ts.server-control.get-port-number('s3');
  my MongoDB::Server $server .= new(:server-name("localhost:$p3"));
  sleep 1;
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

  sleep 2;
  is $server.get-status, MongoDB::C-MASTER-SERVER,
     "Status is standalone master";

}, 'Server test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
