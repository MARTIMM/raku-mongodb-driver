use v6;

use MongoDB;
use MongoDB::Server::Socket;
use BSON;
use BSON::Document;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
class Server::Monitor {
  my MongoDB::Server::Monitor $singleton-instance;

  has %!registered-servers;
#  has MongoDB::ServerType $!server;
#  has MongoDB::Server::Socket $!socket;
#  has Duration $!weighted-mean-rtt-ms;

  # Variables to control infinite monitoring actions
  has Promise $!promise-monitor;
  #has Semaphore $!server-monitor-control;

  has Bool $!monitor-loop;
  has Supplier $!monitor-data-supplier;
  has Int $!heartbeat-frequency-ms;

  has BSON::Document $!monitor-command;
  has BSON::Document $!monitor-result;

  has Semaphore::ReadersWriters $!rw-sem;

  #----------------------------------------------------------------------------
  # Call before monitor-server to set the $!server object!
  # Inheriting from Supplier prevents use of proper BUILD
  #
#  submethod BUILD ( MongoDB::ServerType:D :$server ) {
  submethod BUILD ( ) {

    $!rw-sem .= new;
    $!rw-sem.debug = True;
#TODO check before create
    $!rw-sem.add-mutex-names( <m-loop servers>, :RWPatternType(C-RW-WRITERPRIO))
      unless $!rw-sem.check-mutex-names(<m-loop servers>);

    %!registered-servers = %();

#    $!server = $server;
#    $!weighted-mean-rtt-ms .= new(0);
#    $!server-monitor-control .= new(1);
    $!monitor-data-supplier .= new;
    $!heartbeat-frequency-ms = MongoDB::C-HEARTBEATFREQUENCYMS;
    $!monitor-command .= new: (isMaster => 1);
  }

  #----------------------------------------------------------------------------
  # Prevent calling new(). Must use instance()
  method new (  ) { !!! }

  #----------------------------------------------------------------------------
  method instance ( --> MongoDB::Server::Monitor ) {

    $singleton-instance //= self.bless;
    $singleton-instance;
  }

  #----------------------------------------------------------------------------
  method get-supply ( --> Supply ) {

    $!monitor-data-supplier.Supply;
  }

  #----------------------------------------------------------------------------
  method set-heartbeat ( Int:D $!heartbeat-frequency-ms ) { }

  #----------------------------------------------------------------------------
  method register-server ( MongoDB::ServerType:D :$server ) {

    $!rw-sem.writer( 'servers', {
        if %!registered-servers{$server} {
          warn-message("Server $server.name() already monitored");
        }

        else {
          %!registered-servers{$server} = [
            $server,    # provided server
            0,          # init weighted mean rtt in ms
          ];
        } # else
      } # writer block
    ); # writer

    # Check if monitor runs, if not, start the monitor
    unless $!rw-sem.reader( 'm-loop', { $!monitor-loop; }) {
      $!rw-sem.writer( 'm-loop', { $!monitor-loop = True; });
      debug-message("Start monitoring");
      self!start-monitor;
    }
  }

  #----------------------------------------------------------------------------
  method unregister-server ( MongoDB::ServerType:D :$server ) {

    $!rw-sem.writer( 'servers', {
        if %!registered-servers{$server} {
          %!registered-servers{$server}:delete;
        }

        else {
          warn-message("Server $server.name() not monitored");
        } # else
      } # writer block
    ); # writer

    # Check if there are still servers to monitor, if not, stop the monitor
    unless $!rw-sem.reader( 'servers', { %!registered-servers.keys }) {
      debug-message("Stop monitoring");
      $!rw-sem.writer( 'm-loop', { $!monitor-loop = False; })
    }
  }

  #----------------------------------------------------------------------------
  method !start-monitor ( ) {

    # Don't let looptime become lower than 100 ms
    my Duration $monitor-looptime-ms .= new(
      $!heartbeat-frequency-ms > 50 ?? $!heartbeat-frequency-ms !! 100
    );

    $!promise-monitor .= start( {

        my Duration $rtt;
        my BSON::Document $doc;
        my Int $weighted-mean-rtt-ms;

        # As long as the server lives test it.
        while $!rw-sem.reader( 'm-loop', {$!monitor-loop;}) {

          my Duration $loop-start-time-ms .= new(now * 1000);
          my %rservers = $!rw-sem.reader( 'servers', { %!registered-servers; });
          for %rservers.keys -> $server-name {
            my $server = %rservers{$server-name}[0];

            # Get server info
            ( $doc, $rtt) = $server.raw-query(
              'admin.$cmd', $!monitor-command,
              :number-to-skip(0), :number-to-return(1), :!authenticate,
              :timed-query
            );

            if $doc.defined {
              # Calculation of mean Return Trip Time. See also
              # https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#calculation-of-average-round-trip-times
              $!weighted-mean-rtt-ms .= new(
                0.2 * $rtt * 1000 + 0.8 * $!weighted-mean-rtt-ms
              );

              debug-message(
                "Weighted mean RTT: $!weighted-mean-rtt-ms (ms) for server $server.name()"
              );

              $!monitor-data-supplier.emit( {
                  ok => True,
                  monitor => $doc<documents>[0],
                  weighted-mean-rtt-ms => $!weighted-mean-rtt-ms
                } # emit data
              ); # emit
  #TODO SS-RSPrimary must do periodic no-op
  #See https://github.com/mongodb/specifications/blob/master/source/max-staleness/max-staleness.rst#primary-must-write-periodic-no-ops
            }

            else {
              warn-message("no response from server $server.name()");
              $!monitor-data-supplier.emit( {
                  ok => False,
                  reason => 'Undefined document'
                } # emit data
              ); # emit
            } # else

  #          sleep-until ($loop-start-time-ms + $monitor-looptime-ms)/1000.0;
  #note "AA: Sleep for {$monitor-looptime-ms / 1000.0} sec";
            sleep $monitor-looptime-ms / 1000.0;

            # Capture errors. When there are any, On older servers before
            # version 3.2 the server just stops communicating when a shutdown
            # command was given. Opening a socket will then bring us here.
            # Send ok False to mention the fact that the server is down.
            CATCH {
  #.message.note;
              when .message ~~ m:s/Failed to resolve host name/ ||
                   .message ~~ m:s/No response from server/ ||
                   .message ~~ m:s/Failed to connect\: connection refused/ ||
                   .message ~~ m:s/Socket not available/ ||
                   .message ~~ m:s/Out of range\: attempted to read/ ||
                   .message ~~ m:s/Not enaugh characters left/ {

                # Failure messages;
                #   No response from server - This can happen when there is some
                #   communication going on but the server has problems/down.
                my Str $s = .message();
                error-message("Server $server.name() error $s");

                $!monitor-data-supplier.emit( %( ok => False, reason => $s));

  #              sleep-until ($loop-start-time-ms + $monitor-looptime-ms)/1000.0;
  #note "BB: Sleep for {$monitor-looptime-ms / 1000.0} (0)";
                sleep $monitor-looptime-ms / 1000.0;
              }

              # If not one of the above errors, show and rethrow the error
              default {
                .note;
                .rethrow;
              } # default
            } # CATCH
          } # for %rservers.keys
        } # while $!rw-sem.reader( 'm-loop', {$!monitor-loop;});

        debug-message("server monitoring stopped");

      } # promise block
    ); # promise
  } # method

#`{{
  #----------------------------------------------------------------------------
  # Run this on a separate thread because it lasts until this program stops
  # or that the client is cleaned up
  method start-monitor ( Int:D $heartbeat-frequency-ms --> Promise ) {

    # Just to prevent that more than one monitor is started.
    return Promise unless $!server-monitor-control.try_acquire;

    # Don't let looptime become lower than 50 ms
    my Duration $monitor-looptime-ms .= new(
      $heartbeat-frequency-ms > 50 ?? $heartbeat-frequency-ms !! 50
    );

    debug-message("Start $!server.name() monitoring");
    $!promise-monitor .= start( {

        my Duration $rtt;
        my BSON::Document $doc;

        # As long as the server lives test it. Changes are possible when
        # server conditions change.
        my Bool $mloop = $!rw-sem.writer( 'm-loop', {$!monitor-loop = True;});

        while $mloop {

          my Duration $loop-start-time-ms .= new(now * 1000);

          # Get server info
          ( $doc, $rtt) = $!server.raw-query(
            'admin.$cmd', $!monitor-command,
            :number-to-skip(0), :number-to-return(1), :!authenticate,
            :timed-query
          );

          if $doc.defined {
            # Calculation of mean Return Trip Time. See also
            # https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#calculation-of-average-round-trip-times
            $!weighted-mean-rtt-ms .= new(
              0.2 * $rtt * 1000 + 0.8 * $!weighted-mean-rtt-ms
            );

            debug-message(
              "Weighted mean RTT: $!weighted-mean-rtt-ms (ms) for server $!server.name()"
            );

            $!monitor-data-supplier.emit( {
                ok => True,
                monitor => $doc<documents>[0],
                weighted-mean-rtt-ms => $!weighted-mean-rtt-ms
              }
            );
#TODO SS-RSPrimary must do periodic no-op
#See https://github.com/mongodb/specifications/blob/master/source/max-staleness/max-staleness.rst#primary-must-write-periodic-no-ops
          }

          else {
            $!socket.close-on-fail if $!socket.defined;
            warn-message("no response from server $!server.name()");
            $!monitor-data-supplier.emit( {
                ok => False,
                reason => 'Undefined document'
              }
            );
          }

#          sleep-until ($loop-start-time-ms + $monitor-looptime-ms)/1000.0;
#note "AA: Sleep for {$monitor-looptime-ms / 1000.0} sec";
          sleep $monitor-looptime-ms / 1000.0;
          $mloop = $!rw-sem.reader( 'm-loop', {$!monitor-loop;});

          # Capture errors. When there are any, On older servers before
          # version 3.2 the server just stops communicating when a shutdown
          # command was given. Opening a socket will then bring us here.
          # Send ok False to mention the fact that the server is down.
          CATCH {
#.message.note;
            when .message ~~ m:s/Failed to resolve host name/ ||
                 .message ~~ m:s/No response from server/ ||
                 .message ~~ m:s/Failed to connect\: connection refused/ ||
                 .message ~~ m:s/Socket not available/ ||
                 .message ~~ m:s/Out of range\: attempted to read/ ||
                 .message ~~ m:s/Not enaugh characters left/ {

              # Failure messages;
              #   No response from server - This can happen when there is some
              #   communication going on but the server has problems/down.
              my Str $s = .message();
              error-message("Server $!server.name() error $s");

              $!socket.close-on-fail if $!socket.defined;
              $!socket = Nil;
              $!monitor-data-supplier.emit( %( ok => False, reason => $s));

#              sleep-until ($loop-start-time-ms + $monitor-looptime-ms)/1000.0;
#note "BB: Sleep for {$monitor-looptime-ms / 1000.0} (0)";
              sleep $monitor-looptime-ms / 1000.0;

              # check if loop must be broken
              $mloop = $!rw-sem.reader( 'm-loop', {$!monitor-loop;});
            }

            # If not one of the above errors, show and rethrow the error
            default {
              .note;
              .rethrow;
            }
          }

#          LEAVE {
#            $mloop = $!rw-sem.reader( 'm-loop', {$!monitor-loop;});
#          }
        }

        $!server-monitor-control.release;
        debug-message("server monitoring stopped for '$!server.name()'");
#        $!monitor-data-supplier.done;
      }
    );

    $!promise-monitor;
  }

  #----------------------------------------------------------------------------
  method stop-monitor ( ) {

    debug-message("stopping monitor for server '$!server.name()'");
    $!rw-sem.writer( 'm-loop', {$!monitor-loop = False;});
  }
}}
}
