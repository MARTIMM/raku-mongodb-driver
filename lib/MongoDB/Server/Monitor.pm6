use v6.c;

use MongoDB;
use MongoDB::Socket;
use MongoDB::Header;
use BSON::Document;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
# Complete standalone and thereby thread save, to monitor a mongo server. To
# separate everything, several code sections are taken from Database, Collection
# and Wire modules with several shortcuts because the operation to get the
# information is simple.
#
# - Server object is past from the Server object to initiate the polling.
# - Read and write concern info and some other query options are not needed.
# - No server shutdown on failures. Communicate through channel.
# - Full collection name is fixed. Document and encoding is fixed.
# - No Cursor object needed. One document is pulled out directly from result.
#
class Server::Monitor {

  has $!server where .^name eq 'MongoDB::Server';
  has BSON::Document $!monitor-command;
  has BSON::Document $!monitor-result;
  has MongoDB::Socket $!socket;
  has Int $.monitor-looptime is rw = 10;

  has Duration $!weighted-mean-rtt .= new(0);

  # Variables to control infinite monitoring actions
  has Promise $!promise-monitor;
  has Semaphore $!server-monitor-control;

  #-----------------------------------------------------------------------------
  #
  submethod BUILD (
    :$server where ( .defined and .^name eq 'MongoDB::Server')
  ) {

    $!server = $server;
    $!monitor-command .= new: (isMaster => 1);
    $!monitor-command.encode;
    $!monitor-command does MongoDB::Header;

    $!server-monitor-control .= new(1);
  }

  #-----------------------------------------------------------------------------
  # Run this on a separate thread because it lasts until this program
  # atops or the server shuts down.
  #
  method monitor-server ( Channel $data-channel, Channel $command-channel ) {

#say "Start $!server.name() monitoring";
    return unless $!server-monitor-control.try_acquire;

    $!promise-monitor .= start( {

        my Instant $t0;
        my Duration $rtt;
        my BSON::Document $doc;

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
            info-message("Server $!server.name(). Receive command $cmd")
              if ?$cmd;
            last if ?$cmd and $cmd eq 'stop';

            # Save time stamp for RTT measurement
            $t0 = now;

            # Get server info
            $doc = self!query;

            # Calculation of mean Return Trip Time
            $rtt = now - $t0;
            $!weighted-mean-rtt .= new(
              0.2 * $rtt + 0.8 * $!weighted-mean-rtt
            );

#say "Monitor info: ", $doc.perl;

            # Send data to Client
            $data-channel.send( {
                monitor => $doc<documents>[0],
                weighted-mean-rtt => $!weighted-mean-rtt
              }
            );

            info-message(
              "Weighted mean RTT: $!weighted-mean-rtt for server $!server.name()"
            );

            # Rest for a while
            sleep($!monitor-looptime);

            # Capture errors. When there are any, stop monitoring. On older
            # servers before version 3.2 the server just stops communicating
            # when a shutdown command was given. Opening a socket will then
            # bring us here.
            #
            CATCH {
              default {
                warn-message(
                  "Server $!server.name() error while monitoring, changing state"
                );
                last;
              }
            }
          }
        }

        info-message("Server monitoring stopped for $!server.name()");
        $command-channel.send('stopped');
        $!server-monitor-control.release;
      }
    );
  }

  #-----------------------------------------------------------------------------
  #
  method !query ( --> BSON::Document ) {

    # Full collection name is fixed to 'admin.$cmd'.
    ( my Buf $encoded-query, my Int $request-id) =
       $!monitor-command.encode-query( 'admin.$cmd', :number-to-return(1));

    try {
      $!socket = $!server.get-socket;
      fatal-message("No socket available") unless $!socket.defined;

      $!socket.send($encoded-query);

      # Read 4 bytes for int32 response size
      #
      my Buf $size-bytes = self!get-bytes(4);

      my Int $response-size = decode-int32( $size-bytes, 0) - 4;

      # Receive remaining response bytes from socket. Prefix it with the
      # already read bytes and decode. Return the resulting document.
      #
      my Buf $server-reply = $size-bytes ~ self!get-bytes($response-size);
      $!monitor-result = $!monitor-command.decode-reply($server-reply);

      # Assert that the request-id and response-to are the same
      fatal-message("Id in request is not the same as in the response")
        unless $request-id == $!monitor-result<message-header><response-to>;

      # Catch all thrown exceptions and take out the server if needed
      #
      CATCH {
#channel server state!
        when MongoDB::Message {
#          $client._take-out-server($server);
        }

        default {
          when Str {
            warn-message($_);
#            $client._take-out-server($server);
          }

          when Exception {
            warn-message(.message);
#            $client._take-out-server($server);
          }
        }

      }
    }

    $!socket.close;
    return $!monitor-result;
  }

  #-----------------------------------------------------------------------------
  # Read number of bytes from server. When no/not enaugh bytes an error
  # is thrown.
  #
  method !get-bytes ( int $n --> Buf ) {

    my Buf $bytes = $!socket.receive($n);
    if $bytes.elems == 0 {

      # No data, try again
      #
      $bytes = $!socket.receive($n);
      fatal-message("No response from server") if $bytes.elems == 0;
    }

    if 0 < $bytes.elems < $n {

      # Not 0 but too little, try to get the rest of it
      #
      $bytes.push($!socket.receive($n - $bytes.elems));
      fatal-message("Response corrupted") if $bytes.elems < $n;
    }

    $bytes;
  }
}
