use v6;
use lib 't';

use Test;
use Test-support;
use MongoDB;

#------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#------------------------------------------------------------------------------
for @($ts.serverkeys) -> $skey {
  ok $ts.server-control.stop-mongod($skey), "Server $skey is stopped";
}

throws-like
  { $ts.server-control.stop-mongod($ts.serverkeys[0]) },
  X::MongoDB, "Failed to stop server {$ts.serverkeys[0]} a 2nd time",
  :message(/:s exited unsuccessfully/);

#------------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE start");
sleep .2;
drop-all-send-to();
done-testing();
