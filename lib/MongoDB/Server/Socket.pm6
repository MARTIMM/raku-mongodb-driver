use v6;

use MongoDB;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

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
  has MongoDB::ServerType $.server;

  #-----------------------------------------------------------------------------
  submethod BUILD ( MongoDB::ServerType:D :$!server ) {

    $!is-open = True;
    $!thread-id = $*THREAD.id;
    $!time-last-used = time;
    trace-message("open socket $!server.server-name(), $!server.server-port()");
sleep 1;
    $!sock .= new( :host($!server.server-name), :port($!server.server-port));
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

#`{{
  #-----------------------------------------------------------------------------
  # Open socket, returns True when already opened before otherwise it is opened
  method open ( --> Bool ) {
return True;

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();

note "$*THREAD.id() open: $!is-open";
    return True if $!is-open;

note "Open server $!server.server-name(), $!server.server-port()";
    $!sock .= new( :host($!server.server-name), :port($!server.server-port))
      unless $!sock.defined;
note $!sock.perl;


    trace-message("open socket $!server.server-name(), $!server.server-port()");
    $!is-open = True;
    $!time-last-used = time;

    False;
  }
}}

  #-----------------------------------------------------------------------------
  method send ( Buf:D $b --> Nil ) {

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();

    fatal-message("Socket not opened") unless $!sock.defined;

    trace-message("socket send, size: $b.elems()");
    $!sock.write($b);
    $!time-last-used = time;
  }

  #-----------------------------------------------------------------------------
  method receive ( int $nbr-bytes --> Buf ) {

    fatal-message("thread $*THREAD.id() is not owner of this socket")
      unless $.thread-id == $*THREAD.id();

    fatal-message("socket not opened") unless $!sock.defined;

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
        $!sock = Nil;
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
