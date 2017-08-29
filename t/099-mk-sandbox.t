use v6;
use lib 't';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Server::Control;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Debug));
info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
try {
  $ts.server-control.start-mongod('s1');
  CATCH {
    when X::MongoDB {
      like .message, /:s exited unsuccessfully/, "Server 's1' already started";
    }
  }
}

throws-like
  { $ts.server-control.start-mongod('s1') },
  X::MongoDB, 'Failed to start server a 2nd time',
  :message(/:s exited unsuccessfully/);

#-------------------------------------------------------------------------------
# Cleanup and close
done-testing;
