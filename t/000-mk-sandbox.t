use v6.c;
use lib 't';
use Test-support;
use MongoDB;
use Test;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
#
diag "\n\nSetting up involves initializing mongodb data files which takes time";

#-------------------------------------------------------------------------------
# Check directory Sandbox
#
mkdir( 'Sandbox', 0o700) unless 'Sandbox'.IO ~~ :d;
my $start-portnbr = 65000;

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

  if !start-mongod( $server-dir, :port($port-number) ) {
    plan 1;
    flunk('No database server started!');
    skip-rest('No database server started!');
    exit(0);
  }
}

#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
