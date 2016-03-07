use v6.c;
use MongoDB;
use MongoDB::Socket;
#use MongoDB::ClientIF;
use MongoDB::DatabaseIF;
use BSON::Document;

package MongoDB {

  class Server {

    has Str $.server-name;
    has Int $.server-port;

    # As in MongoDB::Uri without servers key. So there are
    # database, username, password and options
    #
    has Hash $!uri-data;

    has Int $.max-sockets;
    has MongoDB::Socket @!sockets;

    has Duration $!weighted-mean-rtt .= new(0);

    has MongoDB::DatabaseIF $!db-admin;

    # Variables to control infinite monitoring actions
    #
    has Promise $!promise-monitor;
    has Semaphore $!server-monitor-control;

    has Semaphore $!server-socket-selection;


    #---------------------------------------------------------------------------
    # Server must make contact first to see if server exists and reacts. This
    # must be done in the background so Client starts this process in a thread.
    #
    submethod BUILD (
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
      Int :$max-sockets where $_ >= 3 = 3,
      Hash :$uri-data,
      MongoDB::DatabaseIF:D :$db-admin,
    ) {
      $!db-admin = $db-admin;
      $!server-name = $host;
      $!server-port = $port;
      $!max-sockets = $max-sockets;
      $!uri-data = $uri-data;

      $!server-monitor-control .= new(1);
      $!server-socket-selection .= new(1);

      # IO::Socket::INET throws an exception when things go wrong. Need to
      # catch this higher up.
      #
      my IO::Socket::INET $sock .= new(
        :host($!server-name),
        :port($!server-port)
      );

      # Must close this because of thread errors when reading the socket
      # Besides the sockets are encapsulated in Socket and kept in an array.
      #
      $sock.close;
    }

    #---------------------------------------------------------------------------
    # Is called from Client in same thread as server creation. Any run command
    # will end up in a Wire object which will ask select-server to get a ticket
    # linked to a Server object. When calling this method no info is yet
    # available and needs to be retrieved. This causes an endless loop when we
    # call a run-command to get server info. This is prevented here by storing
    # the Server object ourselfs and send the ticket with the run-command. When
    # it arrives ate the Wire object query method it knows not to call for
    # server-select and get the Server object using the provided ticket.
    #
    method _initial-poll ( --> BSON::Document ) {

      # Calculation of mean Return Trip Time
      #
      my BSON::Document $doc = $!db-admin._internal-run-command(
        BSON::Document.new((isMaster => 1)),
        :server(self)
      );

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Run this on a separate thread because it lasts until this program
    # atops or the server shuts down.
    #
    method _monitor-server ( Channel $data-channel, Channel $command-channel ) {

      # Set the lock so the code will only be started once. When server or
      # program stops(controlled), the code is terminated via a channel.
      #
#say "Start {self.name()} monitoring";
      return unless $!server-monitor-control.try_acquire;
#say "Acquired lock";

      $!promise-monitor .= start( {
          my Instant $t0;
          my BSON::Document $doc;
          my Duration $rtt;

          # As long as the server lives test it. Changes are possible when 
          # server conditions change.
          #
          loop {

            # Temporary try block to catch typos
            try {

              # Check the input-channel to see if there is a stop command. If so
              # exit the while loop. Take a nap otherwise.
              #
              my Str $cmd = $command-channel.poll // '';
#say "Chan {self.name()}: $cmd";
              info-message("Receive command $cmd") if ?$cmd;
              last if ?$cmd and $cmd eq 'stop';

              # Calculation of mean Return Trip Time
              #
              $t0 = now;
              $doc = $!db-admin._internal-run-command(
                BSON::Document.new((isMaster => 1)),
                :server(self)
              );
#say "Monitor {self.name()}: ", $doc.perl;
              $rtt = now - $t0;
              $!weighted-mean-rtt .= new(
                0.2 * $rtt + 0.8 * $!weighted-mean-rtt
              );

              # Send data to Client
              #
              $data-channel.send( {
                  monitor => $doc,
                  weighted-mean-rtt => $!weighted-mean-rtt
                }
              );

              info-message(
                "Weighted mean RTT: $!weighted-mean-rtt for server {self.name}"
              );

              # Rest for a while
              #
              sleep 10;

              # Capture errors. When there are any, stop monitoring. On older
              # servers before version 3.2 the server just stops communicating
              # when a shutdown command was given. Opening a socket will then
              # bring us here.
              #
              CATCH {
                default {
                  warn-message(
                    "Server {self.name} caught error while monitoring, quitting"
                  );
                  last;
                }
              }
            }
          }

          info-message("Server monitoring stopped for {self.name()}");
          $command-channel.send('stopped');
          $!server-monitor-control.release;
        }
      );
    }

    #---------------------------------------------------------------------------
    # Search in the array for a closed Socket.
    #
    method get-socket ( --> MongoDB::Socket ) {
#TODO place semaphores using $!max-sockets

      $!server-socket-selection.acquire;

      my MongoDB::Socket $sock;

      # Setup a try block to catch unknown exceptions
      #
      try {
        for ^(@!sockets.elems) -> $si {

          # Skip all active sockets
          #
          next if @!sockets[$si].is-open;

          $sock = @!sockets[$si];
          last;
        }

        # If none is found insert a new Socket in the array
        #
        if ! $sock.defined {

          # Protect against too many open sockets.
          #
          if @!sockets.elems >= $!max-sockets {
            fatal-message("Too many sockets opened, max is $!max-sockets");
          }

          $sock .= new(:server(self));
          @!sockets.push($sock);
        }

        # Return a usable socket which is opened. The user has the responsibility
        # to close the socket. Otherwise there will be new sockets created every
        # time get-socket() is called.
        #
        $sock.open();

        CATCH {
          default {
            $!server-socket-selection.release;
            .throw;
          }
        }
      }

      $!server-socket-selection.release;
      return $sock;
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
    method set-max-sockets ( Int $max-sockets where $_ >= 3 ) {
      $!max-sockets = $max-sockets;
    }
  }
}
