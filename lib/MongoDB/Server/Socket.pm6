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

  has Bool $.is-open;
  has MongoDB::ServerType $!server;

  #-----------------------------------------------------------------------------
  submethod BUILD ( MongoDB::ServerType:D :$server ) {

    $!server = $server;
    $!is-open = False;
  };

  #-----------------------------------------------------------------------------
  method open ( --> Nil ) {

    # We cannot test server status when there is some communication going on
    # using the same port. So only when the port must be opened, we know that
    # we can start something of our own before returning the connection.
    #
    $!sock .= new(
      :host($!server.server-name),
      :port($!server.server-port)
    ) unless $!sock.defined;

    trace-message("open socket");
    $!is-open = True;
  }

  #-----------------------------------------------------------------------------
  method send ( Buf:D $b --> Nil ) {

#TODO Check if sock is usable
    debug-message("socket send, size: $b.elems()");
    $!sock.write($b);
  }

  #-----------------------------------------------------------------------------
  method receive ( int $nbr-bytes --> Buf ) {

#TODO Check if sock is usable
    my Buf $b = $!sock.read($nbr-bytes);
    debug-message("socket receive, request size $nbr-bytes, received size $b.elems()");
    $b;
  }

  #-----------------------------------------------------------------------------
  method close ( ) {
    if $!sock.defined {
      $!sock.close;
      $!sock = Nil;
    }

    trace-message("close socket");
    $!is-open = False;
  }
}

