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

    trace-message("new socket");
  };

  #-----------------------------------------------------------------------------
  method check ( --> Bool ) {

    my Bool $is-closed = False;
    if (time - $!time-last-used) > MAX-SOCKET-UNUSED-OPEN {

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

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();
    return True if $!is-open;

    $!sock .= new( :host($!server.server-name), :port($!server.server-port))
      unless $!sock.defined;

    $!thread-id = $*THREAD.id;

    trace-message("open socket");
    $!is-open = True;
    $!time-last-used = time;
    
    False;
  }

  #-----------------------------------------------------------------------------
  method send ( Buf:D $b --> Nil ) {

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();

    fatal-message("Socket not opened") unless $!sock.defined;

#TODO Check if sock is usable
    trace-message("socket send, size: $b.elems()");
    $!sock.write($b);
    $!time-last-used = time;
  }

  #-----------------------------------------------------------------------------
  method receive ( int $nbr-bytes --> Buf ) {

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();

    fatal-message("socket not opened") unless $!sock.defined;

#TODO Check if sock is usable
    my Buf $b = $!sock.read($nbr-bytes);
    $!time-last-used = time;
    trace-message("socket receive, request size $nbr-bytes, received size $b.elems()");
    $b;
  }

  #-----------------------------------------------------------------------------
  method close ( ) {

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();

    $!sock.close if $!sock.defined;
    $!sock = Nil;

    trace-message("Close socket");
    $!is-open = False;
    $!time-last-used = time;
  }

  #-----------------------------------------------------------------------------
  method close-on-fail ( ) {

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();

    trace-message("'close' socket on failure");
    $!sock = Nil;
    $!is-open = False;
    $!time-last-used = time;
  }

  #-----------------------------------------------------------------------------
  method cleanup ( ) {

    # Close can have exceptions
    try {
      if $!sock.defined {
        $!sock.close;
      }
      
      else {
        $!sock = Nil;
      }
      
      $!is-open = False;

      CATCH {
        $!sock = Nil;
        $!is-open = False;
      }
    }
  }
}

