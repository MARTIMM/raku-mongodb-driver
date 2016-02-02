use v6;
use MongoDB;
use MongoDB::Object-store;
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

    my Array $servers;
    my Array $server-discovery;

    our $db-admin;

    # Semaphore to control the use of select-server. This call can come
    # from different threads.
    #
    state Semaphore $control-select .= new(1);

    # Reserved servers. select-server finds a server using some directions
    # such as read concerns or even direct host:port string. Structure is
    # MD5 code => servers[$server entry]
    #
    has Hash $!server-reservations;

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
    submethod instance ( Str :$uri --> MongoDB::Client ) {

      initialize();

      if ?$uri {
        # Parse the uri and get info in $uri-obj.server-data;
        # Fields are protocol, username, password, servers, database and options
        #
        my MongoDB::Uri $uri-obj .= new(:$uri);

        # Copy some fields into a local $server-data hash which is handed over
        # to the server object. Then add some more.
        #
        my @item-list = <username password database options>;
        my Hash $server-data = %(@item-list Z=> $uri-obj.server-data{@item-list});
        $server-data<client> = $client-object;
        $server-data<db-admin> = $db-admin;

        # Background process to discover hosts only if there are new servers
        # to be discovered or that new non default cases are presnted.
        #
        for @($uri-obj.server-data<servers>) -> Hash $sdata {
          $server-discovery.push: Promise.start( {
              my MongoDB::Server $server;

              try {
                $server .= new(
                  :host($sdata<host>),
                  :port($sdata<port>),
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
    sub initialize ( ) { #--> MongoDB::AdminDB ) {

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
        $db-admin = MongoDB::AdminDB.new;

        $servers = [];
        $server-discovery = [];

        $MongoDB::logger.mlog(
          message => "Client initialized",
          oper-name => 'Client.initialize'
        );
      }
    }

    #---------------------------------------------------------------------------
    #
    method select-server (
      Bool :$need-master = False,
      BSON::Document :$read-concern = BSON::Document.new
      --> Str
    ) {
note "server select acquire";
      $control-select.acquire;

      my MongoDB::Server $server;
      my Int $server-entry;
      my Str $server-ticket;

      # Read all Kept promises and store Server objects in $servers array
      #
      while !$server.defined {

        # First go through all Promises to see if there are still
        # Server objects in the making
        #
        loop ( my $pi = 0; $pi < $server-discovery.elems; $pi++ ) {
          my $promise = $server-discovery[$pi];

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
say "kept";
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
say "broken";
          }

          # When planned look at it in next while cycle
          #
          elsif $promise.status == Planned {
            $MongoDB::logger.mlog(
              message => "Promise $pi still running",
              oper-name => 'Client.select-server'
            );
say "still one planned";
          }
        }

        # Walk through servers array and return server
        #
        $server = Nil;

        loop ( my $si = 0; $si < $servers.elems; $si++) {
say "loop: $si";
          $server = $servers[$si];
          $server-entry = $si;

          if !$need-master or ($need-master and $server.is-master) {
            $MongoDB::logger.mlog(
              message => (
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " selected"
              ),
              oper-name => 'Client.select-server'
            );

say "take: $si";
            last;
          }
        }

        unless $server.defined {
say "not defined";
          if $server-discovery.elems {
            $MongoDB::logger.mlog(
              message => "No server found, wait for running discovery",
              oper-name => 'Client.select-server'
            );
say "waiting";
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

note "server select release";
      $control-select.release;
      $server-ticket = store-object($server) if $server.defined;
      return $server-ticket;
    }

    #---------------------------------------------------------------------------
    #
    method remove-server ( MongoDB::Server $server ) {
note "server remove acquire";
      $control-select.acquire;
      loop ( my $si = 0; $si < $servers.elems; $si++) {
        if $servers[$si] === $server {
          undefine $server;
          $servers.splice( $si, 1);
        }
      }
note "server remove release";
      $control-select.release;
    }
  }
}

