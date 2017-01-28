use v6.c;

use MongoDB;
use MongoDB::Server::Socket;
use BSON;
use BSON::Document;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

#-------------------------------------------------------------------------------
# Note: Because Supplier is inherited, BUILD cannot get its named parameters.
# when a new() method is defined, Supplier gets wrong parameters. Therefore
# BUILD is replaced by monitor-init() and must be called explicitly
#
class Server::Monitor {

  has MongoDB::ServerType $!server;
  has MongoDB::Server::Socket $!socket;

  has Duration $!weighted-mean-rtt;

  # Variables to control infinite monitoring actions
  has Promise $!promise-monitor;
  has Semaphore $!server-monitor-control;

  has Bool $!monitor-loop;
  has Int $!monitor-looptime;
  has Supplier $!monitor-data-supplier;

  has BSON::Document $!monitor-command;
  has BSON::Document $!monitor-result;

  has Semaphore::ReadersWriters $!rw-sem;

  #-----------------------------------------------------------------------------
  # Call before monitor-server to set the $!server object!
  # Inheriting from Supplier prevents use of proper BUILD 
  #
  submethod BUILD ( MongoDB::ServerType:D :$server, Int :$loop-time = 10 ) {

    $!rw-sem .= new;
#    $!rw-sem.debug = True;
#TODO check before create
    $!rw-sem.add-mutex-names(
      <m-loop m-looptime>,
      :RWPatternType(C-RW-WRITERPRIO)
    ) unless $!rw-sem.check-mutex-names(<m-loop m-looptime>);

    $!server = $server;

    $!weighted-mean-rtt .= new(0);

    $!server-monitor-control .= new(1);
    $!monitor-looptime = $loop-time;
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
  method monitor-looptime ( Int $mlt ) {

    $!rw-sem.writer( 'm-looptime', {$!monitor-looptime = $mlt;});
  }

  #-----------------------------------------------------------------------------
  method get-supply ( --> Supply ) {

    $!monitor-data-supplier.Supply;
  }

  #-----------------------------------------------------------------------------
  # Run this on a separate thread because it lasts until this program atops.
  #
  method start-monitor ( --> Promise ) {

    # Just to prevent that more than one monitor is started.
    return Promise unless $!server-monitor-control.try_acquire;

    debug-message("Start $!server.name() monitoring");
    $!promise-monitor .= start( {

        my Instant $t0;
        my Duration $rtt;
        my BSON::Document $doc;

        # Start loops frequently and slow it down to $!monitor-looptime
        my Int $looptime-trottle = 1;

        # As long as the server lives test it. Changes are possible when 
        # server conditions change.
        my Bool $mloop = $!rw-sem.writer( 'm-loop', {$!monitor-loop = True;});

        while $mloop {

          try {

            # Save time stamp for RTT measurement
            $t0 = now;

            # Get server info
            $doc = $!server.raw-query(
              'admin.$cmd', $!monitor-command,
              :number-to-skip(0), :number-to-return(1), :!authenticate
            );

            # then time response
            $rtt = now - $t0;

            if $doc.defined {

              # Calculation of mean Return Trip Time. See also 
              # https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#calculation-of-average-round-trip-times
              #
              $!weighted-mean-rtt .= new(
                0.2 * $rtt + 0.8 * $!weighted-mean-rtt
              );

#note "\n$*THREAD.id() monitor info $!server.name(): ", $doc.perl;

              debug-message(
                "Weighted mean RTT: $!weighted-mean-rtt for server $!server.name()"
              );
              $!monitor-data-supplier.emit( {
                  ok => True,
                  monitor => $doc<documents>[0],
                  weighted-mean-rtt => $!weighted-mean-rtt
                }
              );
            }

            else {
              warn-message("no response from server $!server.name()");
              $!monitor-data-supplier.emit( {
                  ok => False,
                  reason => 'Undefined document'
                }
              );
            }

            # Rest for a while
            my Int $sleeptime = $!rw-sem.reader(
              'm-looptime', {
                $!monitor-looptime;
              }
            );

            $sleeptime = $looptime-trottle++ if $looptime-trottle < $sleeptime;
            sleep($sleeptime);

            # Capture errors. When there are any, On older servers before
            # version 3.2 the server just stops communicating when a shutdown
            # command was given. Opening a socket will then bring us here.
            # Send ok False to mention the fact that the server is down.
            #
            CATCH {
#.note;
              when .message ~~ m:s/Failed to resolve host name/ ||
                   .message ~~ m:s/Failed to connect\: connection refused/ {

                # Failure messages;
                #   Failed to connect: connection refused
                #   Failed to resolve host name
                #
                # 2016-04-30, perl6 bug, cannot do it directly in hash,
                # Doesn't seem to be a bug, according to doc, $_ is one of
                # the triggers to turn a hash into a block. Use 'hash '
                # or '%()' explicitly!!!
                #
                my Str $s = .message();
                error-message("Server $!server.name() error $s");
                $!monitor-data-supplier.emit(
                  hash (
                    ok => False,
                    reason => $s
                  )
                );

                # Rest for a while
                my Int $sleeptime = $!rw-sem.reader(
                  'm-looptime', {
                    $!monitor-looptime;
                  }
                );

                $sleeptime = $looptime-trottle++
                  if $looptime-trottle < $sleeptime;

                sleep($sleeptime);
              }

              when .message ~~ m:s/No response from server/ ||
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
                $!monitor-data-supplier.emit(
                  hash (
                    ok => False,
                    reason => $s
                  )
                );

                # Rest for a while
                my Int $sleeptime = $!rw-sem.reader(
                  'm-looptime', {
                    $!monitor-looptime;
                  }
                );

                $sleeptime = $looptime-trottle++
                  if $looptime-trottle < $sleeptime;

                sleep($sleeptime);
              }

              # If not one of the above errors, rethrow the error
              default {
                .say;
                .rethrow;
              }
            }
          }

          $mloop = $!rw-sem.reader( 'm-loop', {$!monitor-loop;});
        }

        $!server-monitor-control.release;
        $!socket.close;
        $!socket = Nil;
        info-message("Server monitoring stopped for $!server.name()");
        $!monitor-data-supplier.done;
      }
    );

    $!promise-monitor;
  }

  #-----------------------------------------------------------------------------
  method stop-monitor ( ) {

    $!rw-sem.writer( 'm-loop', {$!monitor-loop = False;});
#    $!monitor-data-supplier.done;
  }
}
