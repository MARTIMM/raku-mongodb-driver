use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-----------------------------------------------------------------------------
for $ts.server-range -> $server-number {

  try {
    ok $ts.server-control.stop-mongod('s' ~ $server-number),
       "Server $server-number is stopped";
    CATCH {
      when X::MongoDB::Message {
        like .message, /:s exited unsuccessfully/,
             "Server 's$server-number' already down";
      }
    }
  }
}

throws-like { $ts.server-control.stop-mongod('s1') },
            X::MongoDB::Message, :message(/:s exited unsuccessfully/);

$ts.cleanup-sandbox();

#-----------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE start");
sleep .2;
drop-all-send-to();
done-testing();
exit(0);
