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

    # As in MongoDB::Uri without servers key. So there are
    # database, username, password and options
    #
    has Hash $!server-data;

    has MongoDB::Socket @!sockets;
    has Int $.max-sockets is rw where $_ >= 3;
    has Bool $.status = False;

    has Bool $.is-master = False;
    has Int $.max-bson-object-size;
    has Int $.max-write-batch-size;
    has Duration $!weighted-mean-rtt .= new(0);

    has MongoDB::DatabaseIF $!db-admin;
    has MongoDB::ClientIF $!client;

    has Channel $!channel;
    has Promise $!server-monitor-code;

    submethod BUILD (
      MongoDB::ClientIF :$client!,
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
      MongoDB::DatabaseIF:D :$db-admin!,
      Int :$max-sockets where $_ >= 3 = 3,
      Hash :$server-data
    ) {
      $!db-admin = $db-admin;
      $!client = $client;
      $!server-name = $host;
      $!server-port = $port;
      $!max-sockets = $max-sockets;
      $!server-data = $server-data;
      $!channel = Channel.new;

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
        my IO::Socket::INET $sock .= new(
          :host($!server-name),
          :port($!server-port)
        );

        $!status = True;

        $!server-monitor-code .= start( {
            while 1 {
#              my BSON::Document $doc = $!db-admin.run-command: (isMaster => 1);

              my $cmd = $!channel.poll;
              last if ?$cmd and $cmd eq 'stop';
              sleep 10;
            }
          }
        );

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
          return X::MongoDB.new(
            error-text => "Too many sockets opened, max is $!max-sockets",
            oper-name => 'MongoDB::Server.get-socket',
            severity => MongoDB::Severity::Fatal
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
      my Instant $t0 = now;
      my BSON::Document $doc = $!db-admin.run-command: (isMaster => 1);
      my Duration $rtt = now - $t0;
      $!weighted-mean-rtt .= new(0.2 * $rtt + 0.8 * $!weighted-mean-rtt);
#say "Weighted mean RTT: $!weighted-mean-rtt";
      $!is-master = $doc<ismaster>;
#say $doc.perl;

      # When not defined set these too
      #
      unless ?$!max-bson-object-size {
        $!max-bson-object-size = $doc<maxBsonObjectSize>;
        $!max-write-batch-size = $doc<maxWriteBatchSize>;
      }

      return $!is-master;
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

    #---------------------------------------------------------------------------
    #
    submethod DESTROY {

      # Send a stop code to the monitor code thread and wait for it to finish
      #
      $!channel.send('stop');
      $!server-monitor-code.await;
      undefine $!server-monitor-code;

      # Clear all sockets
      #
      for @!sockets -> $s {
        undefine $s;
      }

      # and channel
      #
      undefine $!channel;
    }
  }
}
