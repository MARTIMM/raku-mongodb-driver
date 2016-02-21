use v6;
use MongoDB;
use MongoDB::Object-store;
use MongoDB::Uri;
use MongoDB::ClientIF;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Wire;
use BSON::Document;

package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Client is MongoDB::ClientIF {

    has Array $!servers;
    has Array $!server-discovery;
    has Str $!uri;

    # Semaphore to control the use of select-server. This call can come
    # from different threads.
    #
    has Semaphore $!control-select .= new(1);

    has MongoDB::Object-store $.store;
    has BSON::Document $.read-concern;
    has Bool $!found-master = False;
    has Str $!replica-set;

    has Hash $!uri-data;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str:D :$uri, BSON::Document :$read-concern ) {

      # Init store
      #
      $!store .= new;

      $!servers = [];
      $!server-discovery = [];
      $!uri = $uri;

      # Parse the uri and get info in $uri-obj. Fields are protocol, username,
      # password, servers, database and options.
      #
      my MongoDB::Uri $uri-obj .= new(:$uri);

      # Store read concern
      #
      $!read-concern =
        $read-concern.defined ?? $read-concern !! BSON::Document.new;

      # Copy some fields into $!uri-data hash which is handed over
      # to the server object..
      #
      my @item-list = <username password database options>;
      $!uri-data = %(@item-list Z=> $uri-obj.server-data{@item-list});

      # Background process to discover hosts only if there are new servers
      # to be discovered or that new non default cases are presented.
      #
      for @($uri-obj.server-data<servers>) -> Hash $sdata {
        $!server-discovery.push: Promise.start( {

            my MongoDB::Server $server .= new(
              :host($sdata<host>), :port($sdata<port>),
              :$!uri-data, :db-admin(self.database('admin')),
              :client(self)
            );

#TODO Check relation of servers otherwise refuse, not yet complete
            # Initial tests on server data
            #
            my $accept-server = True;

            $server._initial-poll;

            # No two masters, then set if server is a master
            #
            $accept-server = False if $!found-master and $server.is-master;
            $!found-master = $server.is-master if $server.is-master;

            # Test replica set name if it is a replica set server
            #
            # replicaSet option in uri is same as replica set name from server
            #
            if $!uri-data<options><replicaSet>:exists
               and $server.monitor-doc<setName>:exists
               and $server.monitor-doc<setName>
                   ne $!uri-data<options><replicaSet> {

              $accept-server = False;
            }

            # No replicaSet option on uri found and server isn't a repl server
            #
            elsif $!uri-data<options><replicaSet>:!exists
                  and $server.monitor-doc<setName>:exists {

              $accept-server = False;
            }

            # All else accept
            #
#            else {
#              $accept-server = False;
#            }

            # Throw an error when not accepted. It wil caught when processing
            # broken promises in cleanup-promises
            #
#            self!add-server($server) if $accept-server;
            fatal-message("Server $server.name() not accepted")
              unless $accept-server;

            # Return a Server object when server is accepted
            #
            info-message("Server $server.name() accepted");
            $server;
          }
        );
      }
    }

    #---------------------------------------------------------------------------
    # Called from thread above where Server object is created.
    #
    method !add-server ( MongoDB::Server:D $server ) {

      # Read all Kept promises and store Server objects in $!servers array
      #
      $!control-select.acquire;

      info-message( "Server {$server.name} saved");
      $!servers.push: $server;

      $!control-select.release;
    }

    #---------------------------------------------------------------------------
    # Return number of servers
    #
    method nbr-servers ( --> Int ) {

      # Investigate first before getting the nuber of servers. We get a
      # server ticket and must be removed again.
      #
      my $t = self.select-server(:!need-master);
      $!store.clear-stored-object($t) if ?$t;
      return $!servers.elems;
    }

    #---------------------------------------------------------------------------
    # Return number of actions left
    #
    method nbr-left-actions ( --> Int ) {

      # Investigate first before getting the nuber of servers. We get a
      # server ticket and must be removed again.
      #
      return $!server-discovery.elems;
    }

    #---------------------------------------------------------------------------
    #
    method database (
      Str:D $name,
      BSON::Document :$read-concern
      --> MongoDB::Database
    ) {

      my BSON::Document $rc =
         $read-concern.defined ?? $read-concern !! $!read-concern;

      return MongoDB::Database.new(
        :client(self),
        :name($name),
        :read-concern($rc)
      );
    }

    #---------------------------------------------------------------------------
    #
    method collection (
      Str:D $full-collection-name,
      BSON::Document :$read-concern
      --> MongoDB::Collection
    ) {
#TODO check for dot in the name

      my BSON::Document $rc =
         $read-concern.defined ?? $read-concern !! $!read-concern;

      ( my $db-name, my $cll-name) = $full-collection-name.split('.');

      my MongoDB::Database $db .= new(
        :client(self),
        :name($db-name),
        :read-concern($rc)
      );

      return $db.collection( $cll-name, :read-concern($rc));
    }

    #---------------------------------------------------------------------------
    #
    method select-server ( BSON::Document :$read-concern --> Str ) {

      my Bool $need-master = False;

      my MongoDB::Server $server;
      my Str $server-ticket;
      my Bool $server-is-master = False;

      my BSON::Document $rc =
        $read-concern.defined ?? $read-concern !! $!read-concern;

      # Read all Kept promises and store Server objects in $!servers array
      #
      while !$server.defined {

        my Bool $still-planned = self!cleanup-promises;

        for @$!servers -> $s {
          $server-is-master = True if $s.is-master;
          if !$need-master or ($need-master and $server-is-master) {
            $server = $s;
            $server-ticket = $.store.store-object($server);
            debug-message(
              "Server {$server.name} selected, is master?: $server-is-master"
            );

            last;
          }
        }

        last if $server.defined;

        if $still-planned {
          warn-message("No server found yet with $!uri, wait for running discovery");
          sleep 1;
        }

        elsif $!servers.elems and !$server-is-master {
          # Try again a bit later to give the servers monitoring some time
          #
          warn-message("No master server found yet with $!uri, wait for server monitoringy");
          sleep 1;
        }

        else {
          error-message("No server found with $!uri, discovery data exhausted");
          last;
        }
      }


      return $server-ticket;
    }

    #---------------------------------------------------------------------------
    #
    method !cleanup-promises ( ) {

      my Bool $still-planned = False;

      loop ( my $pi = 0; $pi < $!server-discovery.elems; $pi++ ) {

        my $promise = $!server-discovery[$pi];

        # If promise is kept, the Server object has been created and
        # stored in $!servers.
        #
        if $promise.status ~~ Kept {
          my $server = $!server-discovery[$pi].result;
          # Cleanup promise entry
          #
          $!server-discovery[$pi] = Nil;
          $!server-discovery.splice( $pi, 1);

          # Save server and start server monitoring if server is accepted
          # after initial poll
          #
          self!add-server($server);
          $server._monitor-server;
        }

        # When broken throw away result
        #
        elsif $promise.status == Broken {

          # When broken, it is caused by a thrown exception
          # so catch it here.
          #
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
          info-message("Thread $pi still running");
          $still-planned = True;
        }
      }

      return $still-planned;
    }

    #---------------------------------------------------------------------------
    #
    method shutdown-server ( Bool :$force = False, Str :$server-ticket ) {
      my BSON::Document $doc = self.database('admin')._internal-run-command(
        BSON::Document.new((
          shutdown => 1,
          :$force
        )),

        :$server-ticket
      );

      # Servers do not return an answer when going down.
      # Update: Newer versions of the mongodb server will return ok 1 as of
      # version 3.2.
      #
      if !$doc.defined or ($doc.defined and $doc<ok>) {
        self._take-out-server($server-ticket);
      }
    }

    #---------------------------------------------------------------------------
    #
    method _take-out-server ( Str $server-ticket ) {
      if ?$server-ticket {
        my $server = $!store.clear-stored-object($server-ticket);

        # Server can be taken out before when a failure takes place in the
        # Wire module. Especially when shutdown-server() is called on
        # servers before version 3.2. Those servers just stop communicating.
        #
        self._remove-server($server) if $server.defined;
      }
    }

    #---------------------------------------------------------------------------
    #
    method _remove-server ( MongoDB::Server $server is rw ) {

#      trace-message("server select acquire");
      $!control-select.acquire;
      loop ( my $si = 0; $si < $!servers.elems; $si++) {
        if $!servers[$si] === $server {
          undefine $server;
          $!servers.splice( $si, 1);
        }
      }

#      trace-message("server remove release");
      $!control-select.release;
    }
  }
}

