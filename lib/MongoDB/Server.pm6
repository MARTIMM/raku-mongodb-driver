use v6.c;

use MongoDB;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;
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
    has MongoDB::Server::Socket @!sockets;

    has Duration $!weighted-mean-rtt .= new(0);

    # Variables to control infinite server monitoring actions
    #
    has MongoDB::Server::Monitor $.server-monitor;
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
    ) {
      $!server-name = $host;
      $!server-port = $port;
      $!max-sockets = $max-sockets;
      $!uri-data = $uri-data // %();

      $!server-monitor-control .= new(1);
      $!server-socket-selection .= new(1);

      # IO::Socket::INET throws an exception when things go wrong. Need to
      # catch this higher up.
      #
      my IO::Socket::INET $sock .= new(
        :host($!server-name),
        :port($!server-port)
      );

      $!server-monitor .= new: :server(self);

      # Must close this because of thread errors when reading the socket
      # Besides the sockets are encapsulated in Socket and kept in an array.
      #
      $sock.close;
    }

    #---------------------------------------------------------------------------
    # Run this on a separate thread because it lasts until this program
    # atops or the server shuts down.
    #
    method _monitor-server ( Channel $data-channel, Channel $command-channel ) {

      $!server-monitor.monitor-server( $data-channel, $command-channel);
    }

    #---------------------------------------------------------------------------
    # Search in the array for a closed Socket.
    #
    method get-socket ( --> MongoDB::Server::Socket ) {
#TODO place semaphores using $!max-sockets

      $!server-socket-selection.acquire;

      my MongoDB::Server::Socket $sock;

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
