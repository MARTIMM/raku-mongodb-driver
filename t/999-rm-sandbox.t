use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

#-----------------------------------------------------------------------------
#
for @$Test-support::server-range -> $server-number {

  ok $Test-support::server-control.stop-mongod('s' ~ $server-number),
     "Server $server-number is stopped";
}

cleanup-sandbox();

#-----------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE start");
done-testing();
exit(0);
