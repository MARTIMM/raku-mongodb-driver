use v6;
use lib 't';
use Test;
use Test-support;

#------------------------------------------------------------------------------
subtest 'Create new sandbox and server environments', {
  MongoDB::Test-support.new.create-sandbox;
  ok "$*CWD/Sandbox".IO.d, "Sandbox created";
}

#------------------------------------------------------------------------------
done-testing;
