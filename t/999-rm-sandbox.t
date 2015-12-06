#`{{
  Setup sandbox
  Generate mongo config
  Start mongo daemon
  Test connection
}}

use lib 't';
use Test-support;
use MongoDB::Connection;

use v6;
use Test;

#-----------------------------------------------------------------------------
# Stop mongodb unless sandbox isn't found, no sandbox requested
#
if %*ENV<NOSANDBOX> or 'Sandbox/port-number'.IO !~~ :e {
  plan 1;
  skip-rest('No sand-boxing requested');
  exit(0);
}

#-----------------------------------------------------------------------------
#
my Int $port-number = slurp('Sandbox/port-number').Int;


my MongoDB::Connection $connection .= new( :host<localhost>, :port($port-number));
ok !? $connection.status, 'MongoDB still running';

diag "Wait for server to stop";
my $exit_code = shell("kill `cat $*CWD/Sandbox/m.pid`");
#diag $exit_code ?? "Server already stopped" !! "Server stopped";
sleep 2;
diag "Server stopped";

diag "Remove sandbox data";
for <Sandbox/m.data/journal Sandbox/m.data Sandbox> -> $path {
  next unless $path.IO ~~ :d;
  for dir($path) -> $dir-entry {
    if $dir-entry.IO ~~ :d {
#      diag "delete directory $dir-entry";
      rmdir $dir-entry;
    }

    else {
#      diag "delete file $dir-entry";
      unlink $dir-entry;
    }
  }
}

diag "delete directory Sandbox";
rmdir "Sandbox";

$connection .= new( :host<localhost>, :port($port-number));
ok ? $connection.status, 'MongoDB not running';

#-----------------------------------------------------------------------------
# Cleanup and close
#
done-testing();
exit(0);
