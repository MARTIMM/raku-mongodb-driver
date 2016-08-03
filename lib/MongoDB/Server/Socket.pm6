use v6.c;

use MongoDB;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
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

