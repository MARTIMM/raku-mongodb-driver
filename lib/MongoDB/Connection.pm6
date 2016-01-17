use v6;
use MongoDB::ClientIF;
use MongoDB::DatabaseIF;
use BSON::Document;

package MongoDB {

  class Connection {

    has $.server-port;
    has $.server-name;
    has $.rtt;
    has IO::Socket::INET $!sock;
    has Bool $.status = False;
    has Bool $.is-master = False;
    has Promise $!monitor;
    has MongoDB::DatabaseIF $!db-admin;
    has MongoDB::ClientIF $!client;

    submethod BUILD (
      MongoDB::ClientIF :$client!,
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
      MongoDB::DatabaseIF:D :$db-admin!
    ) {
      $!db-admin = $db-admin;
      $!client = $client;
      $!server-name = $host;
      $!server-port = $port;

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
        $!sock .= new( :host($!server-name), :port($!server-port));
        $!status = True;

        # Must close this because of thread errors when reading the socket
        #
        self.close;

        # IO::Socket::INET throws an exception when there is no server response.
        # So we catch it here and set the status to False to show there is no
        # server found.
        #
        CATCH {
          default {
            $!status = False;
          }
        }
      }
    }

    #---------------------------------------------------------------------------
    #
    method open ( --> Nil ) {
      $!sock .= new( :host($!server-name), :port($!server-port))
        unless $!sock.defined;
    }

    #---------------------------------------------------------------------------
    #
    method send ( Buf:D $b --> Nil ) {
#      $!sock .= new( :host($!server-name), :port($!server-port))
#        unless $!sock.defined;
      $!sock.write($b);
    }

    #---------------------------------------------------------------------------
    #
    method receive ( Int $nbr-bytes --> Buf ) {
#      $!sock .= new( :host($!server-name), :port($!server-port))
#        unless $!sock.defined;
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

    #---------------------------------------------------------------------------
    #
    method !check-is-master ( ) {
      my BSON::Document $doc = $!db-admin.run-command: (isMaster => 1);
      $!is-master = $doc<ismaster>;
    }
  }
}
