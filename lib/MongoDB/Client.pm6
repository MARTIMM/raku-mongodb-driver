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
    submethod BUILD (
      Str :$uri,
      BSON::Document :$read-concern
    ) {

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
#TODO Check relation of servers otherwise refuse
        for @($uri-obj.server-data<servers>) -> Hash $sdata {
          $!server-discovery.push: Promise.start( {
            my MongoDB::Server $server;

              $server .= new(
                :host($sdata<host>),
                :port($sdata<port>),
                :$server-data
              );

              # Return server object
              #
              self!add-server($server);
              $server;
            }
          );
        }
      }
    }

    #---------------------------------------------------------------------------
    # Called from thread above where Server object is created.
    #
    method !add-server ( MongoDB::Server:D $server ) {

      # Read all Kept promises and store Server objects in $!servers array
      #
      trace-message("server select try_acquire");
      $!control-select.acquire;

      info-message( "Server {$server.name} saved");
      $!servers.push: $server;

      trace-message("server select release");
      $!control-select.release;
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

        my Bool $still-planned = self!cleanup-promises;

#say "Nbr servers: {$!servers.elems}";

        for @$!servers -> $s {
#          debug-message( "Server is master 1?: {$s.is-master}");
#say "ss: {$s.name}";

          $master-found = True if $s.is-master;
          if !$need-master or ($need-master and $master-found) {
#say "ss 1";
#            debug-message( "Server is master 2?: $master-found");
#say "ss 2";
            $server = $s;
            debug-message(
              "Server {$server.name} selected, is master?: $master-found"
            );

            last;
          }
        }
#say "ss 3";

        last if $server.defined;

#say "discover: {$!server-discovery.elems}";
        if $still-planned {
          warn-message("No server found yet, wait for running discovery");
          sleep 1;
        }

        elsif $!servers.elems and !$master-found {
          # Try again a bit later to give the servers monitoring some time
          #
          warn-message("No master server found yet, wait for server monitoringy");
          sleep 1;
        }

        else {
          error-message("No server found, discovery data exhausted");
          last;
        }
      }

      $server-ticket = store-object($server) if $server.defined;
#say "ss 4 $server-ticket";
      return $server-ticket;
    }

    #---------------------------------------------------------------------------
    #
    method !cleanup-promises ( ) {

#say "Nbr promises: {$!server-discovery.elems}";

      my Bool $still-planned = False;

      loop ( my $pi = 0; $pi < $!server-discovery.elems; $pi++ ) {

        my $promise = $!server-discovery[$pi];

        # If promise is kept, the Server object has been created and
        # stored in $!servers.
        #
        if $promise.status ~~ Kept {
#say "cp 2k";
          my $server = $!server-discovery[$pi].result;

          # Cleanup promise entry
          #
          $!server-discovery[$pi] = Nil;
          $!server-discovery.splice( $pi, 1);

          # Start server monitoring
          #
          $server.monitor-server;
        }

        # When broken throw away result
        #
        elsif $promise.status == Broken {
#say "cp 2b";

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
#say "cp 2p";
          info-message("Promise $pi still running");
          $still-planned = True;
        }
      }

      return $still-planned;
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

