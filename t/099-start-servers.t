use v6;
use lib 't';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Server::Control;

#------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
info-message("Test $?FILE start");

#------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
try {
  for @($ts.serverkeys) -> $skey {
    ok $ts.server-control.start-mongod($skey), "Server $skey started";
  }

  CATCH {
    default {
      shell "type C:\\projects\\mongo-perl6-driver\\Sandbox\\Server-s1\\m.log";
    }
  }
}

throws-like
  { $ts.server-control.start-mongod($ts.serverkeys[0]) },
  X::MongoDB, "Failed to start server {$ts.serverkeys[0]} a 2nd time",
  :message(/:s exited unsuccessfully/);

#------------------------------------------------------------------------------
# Cleanup and close
done-testing;
