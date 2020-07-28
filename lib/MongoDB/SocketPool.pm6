use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::SocketPool

B<MongoDB::SocketPool> provides a way to get a socket from a pool of sockets using a hostname and portnumber. Also a thread id is stored to prevent problems reading or writing to sockets created in another thread. Other information stored here is authentication and timeout information.

Its purpose is to reuse sockets whithout reconnectiing all the time. The entries are checked regularly to see if they are still used.

Exceptions are thrown when opening a socket fails.

=head2 Example

my MongoDB::SocketPool $sockets;
$sockets .= instance;
my MongoDB::Socket $socket = $sockets.get-socket( 'localhost', 27017);
$socket.send($buffer);
$buffer = $socket.receive(20);
$sockets.cleanup( 'localhost', 27017);

=end pod

#-------------------------------------------------------------------------------
use MongoDB;
#use MongoDB::ServerPool::Server;
use MongoDB::SocketPool::Socket;

#-------------------------------------------------------------------------------
unit class MongoDB::SocketPool:auth<github:MARTIMM>;

my MongoDB::SocketPool $instance;

has Hash $!socket-info;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!socket-info = {};
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> MongoDB::SocketPool ) {
  $instance = self.bless unless $instance;

  $instance
}

#-------------------------------------------------------------------------------
# Getting a socket will return an opened socket. It will first search for an
# existing one, if not found creates a new and stores it with the current
# thread id.
#multi method get-socket (
#  MongoDB::ServerPool::Server:D $server, Str :$username, Str :$password
#  --> IO::Socket::INET
#) {
#  self.get-socket( $server.host, $server.port, $username, $password);
#}

#multi
method get-socket (
  Str $host, Int $port, Str :$username, Str :$password
  --> MongoDB::SocketPool::Socket
) {

  my MongoDB::SocketPool::Socket $socket;
  my Int $thread-id = $*THREAD.id();

  if $!socket-info{"$host $port $*THREAD.id()"}:exists {
    $socket = $!socket-info{"$host $port $*THREAD.id()"}<socket>;
  }

  else {
    $socket .= new( :$host, :$port);
    $!socket-info{"$host $port $*THREAD.id()"} = %(
      :$socket, :$username, :$password
    ) if ?$socket;
  }

  $socket
}

#-------------------------------------------------------------------------------
# close and remove a socket belonging to the server on the current thread
multi method cleanup ( Str $host, Int $port ) {

  my Int $thread-id = $*THREAD.id();
  if $!socket-info{"$host $port $thread-id"}:exists {
    $!socket-info{"$host $port $thread-id"}<socket>.close;
    $!socket-info{"$host $port $thread-id"}:delete;
  }
}

#-------------------------------------------------------------------------------
# close and remove all sockets belonging to the current thread
multi method cleanup ( :$all! ) {

  for $!socket-info.keys -> $socket-pool-item {
    if $socket-pool-item ~~ m/ "$*THREAD.id()" $/ {
      $!socket-info{$socket-pool-item}<socket>.close;
      $!socket-info{$socket-pool-item}:delete;
    }
  }
}

#-------------------------------------------------------------------------------
