use v6;
use lib 't';
use Test;
use Test-support;
use MongoDB;

#------------------------------------------------------------------------------
#drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
info-message("Test $?FILE start");

#------------------------------------------------------------------------------
subtest 'Create new sandbox and server environments', {
  MongoDB::Test-support.new.create-sandbox;
  ok "$*CWD/Sandbox".IO.d, "Sandbox created";
}

#------------------------------------------------------------------------------
done-testing;
