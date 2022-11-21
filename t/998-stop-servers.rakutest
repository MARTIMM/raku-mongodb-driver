use v6;
use lib 't';

use Test;
use Test-support;
use MongoDB;

#------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;
$ts.serverkeys('s1');
my Hash $clients = $ts.create-clients;
my MongoDB::Client $cl = $clients{$clients.keys[0]};
my Str $uri = $cl.uri-obj.uri;

#------------------------------------------------------------------------------
for @($ts.serverkeys) -> $skey {

  $ts.server-control.stop-mongod( $skey, $uri);
  ok 1, 'server down';
}

#`{{
throws-like
  { $ts.server-control.stop-mongod($ts.serverkeys[0]) },
  X::MongoDB, "Failed to stop server {$ts.serverkeys[0]} a 2nd time",
  :message(/:s exited unsuccessfully/);
}}

#------------------------------------------------------------------------------
# Cleanup and close
info-message("Test $?FILE start");
#sleep .2;
#drop-all-send-to();
done-testing();
