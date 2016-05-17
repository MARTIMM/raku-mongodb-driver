use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-----------------------------------------------------------------------------
#
for $ts.server-range -> $server-number {

  ok $ts.server-control.stop-mongod('s' ~ $server-number),
     "Server $server-number is stopped";
}

$ts.cleanup-sandbox();

#-----------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE start");
done-testing();
exit(0);
