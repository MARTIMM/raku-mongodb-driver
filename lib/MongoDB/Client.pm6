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
#    my MongoDB::Message $logger;

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
                  :db-admin($db-admin),
                  :$server-data
                );

                $MongoDB::logger.mlog(
                  message => "Server $sdata<host>:$sdata<port> connected",
                  oper-name => 'Client.instance',
                );

                # Only show the error but do not handle
                #
                CATCH {
                  .say;
                  $MongoDB::logger.mlog(
                    message => "Server $sdata<host>:$sdata<port> not connected",
                    oper-name => 'Client.instance'
                  );
                }
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

      # If the Client object isn't created yet then make it and
      # define some variables
      #
      unless $client-object.defined {
        $client-object = MongoDB::Client.bless;
        
        # Wire is also a Singleton and needs this object to get a Server
        # using select-server()
        #
        MongoDB::Wire.instance.set-client($client-object);

        # The admin database is given to each server to get server data
        #
        $db-admin .= new;

        $servers = [];
        $server-discovery = [];
#        $logger .= new;

        $MongoDB::logger.mlog(
          message => "Client initialized",
          oper-name => 'Client.initialize'
        );
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

        # First go through all Promises to see if there are still
        # Server objects in the making
        #
        loop ( my $pi = 0; $pi < $server-discovery.elems; $pi++ ) {
          my $promise = $server-discovery[$pi];

          # Skip all undefined entries in the array
          #
          #next unless $promise ~~ Promise and $promise.defined;

          # If promise is kept, the Server object has been created 
          #
          if $promise.status ~~ Kept {

            # Get the Server object from the promise result and check
            # its status. When True, the Server object could make a
            # proper connection to the mongo server.
            #
            $server = $promise.result;
            $servers.push: $server if $server.status;
            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);

            $MongoDB::logger.mlog(
              message => (
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " saved"
              ),
              oper-name => 'Client.select-server'
            );
          }

          # When broken throw away result
          #
          elsif $promise.status == Broken {
            my $s = $server-discovery[$pi].result;
            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);

            $MongoDB::logger.mlog(
              message => (
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " not saved"
              ),
              oper-name => 'Client.select-server'
            );
          }

          # When planned look at it in next while cycle
          #
          elsif $promise.status == Planned {
            $MongoDB::logger.mlog(
              message => "Promise $pi still running",
              oper-name => 'Client.select-server'
            );
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

          if !$need-master or ($need-master and $is-master) {
            $MongoDB::logger.mlog(
              message => (
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " selected"
              ),
              oper-name => 'Client.select-server'
            );

            last;
          }
        }

        unless $server.defined {
          if $server-discovery.elems {
            $MongoDB::logger.mlog(
              message => "No server found, wait for running discovery",
              oper-name => 'Client.select-server'
            );
            sleep 1;
          }

          else {
            $MongoDB::logger.mlog(
              message => "No server found, discovery data exhausted, stopping",
              oper-name => 'Client.select-server',
              severity => MongoDB::Severity::Info
            );
            
            last;
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
          undefine $server;
          $servers.splice( $si, 1);
        }
      }
    }
  }
}

