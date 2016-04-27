use v6.c;

use MongoDB;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;
use BSON::Document;

unit package MongoDB;

subset ServerStatus of Int where 10 <= $_ <= 21;
constant C-UNKNOWN-SERVER               = 10;
constant C-DOWN-SERVER                  = 11;
constant C-RECOVERING-SERVER            = 12;

constant C-REJECTED-SERVER              = 13;
constant C-GHOST-SERVER                 = 14;

constant C-REPLICA-PRE-INIT             = 15;
constant C-REPLICASET-PRIMARY           = 16;
constant C-REPLICASET-SECONDARY         = 17;
constant C-REPLICASET-ARBITER           = 18;

constant C-SHARDING-SERVER              = 19;
constant C-MASTER-SERVER                = 20;
constant C-SLAVE-SERVER                 = 21;

class Server {

  has Str $.server-name;
  has Int $.server-port;

  # As in MongoDB::Uri without servers name and port. So there are
  # database, username, password and options
  #
  has Hash $!uri-data;

  # Variables to control infinite server monitoring actions
  has MongoDB::Server::Monitor $.server-monitor;

  # Communication to monitoring proces
#  has Channel $!data-channel;
#  has Channel $!command-channel;

  has Int $.max-sockets;
  has MongoDB::Server::Socket @!sockets;
  has Semaphore $!server-socket-selection;

  has ServerStatus $.server-status is rw = C-UNKNOWN-SERVER;

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

    $!server-socket-selection .= new(1);

    # IO::Socket::INET throws an exception when things go wrong.
    #
    try {
      my IO::Socket::INET $sock .= new(
        :host($!server-name),
        :port($!server-port)
      );

      # Must close this because of thread errors when reading the socket
      # Besides the sockets are encapsulated in Socket and kept in an array.
      #
      $sock.close;

      CATCH {
        default {
          info-message("Server self.name() is down");
          $!server-status = C-DOWN-SERVER;
        }
      }
    }

#    $!data-channel = Channel.new();
#    $!command-channel = Channel.new();

    # Start server monitoring
#    $!server-monitor.monitor-server( $!data-channel, $!command-channel);
#    $!server-monitor.monitor-server;
  }

  #---------------------------------------------------------------------------
  method server-init ( ) {
say "S: {self}";

    $!server-monitor .= new;
    $!server-monitor.monitor-init(:server(self));
    $!server-monitor.monitor-server;
  }

  #---------------------------------------------------------------------------
  # Make a tap on the Supply. Use act() for this so we are sure that only this
  # code runs whithout any other parrallel threads.
  #
  method tap-monitor ( |c ) {

    my Supply $s = $!server-monitor.Supply;
    $s.act(|c);
  }

  #---------------------------------------------------------------------------
  method stop-monitor ( |c ) {
    
    $!server-monitor.done;
  }

  #---------------------------------------------------------------------------
  # Search in the array for a closed Socket.
  #
  method get-socket ( --> MongoDB::Server::Socket ) {
#TODO place semaphores using $!max-sockets

#    # If server is still unknown, down or rejected then no sockets can be opened
#    return MongoDB::Server::Socket if $!server-status ~~ any(
#      C-UNKNOWN-SERVER |
#      C-DOWN-SERVER |
#      C-REJECTED-SERVER
#    );

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

