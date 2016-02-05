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
#    has Bool $.status = False;

    has Bool $.is-master = False;
    has Int $.max-bson-object-size;
    has Int $.max-write-batch-size;
    has Duration $!weighted-mean-rtt .= new(0);

    has MongoDB::DatabaseIF $!db-admin;
    has MongoDB::ClientIF $!client;

    # Variables to control infinit monitoring actions
    #
    has Channel $!channel;
    has Promise $!promise-monitor;
    has Semaphore $!server-monitor-control;

    submethod BUILD (
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
      Int :$max-sockets where $_ >= 3 = 3,
      Hash :$server-data
    ) {
      $!db-admin = $server-data<db-admin>;
      $!client = $server-data<client>;
      $!server-name = $host;
      $!server-port = $port;
      $!max-sockets = $max-sockets;
      $!server-data = $server-data;
      $!channel = Channel.new;

      $!server-monitor-control .= new(1);

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
#      try {
#        $!status = False;

        my IO::Socket::INET $sock .= new(
          :host($!server-name),
          :port($!server-port)
        );

#        $!status = True;

        # Must close this because of thread errors when reading the socket
        # Besides the sockets are encapsulated in Socket and kept in an array.
        #
        $sock.close;

        # IO::Socket::INET throws an exception when there is no server response.
        # So we catch it here and set the status to False to show there is no
        # server found.
        #
#        CATCH {
#          default {
#            $!status = False;
#            
#          }
#        }
#      }
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
          return fatal-message("Too many sockets opened, max is $!max-sockets");
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
    # Run this on a separate thread because it lasts until this program
    # atops or the server shuts down.
    #
    method monitor-server ( ) {

      # Set the lock so the code will only be started once. When server or
      # program stops, the code is terminated via a channel.
      #
      return unless $!server-monitor-control.try_acquire;

      $!promise-monitor .= start( {
          my Instant $t0;
          my BSON::Document $doc;
          my Duration $rtt;
          while 1 {

            # Calculation of mean Return Trip Time
            #
            $t0 = now;
            $doc = $!db-admin.run-command: (isMaster => 1);
            $rtt = now - $t0;
            $!weighted-mean-rtt .= new(0.2 * $rtt + 0.8 * $!weighted-mean-rtt);
            debug-message(
              "Weighted mean RTT: $!weighted-mean-rtt for server {self.name}"
            );

            # Set master type
            #
            $!is-master = $doc<ismaster> if ?$doc<ismaster>;
#say $doc.perl;

            # When not defined set these too
            #
            unless ?$!max-bson-object-size {
              $!max-bson-object-size = $doc<maxBsonObjectSize>;
              $!max-write-batch-size = $doc<maxWriteBatchSize>;
            }

            # Then check the channel to see if there is a stop command. If so
            # exit the while loop. Take a nap otherwise.
            #
            my $cmd = $!channel.poll;
            last if ?$cmd and $cmd eq 'stop';
            sleep 10;
          }
        }
      );
    }

    #---------------------------------------------------------------------------
    #
    method shutdown ( Bool :$force = False ) {
      my BSON::Document $doc = $!db-admin.run-command: (
        shutdown => 1,
        :$force
      );
#TODO there is no answer if it succeeds?

      # Suppose that there is only an answer when the server didn't shutdown
      # so what are we doing here ...
      #
      if $doc<ok> {
        $!client.remove-server(self);
      }
    }

    #---------------------------------------------------------------------------
    #
    method perl ( --> Str ) {
      return [~] 'MongoDB::Server.new(', ':host(', $.server-name, '), :port(',
                 $.server-port, '))';
    }

    #---------------------------------------------------------------------------
    #
    method name ( --> Str ) {
      return [~] $.server-name, ':', $.server-port;
    }

    #---------------------------------------------------------------------------
    #
    submethod DESTROY {

      # Send a stop code to the monitor code thread and wait for it to finish
      #
      $!channel.send('stop');
      $!promise-monitor.await;
      undefine $!promise-monitor;

      # Release the lock
      #
      $!server-monitor-control.release;

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
