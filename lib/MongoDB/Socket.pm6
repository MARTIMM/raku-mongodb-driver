use v6.c;

package MongoDB {

  class Socket {

    has IO::Socket::INET $!sock;

    has Str $.server-name;
    has Int $.server-port;
    has Int $.rtt;
    has Bool $.is-open;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str:D :$server-name!, Int:D :$server-port!) {
      $!server-port = $server-port;
      $!server-name = $server-name;
      $!rtt = 0;
      $!is-open = False;
    };

    #---------------------------------------------------------------------------
    #
    method open ( --> Nil ) {

      # We cannot test server status when there is some communication going on
      # using the same port. So only when the port must be opened, we know that
      # we can start something of our own before returning the connection.
      #
      $!sock .= new(
        :host($!server-name),
        :port($!server-port)
      ) unless $!sock.defined;
      $!is-open = True;
    }

    #---------------------------------------------------------------------------
    #
    method send ( Buf:D $b --> Nil ) {
#TODO Check if sock is usable
      $!sock.write($b);
    }

    #---------------------------------------------------------------------------
    #
    method receive ( Int $nbr-bytes --> Buf ) {
#TODO Check if sock is usable
      return $!sock.read($nbr-bytes);
    }

    #---------------------------------------------------------------------------
    #
    method close ( ) {
      if $!sock.defined {
        $!sock.close;
        $!sock = Nil;
      }

      $!is-open = False;
    }
  }
}
