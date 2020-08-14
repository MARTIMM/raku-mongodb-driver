use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::SocketPool

B<MongoDB::SocketPool> provides a way to get a socket from a pool of sockets using a hostname and portnumber.

Its purpose is to reuse sockets whithout reconnectiing all the time and authenticating when needed.

Exceptions are thrown when opening a socket fails.

Several sockets must possibly be created for one server. The purpose of this is to;

=item Distinguish between several client objects.
=item With or without authentication for several credentials and mechanisms.

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
use MongoDB::Uri;
use MongoDB::SocketPool::Socket;

use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit class MongoDB::SocketPool:auth<github:MARTIMM>;

my MongoDB::SocketPool $instance;

# servers can have more opened sockets to control connections with or without
# authentication and with different credentials if authenticated. And different
# clients using the same servers. There is only one set of credentials per uri.
# if there is no authentication, username is set to an empty string and uri
# will not be set.

# ?? $!socket-info{client-key}{host port}{username}<socket> = socket
# ?? $!socket-info{client-key}{host port}{username}<uri> = uri-obj
# $!socket-info{client-key}{host port}{username} = socket
has Hash $!socket-info;

has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  trace-message("socket pool initialized");
  $!socket-info = {};

  $!rw-sem .= new;
  #$rw-sem.debug = True;
  $!rw-sem.add-mutex-names( <socketpool>, :RWPatternType(C-RW-WRITERPRIO));
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
  Str:D $client-key, Str:D $host, Int:D $port, MongoDB::Uri $uri-obj?
  # Str :$username, Str :$password
  --> MongoDB::SocketPool::Socket
) {

#next info shows that sockets have become thread save
#trace-message("get-socket: $host, $port $*THREAD.id()");

  my MongoDB::SocketPool::Socket $socket;
#  my Int $thread-id = $*THREAD.id();

  my Str $username = $uri-obj ?? $uri-obj.credentials.username !! '';
  $!rw-sem.writer( 'socketpool', {
      $!socket-info{$client-key} = %() unless $!socket-info{$client-key}:exists;
      $!socket-info{$client-key}{"$host $port"} = %()
        unless $!socket-info{$client-key}{"$host $port"}:exists;
    }
  );

  if $!rw-sem.reader( 'socketpool', {
      $!socket-info{$client-key}{"$host $port"}{$username}:exists; }
  ) {
    $socket = $!socket-info{$client-key}{"$host $port"}{$username};
  }

  else {
    if ? $username {
      $socket .= new( :$host, :$port, :$uri-obj);
    }

    else {
      $socket .= new( :$host, :$port);
    }

    if $socket {
      trace-message("socket created for server $host:$port");
      $!rw-sem.writer( 'socketpool', {
          $!socket-info{$client-key}{"$host $port"}{$username} = $socket;
#          $!socket-info{$client-key}{"$host $port"}{$username}<socket> = $socket;
#          $!socket-info{$client-key}{"$host $port"}{$username}<uri> = $uri-obj;
        }
      );
    }
  }

  $socket
}

#-------------------------------------------------------------------------------
# close and remove a socket belonging to the server on the current thread
method cleanup ( Str $client-key ) {

  my Hash $si-cl = $!rw-sem.writer( 'socketpool', {
      $!socket-info{$client-key}:delete // %();
    }
  );

  for $si-cl.keys -> $host-port {
    for $si-cl{$host-port}.keys -> $un {
      my $s = $si-cl{$host-port}{$un};
      $s.close;

      if ? $un {
        trace-message("cleanup socket for server $host-port and user $un");
      }

      else {
        trace-message("cleanup socket for server $host-port");
      }
    }
  }
}

#-------------------------------------------------------------------------------
