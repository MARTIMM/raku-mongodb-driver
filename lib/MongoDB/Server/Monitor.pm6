use v6.c;

use MongoDB;
use MongoDB::Server::Socket;
use BSON;
use BSON::Document;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

#-------------------------------------------------------------------------------
class Server::Monitor {

  has MongoDB::ServerType $!server;
  has MongoDB::Server::Socket $!socket;

  has Duration $!weighted-mean-rtt-ms;

  # Variables to control infinite monitoring actions
  has Promise $!promise-monitor;
  has Semaphore $!server-monitor-control;

  has Bool $!monitor-loop;
  has Supplier $!monitor-data-supplier;

  has BSON::Document $!monitor-command;
  has BSON::Document $!monitor-result;

  has Semaphore::ReadersWriters $!rw-sem;

  #-----------------------------------------------------------------------------
  # Call before monitor-server to set the $!server object!
  # Inheriting from Supplier prevents use of proper BUILD 
  #
  submethod BUILD ( MongoDB::ServerType:D :$server ) {

    $!rw-sem .= new;
#    $!rw-sem.debug = True;
#TODO check before create
    $!rw-sem.add-mutex-names( <m-loop>, :RWPatternType(C-RW-WRITERPRIO))
      unless $!rw-sem.check-mutex-names(<m-loop>);

    $!server = $server;

    $!weighted-mean-rtt-ms .= new(0);

    $!server-monitor-control .= new(1);
    $!monitor-data-supplier .= new;

    $!monitor-command .= new: (isMaster => 1);
  }

#  #-----------------------------------------------------------------------------
#  method quit ( ) {
#
#    $!rw-sem.writer( 'm-loop', {$!monitor-loop = False;});
#    $!monitor-data-supplier.quit('Monitor forced to quit');
#  }

  #-----------------------------------------------------------------------------
  method get-supply ( --> Supply ) {

    $!monitor-data-supplier.Supply;
  }

  #-----------------------------------------------------------------------------
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
            #
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
            warn-message("no response from server $!server.name()");
            $!monitor-data-supplier.emit( {
                ok => False,
                reason => 'Undefined document'
              }
            );
          }

#          sleep-until ($loop-start-time-ms + $monitor-looptime-ms)/1000.0;
#note "Sleep for {$monitor-looptime-ms / 1000.0} (1)";
          sleep $monitor-looptime-ms / 1000.0;
          $mloop = $!rw-sem.reader( 'm-loop', {$!monitor-loop;});

          # Capture errors. When there are any, On older servers before
          # version 3.2 the server just stops communicating when a shutdown
          # command was given. Opening a socket will then bring us here.
          # Send ok False to mention the fact that the server is down.
          #
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
#note "Sleep for {$monitor-looptime-ms / 1000.0} (0)";
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

  #-----------------------------------------------------------------------------
  method stop-monitor ( ) {

    debug-message("stopping monitor for server '$!server.name()'");
    $!rw-sem.writer( 'm-loop', {$!monitor-loop = False;});
  }
}
