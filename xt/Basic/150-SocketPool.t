use v6;
#use lib 't', 'lib';

use Test;

#use Test-support;
use MongoDB;
use MongoDB::SocketPool::Socket;
use MongoDB::SocketPool;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/150-SocketPool.log".IO.open(
  :mode<wo>, :create, :truncate
);
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::SocketPool $sockets;

#-------------------------------------------------------------------------------
subtest "SocketPool creation", {
  dies-ok( { $sockets .= new; }, '.new() not allowed');

  $sockets .= instance;
  isa-ok $sockets, MongoDB::SocketPool;
}

#-------------------------------------------------------------------------------
subtest "SocketPool manipulations", {

my $t0 = now;
  my IO::Socket::INET $s = $sockets.get-socket( 'www.google.com', 80);
note now - $t0;
  isa-ok $s, IO::Socket::INET;
}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();