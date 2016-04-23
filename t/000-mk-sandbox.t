use v6.c;
use lib 't';
use Test-support;
use MongoDB;
use MongoDB::Server::Control;
use Test;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
#
diag "\n\nSetting up involves initializing mongodb data files which takes time";

#-------------------------------------------------------------------------------
# Check directory Sandbox and start config file
#
mkdir( 'Sandbox', 0o700) unless 'Sandbox'.IO ~~ :d;
my Int $start-portnbr = 65000;
my Str $config-text = Q:qq:to/EOCONFIG/;

  # Configuration file for the servers in the Sandbox
  #
  [Account]
    user = 'test_user'
    pwd = 'T3st-Us3r'

  [Server-Binary]
    path = '$*CWD/Travis-ci/MongoDB/mongod'

  [Servers]
    nojournal = true
    fork = true

  EOCONFIG


#-------------------------------------------------------------------------------
for @$Test-support::server-range -> $server-number {

  my Str $server-dir = "Sandbox/Server$server-number";
  mkdir( $server-dir, 0o700) unless $server-dir.IO ~~ :d;
  mkdir( "$server-dir/m.data", 0o700) unless "$server-dir/m.data".IO ~~ :d;

  my Int $port-number = find-next-free-port($start-portnbr);
  ok $port-number >= $start-portnbr,
     "Portnumber for server $server-number $port-number";
  $start-portnbr = $port-number + 1;

  # Save portnumber for later tests
  #
  spurt "$server-dir/port-number", $port-number;

  $config-text ~= Q:qq:to/EOCONFIG/;

    # Configuration for Server $server-number
    #
    [Servers.s$server-number]
      logpath = '$*CWD/$server-dir/m.log'
      pidfilepath = '$*CWD/$server-dir/m.pid'
      dbpath = '$*CWD/$server-dir/m.data'
      port = $port-number

    [Servers.s$server-number.replicate]
      replSet = 'test_replicate'

    [Servers.s$server-number.authenticate]
      auth = true

    EOCONFIG
}

my Str $file = 'Sandbox/config.toml';
spurt( $file, $config-text);

my MongoDB::Server::Control $msc .= new(:$file);
for @$Test-support::server-range -> $server-number {
  ok $msc.start-mongod("s$server-number"), "Server $server-number started";
}

#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
