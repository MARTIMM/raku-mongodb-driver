
use v6.c;

use MongoDB;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;
use BSON::Document;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
class Server {

  # Used by Socket
  has Str $.server-name;
  has MongoDB::PortType $.server-port;

  # As in MongoDB::Uri without servers name and port. So there are
  # database, username, password and options
  #
  has Hash $!uri-data;

  # Variables to control infinite server monitoring actions
  has MongoDB::Server::Monitor $!server-monitor;
  has Supply $!monitor-supply;
  has Promise $!monitor-promise;

  has MongoDB::SocketLimit $!max-sockets;
  has MongoDB::Server::Socket @!sockets;
  has Semaphore $!server-socket-selection;
#TODO semaphores using $!max-sockets

  # Server status. Must be protected by a semaphore because of a thread
  # handling monitoring data.
  # Set status to its default starting status
  has MongoDB::ServerStatus $!server-status;
  has Semaphore $!status-semaphore;

  #-----------------------------------------------------------------------------
  # Server must make contact first to see if server exists and reacts. This
  # must be done in the background so Client starts this process in a thread.
  #
  submethod BUILD ( Str:D :$server-name, Hash :$uri-data = %(),
    MongoDB::SocketLimit :$max-sockets = 3, Int :$loop-time
  ) {

    # Save name andd port of the server
    ( my $host, my $port) = split( ':', $server-name);
    $!server-name = $host;
    $!server-port = $port.Int;

    $!uri-data = $uri-data;

    $!server-monitor .= new( :server(self), :$loop-time);

    # Define number of available sockets and its semaphore
    $!max-sockets = $max-sockets;

    @!sockets = ();
    $!server-socket-selection .= new(1);

    $!server-status = MongoDB::C-UNKNOWN-SERVER;
    $!status-semaphore .= new(1);
  }

  #-----------------------------------------------------------------------------
  # Server initialization 
  method server-init ( ) {

    # Don't start monitoring if dns failed to return an ip address
#    if $!server-status != MongoDB::C-NON-EXISTENT-SERVER {

      # Start monitoring
      $!monitor-promise = $!server-monitor.start-monitor;
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
                    $server-status = MongoDB::C-REPLICASET-SECONDARY;
                  }

                  # ... Arbiter etc
                }

                # Replicaset name does not match
                else {
                  $server-status = MongoDB::C-REJECTED-SERVER;
                }
              }

              # Replicaset must be initialized. When an other name for
              # replicaset is used the next state should be C-REJECTED-SERVER.
              # Otherwise it becomes any of MongoDB::C-REPLICASET-*
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
#    }
  }

  #-----------------------------------------------------------------------------
  method get-status ( --> MongoDB::ServerStatus ) {

    $!status-semaphore.acquire;
    my MongoDB::ServerStatus $server-status = $!server-status;
    $!status-semaphore.release;
    $server-status;
  }

  #-----------------------------------------------------------------------------
  # Make a tap on the Supply. Use act() for this so we are sure that only this
  # code runs whithout any other parrallel threads.
  #
  method tap-monitor ( |c --> Tap ) {

    $!monitor-supply = $!server-monitor.get-supply
       unless $!monitor-supply.defined;
#    $!monitor-supply.act(|c);
    $!monitor-supply.tap(|c);
  }

  #-----------------------------------------------------------------------------
  method stop-monitor ( ) {

    $!server-monitor.done;
# Doesn't seem to work
#    if $!monitor-promise.defined {
#      $!monitor-promise.result;
#      info-message("Monitor code result: $!monitor-promise.status()"); 
#    }
  }

  #-----------------------------------------------------------------------------
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
#    try {

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
      # time get-socket() is called. When limit is reached, an exception
      # is thrown.
      #
      $sock.open();

#      CATCH {
#say "Error server: ", $_;
#        default {
#          die .message;
#        }
#      }

      $!server-socket-selection.acquire;
      @!sockets.push($sock);
      $!server-socket-selection.release;
#    }

    $!server-socket-selection.release;
    return $sock;
  }

  #-----------------------------------------------------------------------------
  #
  method name ( --> Str ) {

    return [~] $!server-name // '-', ':', $!server-port // '-';
  }

  #-----------------------------------------------------------------------------
  #
  method set-max-sockets ( Int $max-sockets where $_ >= 3 ) {
    $!max-sockets = $max-sockets;
  }
}


#-------------------------------------------------------------------------------
sub dump-callframe ( $fn-max = 10 --> Str ) {

  my Str $dftxt = "\nDump call frame: \n";

  my $fn = 1;
  while my CallFrame $cf = callframe($fn) {
#say $cf.perl;
#say "TOP: ", $cf<TOP>:exists;

    # End loop with the program that starts on line 1 and code object is
    # a hollow shell.
    #
    if ?$cf and $cf.line == 1  and $cf.code ~~ Mu {
      $cf = Nil;
      last;
    }

    # Cannot pass sub THREAD-ENTRY either
    #
    if ?$cf and $cf.code.^can('name') and $cf.code.name eq 'THREAD-ENTRY' {
      $cf = Nil;
      last;
    }

    $dftxt ~= [~] "cf [$fn.fmt('%2d')]: ", $cf.line, ', ', $cf.code.^name,
        ', ', ($cf.code.^can('name') ?? $cf.code.name !! '-'),
         "\n         $cf.file()\n";

    $fn++;
    last if $fn > $fn-max;
  }

  $dftxt ~= "\n";
}
