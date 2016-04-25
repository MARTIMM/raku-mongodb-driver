use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Server::Control;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
#
diag "\n\nSetting up involves initializing mongodb data files which takes time";
for @$Test-support::server-range -> $server-number {
  ok $Test-support::server-control.start-mongod("s$server-number"),
     "Server $server-number started";
}

#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
