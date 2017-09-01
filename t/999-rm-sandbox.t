use v6;
use lib 't';
use Test;
use Test-support;

#------------------------------------------------------------------------------
subtest 'Cleanup sandbox and server data', {
  MongoDB::Test-support.new.cleanup-sandbox;
  nok "$*CWD/Sandbox".IO.d, "Sandbox deleted";
}

#------------------------------------------------------------------------------
done-testing;
