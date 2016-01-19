use v6;
use MongoDB;
use MongoDB::ClientIF;
use MongoDB::Server;
use MongoDB::AdminDB;
use MongoDB::Wire;
use BSON::Document;

package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Client is MongoDB::ClientIF {

#TODO refine this method of using server name/port, server pooling etc

    my Array $servers;                  # Array of servers
    my Array $server-discovery;         # Array of promises
    my MongoDB::AdminDB $db-admin;
    my Bool $master-search-in-process = False;

    #---------------------------------------------------------------------------
    # This class is a singleton class
    #
    my MongoDB::Client $client-object;

    method new ( ) {

      die X::MongoDB.new(
        error-text => "This is a singleton, Please use instance()",
        oper-name => 'MongoDB::Client.new()',
        severity => MongoDB::Severity::Fatal
      );
    }

    #---------------------------------------------------------------------------
    multi submethod instance  (
      Str :$host,
      Int :$port where (!$_.defined or 0 <= $_ <= 65535),
      Str :$url
      --> MongoDB::Client
    ) {

      initialize();

      $servers = [] unless $servers.defined;
      $server-discovery = [] unless $server-discovery.defined;

      my Pair @server-specs = ();
      my Str $server-name;
      my Int $server-port;

#say "H & P: {$host//'nh'}, {$port//'np'}, {$url // 'nu'}";

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
      if !$servers.elems
         or $server-name ne 'localhost'
         or $server-port != 27017 {

        for @server-specs -> Pair $spec {
          $server-discovery.push: Promise.start( {
              my $server;

              try {
                $server = MongoDB::Server.new(
                  :client($client-object),
                  :host($spec.key),
                  :port($spec.value),
                  :db-admin($db-admin)
                );

                # Only show the error but do not handle
                #
                CATCH { .say; }
              }

              # Return server object
              #
              $server;
            }
          );
#say "KV: {$spec.kv}, {@server-specs.elems}, {$server-discovery.elems}";
        }
      }

      return $client-object;
    }

    #---------------------------------------------------------------------------
    multi submethod instance ( --> MongoDB::Client ) {
      initialize();
      return $client-object;
    }

    #---------------------------------------------------------------------------
    sub initialize ( ) {
      unless $client-object.defined {
        $client-object = MongoDB::Client.bless;
        MongoDB::Wire.instance.set-client($client-object);
        $db-admin .= new;
      }
    }

    #---------------------------------------------------------------------------
    # Server discovery
    #
    method !discover-servers ( ) {

    }

    #---------------------------------------------------------------------------
    #
    method select-server ( Bool :$need-master = False --> MongoDB::Server ) {

      my MongoDB::Server $server;
      
      # Read all Kept promises and store Server objects in $servers array
      #
      while !$server.defined {
        my Bool $is-master = False;

        loop ( my $pi = 0; $pi < $server-discovery.elems; $pi++ ) {
          my $promise = $server-discovery[$pi];

          next unless $promise ~~ Promise and $promise.defined;

          # If promise is kept, the Server object has been created
          #
          if $promise.status ~~ Kept {

            # Get the Server object from the promise result and check
            # its status. When True, there is a proper server found and its
            # socket can be used for I/O.
            #
            $server = $promise.result;
            $servers.push: $server if $server.status;
            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);
          }

          # When broken throw away result
          #
          elsif $promise.status == Broken {
            $server-discovery[$pi].result;
            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);
          }
        }

        # Walk through servers array and return server
        #
        $server = Nil;

        loop ( my $si = 0; $si < $servers.elems; $si++) {
          $server = $servers[$si];

          # Guard the operation because the request ends up in Wire which
          # will ask for a server using this select-server() method.
          #
          if !$master-search-in-process {
            $master-search-in-process = True;
            $is-master = $server.check-is-master;
            $master-search-in-process = False;
          }

          last if !$need-master or ($need-master and $is-master);
        }

        unless $server.defined {
          if $server-discovery.elems {
            sleep 1;
          }

          else {
#say "server discovery data exhausted";
            last;
            #return $server;
          }
        }
      }

      return $server;
    }

    #---------------------------------------------------------------------------
    #
    method remove-server ( MongoDB::Server $server ) {
      loop ( my $si = 0; $si < $servers.elems; $si++) {
        if $servers[$si] === $server {
          $server.splice( $si, 1);
        }
      }
    }
  }
}

