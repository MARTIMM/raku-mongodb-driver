use v6;
use MongoDB;
use MongoDB::Object-store;
use MongoDB::Uri;
use MongoDB::ClientIF;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Wire;
use BSON::Document;

package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Client is MongoDB::ClientIF {

    has Array $!servers;
    has Array $!server-discovery;

    # Semaphore to control the use of select-server. This call can come
    # from different threads.
    #
    has Semaphore $!control-select .= new(1);

    # Reserved servers. select-server finds a server using some directions
    # such as read concerns or even direct host:port string. Structure is
    # MD5 code => servers[$server entry]
    #
    has Hash $!server-reservations;

    # These are shared among other Clients
    #
    my MongoDB::Database $db-admin;
    my Bool $initialized = False;

    #---------------------------------------------------------------------------
    submethod BUILD ( Str :$uri --> MongoDB::Client ) {

      unless $initialized {

        # The admin database is given to each server to get server data
        #
        $db-admin = self.database('admin');

        $initialized = True;
      }

      $!servers = [];
      $!server-discovery = [];

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
        $server-data<client> = self;
        $server-data<db-admin> = $db-admin;

        # Background process to discover hosts only if there are new servers
        # to be discovered or that new non default cases are presnted.
        #
        for @($uri-obj.server-data<servers>) -> Hash $sdata {
          $!server-discovery.push: Promise.start( {
            my MongoDB::Server $server;

              $server .= new(
                :host($sdata<host>),
                :port($sdata<port>),
                :$server-data
              );

              info-message("Server $sdata<host>:$sdata<port> connected");

              # Return server object
              #
              $server;
            }
          );
        }
      }
    }

    #---------------------------------------------------------------------------
    # Select a collection. When it is new it comes into existence only
    # after inserting data
    #
    method database ( Str:D $name --> MongoDB::Database ) {

      trace-message("create database $name");
      return MongoDB::Database.new( :client(self), :name($name));
    }

    #---------------------------------------------------------------------------
    #
    method select-server (
      Bool :$need-master = False,
      BSON::Document :$read-concern = BSON::Document.new
      --> Str
    ) {

      my MongoDB::Server $server;
      my Str $server-ticket;
      my Bool $master-found = False;

      # Read all Kept promises and store Server objects in $!servers array
      #
      while !$server.defined {

        if $!control-select.try_acquire {
          trace-message("server select try_acquire");

          # First go through all Promises to see if there are still
          # Server objects in the making
          #
          loop ( my $pi = 0; $pi < $!server-discovery.elems; $pi++ ) {
            my $promise = $!server-discovery[$pi];
            trace-message("discover server $pi");

            # If promise is kept, the Server object has been created 
            #
            if $promise.status ~~ Kept {

              # Get the Server object from the promise result and check
              # its status. When True, the Server object could make a
              # proper connection to the mongo server.
              #
              $server = $promise.result;
              $!servers.push: $server;
              
              # Start server monitoring
              #
              $server.monitor-server;
              
              # Cleanup promise entry
              #
              $!server-discovery[$pi] = Nil;
              $!server-discovery.splice( $pi, 1);

              info-message(
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " saved"
              );
            }

            # When broken throw away result
            #
            elsif $promise.status == Broken {

              try {
                $!server-discovery[$pi].result;

                CATCH {
                  default {
                    warn-message(.message);

                    $!server-discovery[$pi] = Nil;
                    $!server-discovery.splice( $pi, 1);
                  }
                }
              }
            }

            # When planned look at it in next while cycle
            #
            elsif $promise.status == Planned {
              info-message("Promise $pi still running");
            }
          }

          trace-message("server select release");
          $!control-select.release;
        }
        
        else {
          trace-message("server select try_acquire denied");
        }

        # Walk through $!servers array and return server
        #
        $server = Nil;

        loop ( my $si = 0; $si < $!servers.elems; $si++) {
          trace-message("loop through discovered servers entry $si");

          my $s = $!servers[$si];
          $master-found = $s.is-master unless $master-found;

          if !$need-master or ($need-master and $s.is-master) {
            $server = $s;
            info-message(
              [~] "Server $si ", $server.server-name,
              ':', $server.server-port, " selected"
            );

            last;
          }
        }

        unless $server.defined {
          if $!server-discovery.elems {
            warn-message("No server found yet, wait for running discovery");
            sleep 1;
          }
          
          elsif $!servers.elems and !$master-found {
            # Try again a bit later to give the servers monitoring some time
            #
            sleep 1;
          }

          else {
            error-message("No server found, discovery data exhausted, stopping");
            last;
          }
        }
      }

      $server-ticket = store-object($server) if $server.defined;
      return $server-ticket;
    }

    #---------------------------------------------------------------------------
    #
    method remove-server ( MongoDB::Server $server ) {

      trace-message("server select acquire");
      $!control-select.acquire;
      loop ( my $si = 0; $si < $!servers.elems; $si++) {
        if $!servers[$si] === $server {
          undefine $server;
          $!servers.splice( $si, 1);
        }
      }

      trace-message("server remove release");
      $!control-select.release;
    }
  }
}

