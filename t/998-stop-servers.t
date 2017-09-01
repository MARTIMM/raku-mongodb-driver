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
try {
  for @($ts.serverkeys) -> $skey {
    ok $ts.server-control.stop-mongod($skey), "Server $skey is stopped";
    CATCH {
      when X::MongoDB {
        like .message, /:s exited unsuccessfully/, "Server $skey already down";
      }
    }
  }
}

throws-like
  { $ts.server-control.stop-mongod($ts.serverkeys[0]) },
  X::MongoDB, 'Failed to stop server a 2nd time',
  :message(/:s exited unsuccessfully/);

#------------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE start");
sleep .2;
drop-all-send-to();
done-testing();