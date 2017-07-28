use v6;

use MongoDB;
use MongoDB::Server::Socket;
use BSON;
use BSON::Document;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

enum SERVERDATA <<:ServerObj(0) WMRttMs>>;

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

  has Supplier $!monitor-data-supplier;
  has Duration $!heartbeat-frequency-ms;

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
    #$!rw-sem.debug = True;
    $!rw-sem.add-mutex-names( <m-loop m-servers>, :RWPatternType(C-RW-WRITERPRIO));

    %!registered-servers = %();

#    $!server = $server;
#    $!weighted-mean-rtt-ms .= new(0);
#    $!server-monitor-control .= new(1);
    $!monitor-data-supplier .= new;
    $!heartbeat-frequency-ms .= new(MongoDB::C-HEARTBEATFREQUENCYMS);
    trace-message("Monitor sleep time set to $!heartbeat-frequency-ms ms");
    $!monitor-command .= new: (isMaster => 1);

    # start the monitor
    debug-message("Start monitoring");
    self!start-monitor;
  }

  #----------------------------------------------------------------------------
  # Prevent calling new(). Must use instance()
  method new ( ) { !!! }

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
  method set-heartbeat ( Int:D $heartbeat-frequency-ms ) {

    $!rw-sem.writer( 'm-loop', {
        # Don't let looptime become lower than 100 ms
        $!heartbeat-frequency-ms .= new(
          $heartbeat-frequency-ms > 100 ?? $heartbeat-frequency-ms !! 100
        );
        trace-message("Monitor sleep time set to $!heartbeat-frequency-ms ms");
      }
    );
  }

  #----------------------------------------------------------------------------
  method register-server ( MongoDB::ServerType:D $server ) {

    $!rw-sem.writer( 'm-servers', {
        if %!registered-servers{$server.name}:exists {
          warn-message("Server $server.name() already registered");
        }

        else {
          trace-message("Server $server.name() registered");
          %!registered-servers{$server.name} = [
            $server,    # provided server
            0,          # init weighted mean rtt in ms
          ];
        } # else
      } # writer block
    ); # writer
  }

  #----------------------------------------------------------------------------
  method unregister-server ( MongoDB::ServerType:D $server ) {

    $!rw-sem.writer( 'm-servers', {
        if %!registered-servers{$server.name}:exists {
          %!registered-servers{$server.name}:delete;
          trace-message("Server $server.name() un-registered");
        }

        else {
          warn-message("Server $server.name() not registered");
        } # else
      } # writer block
    ); # writer
  }

  #----------------------------------------------------------------------------
  method !start-monitor ( ) {

    $!promise-monitor .= start( {

        my Duration $rtt;
        my BSON::Document $doc;
        my Int $weighted-mean-rtt-ms;

        # Do forever once it is started
        loop {
          my Duration $loop-start-time-ms .= new(now * 1000);
          my %rservers = $!rw-sem.reader(
           'm-servers',
            sub () { %!registered-servers; }
          );

          trace-message("Servers to monitor: " ~ %rservers.keys.join(', '));

          for %rservers.keys -> $server-name {
            # Last check if server is still registered
            next unless $!rw-sem.reader(
              'm-servers',
              { %!registered-servers{$server-name}:exists; }
            );

            trace-message("Monitoring $server-name");
            my $server = %rservers{$server-name}[ServerObj];

            trace-message("Monitor is-master request for $server-name");
            # get server info
            ( $doc, $rtt) = $server.raw-query(
              'admin.$cmd', $!monitor-command,
              :number-to-skip(0), :number-to-return(1), :!authenticate,
              :timed-query
            );

            trace-message(
              "Monitor is-master request result for $server-name: "
              ~ ($doc//'-').perl
            );
            # when doc is defined, the request ended properly. the ok field
            # in the doc will tell if the operation is succsessful or not
            if $doc.defined {
              # Calculation of mean Return Trip Time. See also
              # https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#calculation-of-average-round-trip-times
              %rservers{$server-name}[WMRttMs] = Duration.new(
                0.2 * $rtt * 1000 + 0.8 * %rservers{$server-name}[WMRttMs]
              );

              # set new value of waiten mean rtt if the server is still registered
              $!rw-sem.writer( 'm-servers', {
                  if %!registered-servers{$server-name}:exists {
                    %!registered-servers{$server-name}[WMRttMs] =
                      %rservers{$server-name}[WMRttMs];
                  }
                }
              );

              debug-message(
                "Weighted mean RTT: %rservers{$server-name}[WMRttMs] (ms) for server $server.name()"
              );

              $!monitor-data-supplier.emit( {
                  :ok, monitor => $doc<documents>[0], :$server-name,
                  weighted-mean-rtt-ms => %rservers{$server-name}[WMRttMs]
                } # emit data
              ); # emit
  #TODO SS-RSPrimary must do periodic no-op
  #See https://github.com/mongodb/specifications/blob/master/source/max-staleness/max-staleness.rst#primary-must-write-periodic-no-ops
            }

            # no doc returned, server is in trouble or the connection
            # between it is down.
            else {
              warn-message("no response from server $server.name()");
              $!monitor-data-supplier.emit( {
                  :!ok, reason => 'Undefined document', :$server-name
                } # emit data
              ); # emit
            } # else

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
                error-message("Server $server-name error $s");

                $!monitor-data-supplier.emit( %(
                  :!ok, reason => $s, :$server-name
                ));
              }

              # If not one of the above errors, show and rethrow the error
              default {
                .note;
                .rethrow;
              } # default
            } # CATCH
          } # for %rservers.keys

          my $heartbeat-frequency-ms = $!rw-sem.reader(
            'm-loop', {$!heartbeat-frequency-ms}
          );
          trace-message("Monitor sleeps for $heartbeat-frequency-ms ms");
          # Sleep after all servers are monitored
          sleep $heartbeat-frequency-ms / 1000.0;

        } # loop

        "server monitoring stopped";

      } # promise block
    ); # promise
  } # method
}
