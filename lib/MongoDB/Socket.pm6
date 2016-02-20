use v6.c;

package MongoDB {

  class Socket {

    has IO::Socket::INET $!sock;

    has Bool $.is-open;
    has $!server where .^name eq 'MongoDB::Server';

    #---------------------------------------------------------------------------
    #
    submethod BUILD (
      :$server! where .^name eq 'MongoDB::Server',
    ) {
      $!server = $server;
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
        :host($!server.server-name),
        :port($!server.server-port)
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
