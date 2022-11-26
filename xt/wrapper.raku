#!/usr/bin/env -S rakudo -I lib

use lib 'xt';

use Test;
use TestLib::Test-support;


#-------------------------------------------------------------------------------
my Array $server-keys = [];

#-------------------------------------------------------------------------------
#sub MAIN ( *@tests, Str:D :$server, Bool :$ignore = False, Str:D :$version! ) {
sub MAIN (
  *@tests, Str:D :$servers, Bool :$start = False, Bool :$stop = False,
  Str :$version = '4.0.18'
) {

  # Always run from here raku-mongodb-driver root. It wouldn't find some
  # libs either.
  if $*CWD.IO.basename ne 'raku-mongodb-driver' {
    note "Please run from root directory of distribution. Now exiting...";
    exit 1;
  }

  # Set server list in environment
  $server-keys = [$servers.split(/\s* ',' \s*/)];
  my TestLib::Test-support $ts .= new;
  for @$server-keys -> $server-key {
    $ts.create-server-config( $server-key, Version.new($version));
    $ts.start-mongod( $server-key, $version) if $start;
  }


#`{{
  # Run the tests and return exit code if not ignored
  my Str $cmd = "prove -v -e perl6 " ~ @tests.join(' ');
  $cmd ~= ' || echo "failures ignored, these tests are for developers"'
    if $ignore;
  my Proc $p = shell $cmd;
  exit $p.exitcode;
}}
}

#-------------------------------------------------------------------------------
sub USAGE ( ) {
  say Q:s:to/EOUSAGE/;

    Wrapper to wrap a test sequence together with the choice of mongod or
    mongos servers. The program starts and stops the server when requested

    Command;
      wrapper.raku <options> <test list>
    
    Options
      servers           A comma separated list of keys. The keys are used in
                        the configuration file at 'xt/TestServers/config.yaml'.
      start             Start server before testing.
      stop              Stop server after testing.
      version           Version of the mongo servers to test. The version is
                        '4.0.18' by default.

    Arguments
      test list         A list of tests to run with the server. The path is a
                        simple shell regular expression and starts from
                        'xt/Tests'.

    Examples
      Testing accounting on a single server. The server key is 'simple'.

        wrapper.raku --version=3.6.9 --servers=simple 'Accounts/5*'

      Testing replica servers. Before tests are run, the servers are started.

        wrapper --servers=replica1,replica2 --start 'Behavior/61*'

      Stop servers without testing.

        wrapper --stop --servers=simple

    EOUSAGE
}
