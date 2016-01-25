use v6;
use MongoDB;
use MongoDB::Uri;
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
    submethod instance ( Str :$uri = 'mongodb://' --> MongoDB::Client )  {
      initialize();

      # Parse the uri and get info in $uri-obj.server-data;
      # Fields are protocol, username, password, servers, database and options
      #
      my MongoDB::Uri $uri-obj .= new(:$uri);

      # Copy some fields into a local $server-data hash which is handed over
      # to the server object.
      #
      my @item-list = <username password database options>;
      my Hash $server-data = %(@item-list Z=> $uri-obj.server-data{@item-list});

      # Background process to discover hosts only if there are new servers
      # to be discovered or that new non default cases are presnted.
      #
      if $uri-obj.server-data<servers>.elems {

        for @($uri-obj.server-data<servers>) -> Hash $sdata {
          $server-discovery.push: Promise.start( {
              my MongoDB::Server $server;

              try {
                $server .= new(
                  :client($client-object),
                  :host($sdata<host>),
                  :port($sdata<port>),
                  :db-admin($db-admin)
                  :$server-data
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
        }
      }

      return $client-object;
    }

    #---------------------------------------------------------------------------
    sub initialize ( ) {
      $servers = [] unless $servers.defined;
      $server-discovery = [] unless $server-discovery.defined;

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
    method select-server (
      Bool :$need-master = False,
      BSON::Document :$read-concern = BSON::Document.new
      --> MongoDB::Server
    ) {

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

