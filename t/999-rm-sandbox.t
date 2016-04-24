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

  my Str $server-dir = "Sandbox/Server$server-number";
#  stop-mongod($server-dir);
  ok 1, (stop-mongod($server-dir) ?? 'Server is stopped' !! 'Server already stopped');
#  ok stop-mongod($server-dir), "Server from $server-dir stopped";
}

cleanup-sandbox();

#-----------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE start");
done-testing();
exit(0);
