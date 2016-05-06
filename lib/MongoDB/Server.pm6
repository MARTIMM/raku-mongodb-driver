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
  has Supply $!monitor-supply;
  has Promise $!monitor-promise;

  has Int $.max-sockets;
  has MongoDB::Server::Socket @!sockets;
  has Semaphore $!server-socket-selection;

  # Server status. Must be protected by a semaphore because of a thread
  # handling monitoring data
  #
  has MongoDB::ServerStatus $!server-status;
  has Semaphore $!status-semaphore;

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
    # Save name andd port of the server
    $!server-name = $host;
    $!server-port = $port;

    # Define number of available sockets and its semaphore
    $!max-sockets = $max-sockets;
    $!server-socket-selection .= new(1);
#TODO semaphores using $!max-sockets

    # Set status to its default starting status
    $!server-status = MongoDB::C-UNKNOWN-SERVER;
    $!status-semaphore .= new(1);

    $!uri-data = $uri-data // %();

    $!server-monitor .= new;
  }

  #---------------------------------------------------------------------------
  # Server initialization 
  method server-init ( ) {

    # Don't start monitoring if dns failed to return an ip address
    if $!server-status != MongoDB::C-NON-EXISTENT-SERVER {

      # Initialize and start monitoring
      $!server-monitor.monitor-init(:server(self));

      # Start monitoring
      $!monitor-promise = $!server-monitor.monitor-server;
      return unless $!monitor-promise.defined;

      # Tap into monitor data
      self.tap-monitor( -> Hash $monitor-data {

          my MongoDB::ServerStatus $server-status = MongoDB::C-UNKNOWN-SERVER;
          if $monitor-data<ok> {

            my $mdata = $monitor-data<monitor>;

            # Does the caller want to have a replicaset
            if $!uri-data<options><replicaSet> {

              # Is the server in a replicaset
              if $mdata<isreplicaset>:!exists and $mdata<setName> {

                # Is the server in the replicaset matching the callers request
                if $mdata<setName> eq $!uri-data<options><replicaSet> {

                  if $mdata<ismaster> {
                    $server-status = MongoDB::C-REPLICASET-PRIMARY;
                  }

                  elsif $mdata<secondary> {
                    $server-status = MongoDB::C-REPLICASET-PRIMARY;
                  }

                  # ... Arbiter etc
                }

                # Replicaset name does not match
                else {
                  $server-status = MongoDB::C-REJECTED-SERVER;
                }
              }

              # Must be initialized. When an other name for replicaset is used
              # the next state should be C-REJECTED-SERVER. Otherwise it becomes
              # any of MongoDB::C-REPLICASET-*
              #
              elsif $mdata<isreplicaset> and $mdata<setName>:!exists {
                $server-status = MongoDB::C-REPLICA-PRE-INIT
              }

              # Shouldn't happen
              else {
                $server-status = MongoDB::C-REJECTED-SERVER;
              }
            }

            # Need one standalone server
            else {

              # Must not be any type of replicaset server
              if $mdata<isreplicaset>:exists
                 or $mdata<setName>:exists
                 or $mdata<primary>:exists {
                $server-status = MongoDB::C-REJECTED-SERVER;
              }

              else {
                # Must be master
                if $mdata<ismaster> {
                  $server-status = MongoDB::C-MASTER-SERVER;
                }

                # Shouldn't happen
                else {
                  $server-status = MongoDB::C-REJECTED-SERVER;
                }
              }
            }
          }

          # Server did not respond
          else {

            if $monitor-data<reason>:exists
               and $monitor-data<reason> ~~ m:s/Failed to resolve host name/ {
              $server-status = MongoDB::C-NON-EXISTENT-SERVER;
            }

            else {
              $server-status = MongoDB::C-DOWN-SERVER;
            }
          }

          # Set the status with the new value
          $!status-semaphore.acquire;
          $!server-status = $server-status;
          $!status-semaphore.release;
        }
      );
    }
  }

  #---------------------------------------------------------------------------
  method get-status ( --> MongoDB::ServerStatus ) {

    $!status-semaphore.acquire;
    my MongoDB::ServerStatus $server-status = $!server-status;
    $!status-semaphore.release;
    $server-status;
  }

  #---------------------------------------------------------------------------
  # Make a tap on the Supply. Use act() for this so we are sure that only this
  # code runs whithout any other parrallel threads.
  #
  method tap-monitor ( |c ) {

    $!monitor-supply = $!server-monitor.Supply unless $!monitor-supply.defined;
#    $!monitor-supply.act(|c);
    $!monitor-supply.tap(|c);
  }

  #---------------------------------------------------------------------------
  method stop-monitor ( |c ) {

    $!server-monitor.done(c);
# Doesn't seem to work
#    if $!monitor-promise.defined {
#      $!monitor-promise.result;
#      info-message("Monitor code result: $!monitor-promise.status()"); 
#    }
  }

  #---------------------------------------------------------------------------
  # Search in the array for a closed Socket.
  #
  method get-socket ( --> MongoDB::Server::Socket ) {

    my MongoDB::Server::Socket $sock;

    # Get a free socket entry
    $!server-socket-selection.acquire;
    for ^(@!sockets.elems) -> $si {

      # Skip all active sockets
      #
      next if @!sockets[$si].is-open;

      $sock = @!sockets[$si];
      last;
    }
    $!server-socket-selection.release;

    # Setup a try block to catch socket new() exceptions
    #
    try {

      # If none is found insert a new Socket in the array
      #
      if ! $sock.defined {

        # Protect against too many open sockets.
        #
        if @!sockets.elems >= $!max-sockets {
          fatal-message("Too many sockets opened, max is $!max-sockets");
        }

        $sock .= new(:server(self));
      }

      # Return a usable socket which is opened. The user has the responsibility
      # to close the socket. Otherwise there will be new sockets created every
      # time get-socket() is called.
      #
      $sock.open();

      CATCH {
        default {
          die .message;
        }
      }

      $!server-socket-selection.acquire;
      @!sockets.push($sock);
      $!server-socket-selection.release;
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

