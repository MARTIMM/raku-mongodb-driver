#!/usr/bin/env -S raku -I lib

use v6;
use lib 'lib', 't';
use Test;
use Test-support;

#-------------------------------------------------------------------------------
sub MAIN ( *@tests, Str :$serverkeys, Bool :$ignore = False ) {

  # Set server list in environment
  my MongoDB::Test-support $ts .= new;
  $ts.serverkeys($serverkeys);

  # Set perl6 lib in environment
  %*ENV<RAKULIB> = 'lib';

  # Run the tests and return exit code if not ignored
  my Str $cmd = "prove -v -e perl6 " ~ @tests.join(' ');
  $cmd ~= ' || echo "failures ignored, these tests are for developers"'
    if $ignore;
  my Proc $p = shell $cmd;
  exit $p.exitcode;
}
