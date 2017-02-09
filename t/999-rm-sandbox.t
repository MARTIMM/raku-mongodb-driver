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
#
for $ts.server-range -> $server-number {

  ok $ts.server-control.stop-mongod('s' ~ $server-number),
     "Server $server-number is stopped";
}

$ts.cleanup-sandbox();

#-----------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE start");
sleep .2;
drop-all-send-to();
done-testing();
exit(0);
