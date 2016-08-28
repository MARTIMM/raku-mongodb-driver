use v6.c;

use MongoDB;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
#TODO Sockets must initiate a handshake procedure when socket is opened. Perhaps
#  not needed because the monitor is keeping touch and known the type of the
#  server which is communicated to the Server and Client object
#TODO When authentication is needed it must be done on every opened socket

class Server::Socket {

  has IO::Socket::INET $!sock;
  has Int $.thread-id;
  has Int $.time-last-used;
#  has Bool $!must-authenticate;

  has Bool $.is-open;
  has MongoDB::ServerType $!server;

  #-----------------------------------------------------------------------------
  submethod BUILD ( MongoDB::ServerType:D :$server ) {

    $!server = $server;

    $!is-open = False;
    $!thread-id = $*THREAD.id;
    $!time-last-used = time;

    info-message("New socket for $!thread-id at time $!time-last-used");
  };

  #-----------------------------------------------------------------------------
  method check ( --> Bool ) {

    my Bool $is-closed = False;
    if (time - $!time-last-used) > C-MAX-SOCKET-UNUSED-OPEN {

      debug-message("close socket, timeout after {time - $!time-last-used} sec");
      $!sock.close if $!sock.defined;
      $!is-open = False;
      $is-closed = True;
    }

    $is-closed;
  }

  #-----------------------------------------------------------------------------
  # Open socket, returns True when already opened before otherwise it is opened
  method open ( --> Bool ) {

    die "Thread $*THREAD.id() is not owner of this socket"
      unless $.thread-id == $*THREAD.id();
    return True if $!is-open;

    $!sock .= new( :host($!server.server-name), :port($!server.server-port))
      unless $!sock.defined;

    $!thread-id = $*THREAD.id;

    trace-message("Open socket");
    $!is-open = True;
    $!time-last-used = time;
    
    False;
  }

  #-----------------------------------------------------------------------------
  method send ( Buf:D $b --> Nil ) {

    die "Thread $*THREAD.id() is not owner of this socket"
      unless $.thread-id == $*THREAD.id();

    die "Socket not opened" unless $!sock.defined;

#TODO Check if sock is usable
    debug-message("Socket send, size: $b.elems()");
    $!sock.write($b);
    $!time-last-used = time;
  }

  #-----------------------------------------------------------------------------
  method receive ( int $nbr-bytes --> Buf ) {

    die "Thread $*THREAD.id() is not owner of this socket"
      unless $.thread-id == $*THREAD.id();

    die "Socket not opened" unless $!sock.defined;

#TODO Check if sock is usable
    my Buf $b = $!sock.read($nbr-bytes);
    $!time-last-used = time;
    debug-message("Socket receive, request size $nbr-bytes, received size $b.elems()");
    $b;
  }

  #-----------------------------------------------------------------------------
  method close ( ) {

    die "Thread $*THREAD.id() is not owner of this socket"
      unless $.thread-id == $*THREAD.id();

    $!sock.close if $!sock.defined;
    $!sock = Nil;

    trace-message("Close socket");
    $!is-open = False;
    $!time-last-used = time;
  }

  #-----------------------------------------------------------------------------
  method close-on-fail ( ) {

    die "Thread $*THREAD.id() is not owner of this socket"
      unless $.thread-id == $*THREAD.id();

    trace-message("'Close' socket on failure");
    $!sock = Nil;
    $!is-open = False;
    $!time-last-used = time;
  }
}

