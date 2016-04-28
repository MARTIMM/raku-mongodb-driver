use v6.c;

use MongoDB;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;
use BSON::Document;

unit package MongoDB;

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

  has MongoDB::ServerStatus $.server-status is rw = MongoDB::C-UNKNOWN-SERVER;

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
          $!server-status = MongoDB::C-DOWN-SERVER;
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

    self.tap-monitor( -> Hash $monitor-data {

#TODO protect with semaphore
        say "\nMonitor data: $monitor-data.perl()";
        if $monitor-data<ok> {

          my $mdata = $monitor-data<monitor>;

          # Does the caller want to have a replicaset
          if $!uri-data<options><replicaSet> {

            # Is the server in a replicaset
            if $mdata<isreplicaset> and $mdata<setName> {

              # Is the server in the replicaset matching the callers request
              if $mdata<setName> eq $!uri-data<options><replicaSet> {

                if $mdata<ismaster> {
                  $!server-status = MongoDB::C-REPLICASET-PRIMARY;
                }

                elsif $mdata<issecondary> {
                  $!server-status = MongoDB::C-REPLICASET-PRIMARY;
                }

                # ... Arbiter etc
              }

              # Replicaset name does not match
              else {
                $!server-status = MongoDB::C-REJECTED-SERVER;
              }
            }

            # Must be initialized. When an other name for replicaset is used
            # the next state should be C-REJECTED-SERVER. Otherwise it becomes
            # any of MongoDB::C-REPLICASET-*
            #
            elsif $mdata<isreplicaset> and $mdata<setName>:!exists {
              $!server-status = MongoDB::C-REPLICA-PRE-INIT
            }

            # Shouldn't happen
            else {
              $!server-status = MongoDB::C-REJECTED-SERVER;
            }
          }

          # Need one standalone server
          else {

            # Must not be any type of replicaset server
            if $mdata<isreplicaset>:exists {
              $!server-status = MongoDB::C-REJECTED-SERVER;
            }

            else {
              # Must be master
              if $mdata<ismaster> {
                $!server-status = MongoDB::C-MASTER-SERVER;
              }

              # Shouldn't happen
              else {
                $!server-status = MongoDB::C-REJECTED-SERVER;
              }
            }
          }
        }

        # Server did not respond
        else {
          $!server-status = MongoDB::C-DOWN-SERVER;
        }
      }
    );
  }

  #---------------------------------------------------------------------------
  # Make a tap on the Supply. Use act() for this so we are sure that only this
  # code runs whithout any other parrallel threads.
  #
  method tap-monitor ( |c ) {

    $!server-monitor.Supply.act(|c);
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

