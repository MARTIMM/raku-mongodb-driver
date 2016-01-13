use v6;

# use lib '/home/marcel/Languages/Perl6/Projects/BSON/lib';

use MongoDB::Connection;
use BSON::Document;

package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Client {

#TODO refine this method of using server name/port, connection pooling etc

    my Array $server-connections;       # Array of connections
    my Array $server-discovery;         # Array of promises

    #---------------------------------------------------------------------------
    #
    multi submethod BUILD (
      Str :$host,
      Int :$port where (!$_.defined or 0 <= $_ <= 65535),
      Str :$url
    ) {

      $server-connections = [] unless $server-connections.defined;
      $server-discovery = [] unless $server-discovery.defined;

      my Pair @server-specs = ();
      my Str $server-name;
      my Int $server-port;

say "H & P: {$host//'nh'}, {$port//'np'}, {$url // 'nu'}";

      if ?$url {
#TODO process url
#        $server-name = 'localhost';
#        $server-port = 27017;
      }

      else {
        # Test for the server name. When no cases match a previously stored
        # server name is taken
        #
        if !?$host and !?$server-name and !?$url {
          $server-name = 'localhost';
        }

        elsif ?$host {
          $server-name = $host;
        }

        # Test for the server port. When no cases match a previously stored
        # server port is taken
        #
        if !$port.defined and !$server-port.defined {
          $server-port = 27017;
        }

        elsif $port.defined {
          $server-port = $port;
        }

        @server-specs.push: ($server-name => $server-port);
      }

      # Background process to discover hosts only if there are no servers
      # discovered yet or that new non default cases are presnted.
      #
      if !$server-connections.elems
         or $server-name ne 'localhost'
         or $server-port != 27017 {

        for @server-specs -> Pair $spec {
          $server-discovery.push: Promise.start( {
              MongoDB::Connection.new(
                :client(self),
                :host($spec.key),
                :port($spec.value)
              );
            }
          );
say "KV: {$spec.kv}, {@server-specs.elems}, {$server-discovery.elems}";
        }
      }
    }

    #---------------------------------------------------------------------------
    # Server discovery
    #
    method !discover-servers ( ) {

    }

    #---------------------------------------------------------------------------
    #
#    method select-server ( Bool :$need-master = True --> MongoDB::Connection ) {
    method select-server ( --> MongoDB::Connection ) {

      my MongoDB::Connection $server;
      while !$server.defined {
        my Bool $isMaster = False;

        loop ( my $pi = 0; $pi < $server-discovery.elems; $pi++ ) {
          my $promise = $server-discovery[$pi];
say "P: $pi, ", $promise.WHAT;

          next unless $promise ~~ Promise and $promise.defined;
say "P sts: ", $promise.status;

          # If promise is kept, the Connection object has been created
          #
          if $promise.status ~~ Kept {
            
            # Get the Connection object from the promise result and check
            # its status. When True, there is a proper server found and its
            # socket can be used for I/O.
            #
            $server = $promise.result;
say "C sts: ", $server.WHAT, ', ', $server.status;
            if $server.status {

              $server-connections.push: $server;

#TODO Test for master server, continue if not and needed
#$isMaster = True;
#last;
            }
            
            else {
              $server = Nil;
            }

            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);
          }

          elsif $promise.status == Broken {
            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);
          }
        
#          elsif $promise.status == Planned {
#            $server-discovery[$pi] = Nil;
#            $server-discovery.splice( $pi, 1);
#          }
        }

        # When there isn't a server found from newly created servers
        # try cached entries
        #
        unless $server.defined {
          loop ( my $si = 0; $si < $server-connections.elems; $si++) {
            $server = $server-connections[$si];
#TODO Test for master server, continue if not and needed
#$isMaster = True;
#last;
say "Cached server $si: ", $server.WHAT, ', ', $server.status;
          }
        }

        unless $server.defined {
          if $server-discovery.elems {
say "sleep ...";
            sleep 1;
          }

          else {
say "server discovery data exhausted";
            return $server;
          }
        }
      }

      return $server;
    }
  }
}

