use v6;
use MongoDB;

package MongoDB {

  class Connection {
  
    has $.server-port;
    has $.server-name;
    has $.rtt;
    has IO::Socket::INET $!sock;
    has Exception $.status = Nil;

    submethod BUILD (
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
    ) {
      $!server-name = $host;
      $!server-port = $port;

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
        $!status = Nil;

        $!sock .= new( :host($!server-name), :port($!server-port))
          unless $!sock.defined;

        CATCH {
          default {
            $!status = X::MongoDB.new(
              :error-text("Failed to connect to $!server-name at port $!server-port"),
              :oper-name<new>,
              :severity(MongoDB::Severity::Error)
            );
          }
        }
      }
    }

    #---------------------------------------------------------------------------
    #
    method send ( Buf:D $b --> Nil ) {
      $!sock.write($b);
    }

    #---------------------------------------------------------------------------
    #
    method receive ( Int $nbr-bytes --> Buf ) {
      return $!sock.read($nbr-bytes);
    }

    #---------------------------------------------------------------------------
    #
    method close ( ) {
      if $!sock.defined {
        $!sock.close;
        $!sock = Nil;
      }
    }
  }
}
