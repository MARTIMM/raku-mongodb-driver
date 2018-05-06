use v6;
use lib 't';
use Test;
use Test-support;
use MongoDB;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
subtest 'Cleanup sandbox and server data', {
  MongoDB::Test-support.new.cleanup-sandbox;
  nok "$*CWD/Sandbox".IO.d, "Sandbox deleted";
}

#-------------------------------------------------------------------------------
done-testing;
