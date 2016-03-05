use v6.c;
use MongoDB;
use MongoDB::Uri;
use MongoDB::ClientIF;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Wire;
use BSON::Document;

package MongoDB {

  enum Topology-type < Unknown Standalone
                       Replicaset-with-primary
                       Replicaset-no-primary
                     >;
  enum Server-type < Unknown-server
                     Replicaset-primary Replicaset-secondary
                     Replicaset-arbiter
                     Sharding-server
                     Master-server Slave-server
                     Replica-pre-init Recovering-server
                     Rejected-server Failed-server Ghost-server
                   >;

  #-----------------------------------------------------------------------------
  #
  class Client is MongoDB::ClientIF {

    has Bool $.found-master = False;
    has Topology-type $.topology-type = Topology-type::Unknown;

    # Store all found servers here. key is the name of the server which is
    # the server address/ip and its port number. This should be unique.
    #
    has Hash $!servers;

    # Key is same as for $!servers;
    #
    has Hash $!server-discovery;

    has Str $!uri;

    has BSON::Document $.read-concern;
    has Str $!Replicaset;

    has Hash $!uri-data;


    #---------------------------------------------------------------------------
    # Explicitly create an object using the undefined class name to prevent
    # changes in the existing class used as an invocant.
    #
    method new ( Str:D :$uri, BSON::Document :$read-concern ) {

      MongoDB::Client.bless( :$uri, :$read-concern);
    }

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str:D :$uri, BSON::Document :$read-concern ) {

      $!servers = {};
      $!server-discovery = {};
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

      info-message("Found {$uri-obj.server-data<servers>.elems} servers in uri");

      # Background process to discover hosts only if there are new servers
      # to be discovered or that new non default cases are presented.
      #
      for @($uri-obj.server-data<servers>) -> Hash $sdata {
        my $db-admin = self.database('admin');
        $!server-discovery{"$sdata<host>:$sdata<port>"} =  Promise.start( {

            # Create Server object. Throws on failure.
            #
#say "Try connect to server $sdata<host>, $sdata<port>";
            my MongoDB::Server $server .= new(
              :host($sdata<host>), :port($sdata<port>),
              :$!uri-data, :$db-admin
            );

            # Return Server object when server could connect
            #
            info-message("Server $server.name() accepted");

            $server;
          }
        );
      }
    }

    #---------------------------------------------------------------------------
    # Return number of servers
    #
    method nbr-servers ( --> Int ) {

      # Investigate first before getting the nuber of servers. We get a
      # server ticket and must be removed again.
      #
      self!cleanup-promises;
      return $!servers.elems;
    }

    #---------------------------------------------------------------------------
    # Return number of actions left
    #
    method nbr-left-actions ( --> Int ) {

      # Investigate first before getting the nuber of servers. We get a
      # server ticket and must be removed again.
      #
      return self!cleanup-promises;
    }

    #---------------------------------------------------------------------------
    # Called from thread above where Server object is created.
    #
    method server-status ( Str:D $server-name --> Server-type ) {

      my Server-type $sts;
      $sts = $!servers{$server-name}<status> if $!servers{$server-name}.defined;
      return $sts;
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
    method select-server ( BSON::Document :$read-concern --> MongoDB::Server ) {

      my Bool $need-master = False;
      my Bool $found-other-than-unusable;

      my MongoDB::Server $server;
#      my Bool $server-is-master = False;

      my BSON::Document $rc =
        $read-concern.defined ?? $read-concern !! $!read-concern;


      # As long as we didn't find a server. Break out of the loop
      # if there is no data left.
      #
      while !$server.defined {

        $found-other-than-unusable = False;

        # Check if there are any promises left.
        #
        my Int $still-planned = self!cleanup-promises;

        # Loop through the existing set of already found servers
        #
        for $!servers.values -> Hash $srv-struct {

          # Skip all Rejected-server servers
          #
          next if $srv-struct<status>
            ~~ any(Server-type::Rejected-server|Server-type::Failed-server);
          $found-other-than-unusable = True;

          # Check if server is not conflicting
          #
          $server = self!test-server-acceptance($srv-struct);
        }

        self!cleanup-Rejected-server;
        last if $server.defined;

        if $still-planned {
          warn-message("No server found yet with $!uri, wait for running discovery");
          sleep 1;
        }

        elsif $found-other-than-unusable {

          # Try again a bit later to give the servers monitoring some time
          #
          warn-message("No server found yet with $!uri, wait for server monitoringy");
          sleep 1;
        }

        else {
          error-message("No server found with $!uri, discovery data exhausted");
          last;
        }
      }

      return $server;
    }

    #---------------------------------------------------------------------------
    #
    method !cleanup-promises ( --> Int ) {

      my Int $still-planned = 0;

      # Loop through all Promise objects
      #
      for $!server-discovery.keys -> $server-name {

        # When processed, object is cleared. Skip them if encounter one
        #
        next unless $!server-discovery{$server-name}.defined;

        # If promise is kept, the Server object is created and
        # is stored in $!servers.
        #
        if $!server-discovery{$server-name}.status ~~ Kept {
          my MongoDB::Server $server = $!server-discovery{$server-name}.result;

          info-message("Kept: $server.name()");

          # Cleanup promise entry
          #
          $!server-discovery{$server-name}:delete;

          # Save server and start server monitoring.
          #
          self!add-server($server);
        }

        # When broken throw away result
        #
        elsif $!server-discovery{$server-name}.status == Broken {

          # When broken, it is mostly caused by a thrown exception
          # so catch it here.
          #
          try {
            $!server-discovery{$server-name}.result;

            CATCH {
              default {
                warn-message(.message);
                $!server-discovery{$server-name}:delete;
                self!add-failed-server($server-name);
              }
            }
          }
        }

        # When planned look at it in next while cycle
        #
        elsif $!server-discovery{$server-name}.status == Planned {
          info-message("Thread for $server-name still running");
          $still-planned++;
        }
      }

      return $still-planned;
    }

    #---------------------------------------------------------------------------
    # Called from thread above where Server object is created.
    #
    method !add-server ( MongoDB::Server:D $server ) {

      $!servers{$server.name} = {
        server => $server,
        status => Server-type::Unknown-server,
        data-channel => Channel.new(),
        command-channel => Channel.new(),
        server-data => {
          monitor => {},
          weighted-mean-rtt => 0
        }
      }

      info-message( "Server {$server.name} saved");

      # Start server monitoring
      #
      $server._monitor-server(
        $!servers{$server.name}<data-channel>,
        $!servers{$server.name}<command-channel>
      );
    }

    #---------------------------------------------------------------------------
    # Called from thread above where Server object is created.
    #
    method !add-failed-server ( Str:D $server-name ) {

      $!servers{$server-name} = {
        status => Server-type::Failed-server,
      }

      info-message( "Failed server $server-name saved");
    }

    #---------------------------------------------------------------------------
    #
    method !test-server-acceptance ( Hash $srv-struct --> MongoDB::Server ) {

#TODO Check relation of servers otherwise refuse, not yet complete

      my MongoDB::Server $server;
      my Bool $found-master = False;

      # Get new data from the server monitoring process. Might not yet be
      # available.
      #
      my Hash $new-monitor-data = $srv-struct<data-channel>.poll // Hash;
      if $new-monitor-data.defined {
        info-message("New server data from $srv-struct<server>.name()");
        $srv-struct<server-data> = $new-monitor-data;
      }
#say "Srv: $srv-struct<server-data>.perl()";

      # If there is no server data found yet to test against then skip the rest.
      #
      return MongoDB::Server unless $srv-struct<server-data><monitor>.keys;


      # Initial tests on server data
      #
      my Bool $accept-server = True;

      my Str $replsetname = $srv-struct<srv-data><setName> // '';
      my Bool $ismaster = $srv-struct<server-data><monitor><ismaster> //False;

      # Is replicaSet option used on uri?
      #
      if $!uri-data<options><replicaSet>:exists {

        # Server is accepted only if setName is equal to option
        #
        $accept-server = $!uri-data<options><replicaSet> eq $replsetname;
say "IPoll 0: $!uri-data<options><replicaSet>, $accept-server";
      }

      else {

        # No two masters, set if server is accepted and is a master
        #
        $accept-server = not ($found-master and $ismaster);
say "Accept: $accept-server, $ismaster";
      }

      # When server can be accepted, set the status values
      #
      if $accept-server {
        if $ismaster {
          $found-master = True;
          if $replsetname {
            $srv-struct<status> = Server-type::Replicaset-primary;
            $!topology-type = Topology-type::Replicaset-with-primary;
          }
          
          else {
            $srv-struct<status> = Server-type::Master-server;
            $!topology-type = Topology-type::Standalone;
          }
        }

        else {

          if $replsetname {
            $srv-struct<status> = Server-type::Replicaset-secondary;
            $!topology-type = Topology-type::Replicaset-no-primary
              unless $!topology-type ~~ Topology-type::Replicaset-with-primary;
          }

          else {
            $srv-struct<status> = Server-type::Slave-server;
            $!topology-type = Topology-type::Standalone;
          }
        }

        $server = $srv-struct<server>;
        debug-message("Server {$server.name} selected");
      }

      else {
        $srv-struct<status> = Server-type::Rejected-server;
        debug-message("Server {$srv-struct<server>.name} rejected");
      }

      $!found-master = $found-master;
      return $server;
    }

    #---------------------------------------------------------------------------
    #
    method !cleanup-Rejected-server ( ) {
return;

      for $!servers.keys -> Str $srv-name {
say "Status of $srv-name: $!servers{$srv-name}<status>";
        if $!servers{$srv-name}<status> ~~ Server-type::Rejected-server {
          self!remove-server($!servers{$srv-name}<server>);
          $!servers{$srv-name}:delete;
        }
      }
    }

    #---------------------------------------------------------------------------
    #
    method shutdown-server (
      MongoDB::Server $server is copy,
      Bool :$force = False
    ) {
      my BSON::Document $doc = self.database('admin')._internal-run-command(
        BSON::Document.new((
          shutdown => 1,
          :$force
        )),

        :$server
      );

      # Servers do not return an answer when going down.
      # Update: Newer versions of the mongodb server will return ok 1 as of
      # version 3.2.
      #
      if !$doc.defined or ($doc.defined and $doc<ok>) {
        self._take-out-server($server);
      }
    }

    #---------------------------------------------------------------------------
    #
    method _take-out-server ( MongoDB::Server $server is copy ) {
      if $server.defined {

        # Server can be taken out before when a failure takes place in the
        # Wire module. Especially when shutdown-server() is called on
        # servers before version 3.2. Those servers just stop communicating.
        #
        self!remove-server($server) if $server.defined;
      }
    }

    #---------------------------------------------------------------------------
    #
    method !remove-server ( MongoDB::Server $server is copy ) {

      for $!servers.values -> Hash $srv-struct {
        if $srv-struct<server> === $server {

          # Stop monitoring on server and wait for it to stop
          #
          $srv-struct<command-channel>.send('stop');
          sleep 1;
          $srv-struct<command-channel>.receive;
          $!servers{$server.name}:delete;
          undefine $server;
        }
      }
    }

    #---------------------------------------------------------------------------
    #
    method DESTROY ( ) {

      for $!servers.values -> Hash $srv-struct {
        self!remove-server($srv-struct<server>);
      }

      debug-message("Client destroyed");
    }
  }
}

