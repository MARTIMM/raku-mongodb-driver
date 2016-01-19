use v6;
use MongoDB;
use MongoDB::Socket;
use MongoDB::ClientIF;
use MongoDB::DatabaseIF;
use BSON::Document;

package MongoDB {

  class Server {

    has Str $.server-name;
    has Int $.server-port;

    has MongoDB::Socket @!sockets;
    has Int $.max-sockets is rw;
    has Bool $.status = False;
    has Bool $.is-master = False;

    has Promise $!monitor;

    has MongoDB::DatabaseIF $!db-admin;
    has MongoDB::ClientIF $!client;

    submethod BUILD (
      MongoDB::ClientIF :$client!,
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
      MongoDB::DatabaseIF:D :$db-admin!,
      Int :$max-sockets where $_ >= 3 = 3
    ) {
      $!db-admin = $db-admin;
      $!client = $client;
      $!server-name = $host;
      $!server-port = $port;
      $!max-sockets = $max-sockets;

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
        my IO::Socket::INET $sock .= new(
          :host($!server-name),
          :port($!server-port)
        );

        $!status = True;

        # Must close this because of thread errors when reading the socket
        # Besides the sockets are encapsulated in Socket and kept in an array.
        #
        $sock.close;

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
    # Search in the array for a closed Socket.
    #
    method get-socket ( --> MongoDB::Socket ) {

      my MongoDB::Socket $s;

      for @!sockets -> $sock {
        if ! $sock.is-open {
          $s = $sock;
          last;
        }
      }

      # If none is found insert a new Socket in the array
      #
      if ! $s.defined {
        
        # Protect against too many open sockets.
        #
        if @!sockets.elems >= $!max-sockets {
          die X::MongoDB.new(
            error-text => "Too many sockets opened, max is $!max-sockets",
            oper-name => 'MongoDB::Server.get-socket()',
            severity => MongoDB::Severity::Error
          );
        }

        $s .= new( :$!server-port, :$!server-name);
        @!sockets.push($s);
      }

      # Return a usable socket which is opened. The user has the responsibility
      # to close the socket. Otherwise there will be new sockets created every
      # time get-socket() is called.
      #
      $s.open();

      return $s;
    }

    #---------------------------------------------------------------------------
    #
    method check-is-master ( --> Bool ) {
      my BSON::Document $doc = $!db-admin.run-command: (isMaster => 1);
      $!is-master = $doc<ismaster>;
    }

    #---------------------------------------------------------------------------
    #
    method shutdown ( Bool :$force = False ) {
      my BSON::Document $doc = $!db-admin.run-command: (
        shutdown => 1,
        :$force
      );
#TODO is there an answer?

      if $doc<ok> {
        $!client.remove-server(self);
      }
    }
  }
}
