use v6.c;

use MongoDB;
use MongoDB::Uri;
use MongoDB::ClientIF;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Wire;
use BSON::Document;

unit package MongoDB;

# Start as TUnknown type and Unknown-server status
#
enum Topology-type < TUnknown TStandalone
                     Replicaset-with-primary
                     Replicaset-no-primary
                   >;

enum Server-status < Unknown-server Down-server Recovering-server
                     Rejected-server Ghost-server
                     Replicaset-primary Replicaset-secondary
                     Replicaset-arbiter
                     Sharding-server
                     Master-server Slave-server
                     Replica-pre-init
                   >;

#-------------------------------------------------------------------------------
#
class Client is MongoDB::ClientIF {

  has Bool $.found-master = False;
  has Topology-type $.topology-type = Topology-type::TUnknown;

  # Store all found servers here. key is the name of the server which is
  # the server address/ip and its port number. This should be unique.
  #
  has Hash $!servers;
  has Str $!master-servername;          # Modify only in thread
  has Semaphore $!servers-semaphore;

  # Key is same as for $!servers;
  #
  has Hash $!server-discovery;

  has Str $!uri;

  has BSON::Document $.read-concern;
  has Str $!Replicaset;

  has Hash $!uri-data;

  has Promise $!Background-discovery;
  has Channel $!Background-command-pipe;
#  has Channel $!Background-result-pipe;

  #-----------------------------------------------------------------------------
  # Explicitly create an object using the undefined class name to prevent
  # changes in the existing class when used as an invocant.
  #
#  method new ( Str:D :$uri, BSON::Document :$read-concern ) {
#
#    MongoDB::Client.bless( :$uri, :$read-concern);
#  }

  #-----------------------------------------------------------------------------
  #
  submethod BUILD ( Str:D :$uri, BSON::Document :$read-concern ) {

    $!servers = {};
    $!servers-semaphore .= new(1);
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

    # Background proces to handle server monitoring data
    $!Background-command-pipe .= new;
    $!Background-discovery = Promise.start( {

        # Start processing when something is produced
        while my Hash $server-data = $!Background-command-pipe.receive {

          # Create server object
          my MongoDB::Server $server .= new(
            :host($server-data<host>),
            :port($server-data<port>),
            :$!uri-data
          );

          info-message("Server $server.name() processed");

          my Str $server-name = "$server-data<host>:$server-data<port>";

#          self!add-server($server);
          # Start server monitoring
          $server.server-init;

          # Tap into the stream of monitor data
          $server.tap-monitor( -> Hash $monitor-data {

say "Monitor: ", $monitor-data.perl;
              # Only when data is ok
              my Hash $h = {
                server => $server,
                status => $server.get-status,
                timestamp => now,
                server-data => $monitor-data // {}
              };

say "Hash 0: $h.perl()";
              # No errors while monitoring
              if $monitor-data.defined and $monitor-data<ok> {

              }

              # There are errors while monitoring
              elsif $monitor-data.defined {

                # Not found by DNS so big chance that it doesn't exist
                if $h<status> ~~ MongoDB::C-NON-EXISTENT-SERVER {

                  $server.stop-monitor;
#                  undefine $server;
#                  $server = Nil;
#                  $h = Nil;
                  error-message("Stopping monitor: $monitor-data<reason>");
                }

                # Down server can be revived
                else {

                }
              }
              
              # Other cases should be skipped
              else {
#                $h = Nil;
              }

say "Hash 1: $h.perl()";
              # Check for double master servers
              if $h.defined {
                if $h<status> ~~ any(
                  MongoDB::C-MASTER-SERVER |
                  MongoDB::C-REPLICASET-PRIMARY
                ) {

                  # Not defined, be the first master server
                  if not $!master-servername.defined {
                    $!master-servername = $server.name;
                  }

                  # Is defined, be the second and rejected master server
                  else {
                    if $!master-servername ne $server.name {
                      $h<status> = MongoDB::C-REJECTED-SERVER;
                      error-message("Server $server.name() rejected, second master");
                    }
                  }
                }

#TODO $!master-servername must be able to change when server roles are changed
#TODO Define client topology

                # Store result
                $!servers-semaphore.acquire;
                $!servers{$server.name} = $h;
                $!servers-semaphore.release;
              }
            }
          );
        }
      }
    );

    # Feed background process with hosts.
    for @($uri-obj.server-data<servers>) -> Hash $server-data {
      $!Background-command-pipe.send($server-data);
    }
  }

  #-----------------------------------------------------------------------------
  # Return number of servers
  #
  method nbr-servers ( --> Int ) {

    $!servers-semaphore.acquire;
    my $nservers = $!servers.elems;
    $!servers-semaphore.release;

    $nservers;
  }

  #-----------------------------------------------------------------------------
  # Called from thread above where Server object is created.
  #
  method server-status ( Str:D $server-name --> MongoDB::ServerStatus ) {

    $!servers-semaphore.acquire;
    my Hash $h = $!servers{$server-name};
    $!servers-semaphore.release;

    my MongoDB::ServerStatus $sts = $h<status> if $h.defined;
  }

  #-----------------------------------------------------------------------------
  #
  method select-server ( BSON::Document :$read-concern --> MongoDB::Server ) {

#TODO use read/write concern for selection
#TODO must break loop when nothing is found
    my Int $test-count = 10;
    my Hash $h;
    while $test-count-- {

      if $!master-servername.defined {
        $!servers-semaphore.acquire;
        my Hash $h = $!servers{$!master-servername};
        $!servers-semaphore.release;
      }

      sleep 1;
    }

    $h<server> // MongoDB::Server;
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

    MongoDB::Database.new( :client(self), :name($name), :read-concern($rc));
  }

  #-----------------------------------------------------------------------------
  #
  method collection (
    Str:D $full-collection-name,
    BSON::Document :$read-concern
    --> MongoDB::Collection
  ) {
#TODO check for dot in the name

    my BSON::Document $rc =
       $read-concern.defined ?? $read-concern !! $!read-concern;

    ( my $db-name, my $cll-name) = $full-collection-name.split( '.', 2);

    my MongoDB::Database $db .= new(
      :client(self),
      :name($db-name),
      :read-concern($rc)
    );

    return $db.collection( $cll-name, :read-concern($rc));
  }

  #-----------------------------------------------------------------------------
  #
  method DESTROY ( ) {

    # Remove all servers concurrently. Shouldn't be many per client.
    for $!servers.values.race(batch => 1) -> Hash $srv-struct {

      if $srv-struct<server>.defined {

        # Stop monitoring on server
        #
        $srv-struct<server>.stop-monitor;

        info-message(
          "Server $srv-struct<server>.name() "
            ~ $srv-struct<command-channel>.receive
        );

        undefine $srv-struct<server>;
      }
    }

    debug-message("Client destroyed");
  }
}





=finish




  #-----------------------------------------------------------------------------
  #
  method select-server ( BSON::Document :$read-concern --> MongoDB::Server ) {

    my Bool $need-master = False;
    my Bool $found-other-than-unusable;

    my MongoDB::Server $server;
#      my Bool $server-is-master = False;

    my BSON::Document $rc =
      $read-concern.defined ?? $read-concern !! $!read-concern;

#say "SS: 0";
    # As long as we didn't find a server. Break out of the loop
    # if there is no data left.
    #
    while !$server.defined {

      $found-other-than-unusable = False;

      # Check if there are any promises left.
      #
      my Int $still-planned = self!cleanup-promises;
#say "SS: 1, still planned: $still-planned";

      # Loop through the existing set of already found servers
      #
      for $!servers.keys -> Str $server-name {
#say "SS: 2, server: $server-name";

        my Hash $srv-struct = $!servers{$server-name};

        # Try to revive down servers
        #
        self!revive-server( $server-name, $srv-struct);

        # Skip all rejected and unconnectable servers
        #
#say "SS: 3, server status: $srv-struct<status>";
        next if $srv-struct<status>  ~~ any(
          Server-status::Rejected-server |
          Server-status::Down-server |
          Server-status::Recovering-server
        );

        $found-other-than-unusable = True;

        # Check if server is not conflicting
        #
        $server = self!test-server-acceptance($srv-struct);
      }

#say "SS: 4, server defined: {$server.defined ?? $server.name !! '-'}";
      last if $server.defined;

      if $still-planned {
        warn-message("No server found yet with $!uri, wait for running discovery");
        sleep 1;
      }

      elsif $found-other-than-unusable {

        # Try again a bit later to give the servers monitoring some time
        #
        warn-message("No server found yet with $!uri, wait for server monitoring");
        sleep 1;
      }

      else {
        error-message("No server found with $!uri, discovery data exhausted");
        last;
      }
    }

#say "SS: 5, server returned: {$server.defined ?? $server.name !! '-'}";
    return $server;
  }

  #-----------------------------------------------------------------------------
  #
  method !revive-server ( Str $server-name, Hash $srv-struct ) {

    # Retry after every 5 sec
    #
    if $srv-struct<status> ~~ Server-status::Down-server
       and (now - $srv-struct<timestamp> > 5) {

      # Shouldn't happen
      fatal-message("Discovery entry for $server-name still defined")
        if $!server-discovery{$server-name}.defined;

      # Next round is again some seconds from now
      #
      $srv-struct<timestamp> = now;

      # When server is added this will also be set but we need this done
      # sooner to prevent a second start in a later cycle. When the server
      # fails to start, it will be set back to Down-server.
      #
      $srv-struct<status> = Server-status::Recovering-server;

      ( my $host, my $port) = $server-name.split(':');

      trace-message("Revive: $server-name, $host, $port");
#      $!server-discovery{$server-name} =
#        self!start-server-promise( $host, $port.Int);
    }
  }

  #-----------------------------------------------------------------------------
  #
  method !test-server-acceptance ( Hash $srv-struct --> MongoDB::Server ) {

#TODO Check relation of servers otherwise refuse, not yet complete

    my MongoDB::Server $server;
    my Bool $found-master = False;

    # Get new data from the server monitoring process. Might not yet be
    # available. The monitoring takes place regularly so we must get the
    # last data sent over the channel.
    #
    my Hash $new-monitor-data;
    while my Hash $nmd = $srv-struct<data-channel>.poll // Hash {
      $new-monitor-data = $nmd if $nmd.defined;
    }

    if $new-monitor-data.defined              # Data sent?
       and $new-monitor-data<ok>              # Server ok
       and $new-monitor-data<monitor><ok> {   # Sent server data ok

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
    my Bool $ismaster = $srv-struct<server-data><monitor><ismaster> // False;
    my Bool $issecondary = $srv-struct<server-data><monitor><secondary> // False;
    my Bool $isreplicaset = $srv-struct<server-data><monitor><isreplicaset> // False;

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
#say "Accept server: $accept-server, is master: $ismaster";
    }

    # When server can be accepted, set the status values
    #
    if $accept-server {

      if $ismaster {

        $found-master = True;
        if $replsetname {
          $srv-struct<status> = Server-status::Replicaset-primary;
          $!topology-type = Topology-type::Replicaset-with-primary;
        }

        else {
          $srv-struct<status> = Server-status::Master-server;
          $!topology-type = Topology-type::TStandalone;
        }
      }


      elsif $issecondary {

        if $replsetname {
          $srv-struct<status> = Server-status::Replicaset-secondary;
          $!topology-type = Topology-type::Replicaset-no-primary
            unless $!topology-type ~~ Topology-type::Replicaset-with-primary;
        }

        else {
          $srv-struct<status> = Server-status::Slave-server;
          $!topology-type = Topology-type::TStandalone;
        }
      }

      # The server is neither master nor secondary. If isreplicaset is True
      # then it is a pre inititialized server
      #
      elsif $isreplicaset {
        $srv-struct<status> = Server-status::Replica-pre-init;
        $!topology-type = Topology-type::Topology-type::Replicaset-no-primary
            unless $!topology-type ~~ Topology-type::Replicaset-with-primary;
      }

      $server = $srv-struct<server>;
      debug-message("Server {$server.name} type and status: $!topology-type, $srv-struct<status>");
    }

    else {
      $srv-struct<status> = Server-status::Rejected-server;
      debug-message("Server {$srv-struct<server>.name} rejected");
    }

    $!found-master = $found-master;
    return $server;
  }
  #-----------------------------------------------------------------------------
  #
  method !cleanup-promises ( --> Int ) {

    my Int $still-planned = 0;

#say "CLP: servers $!server-discovery.keys()";

    # Loop through all Promise objects
    #
    for $!server-discovery.keys -> $server-name {

      # When processed, object is cleared. Skip them if encounter one
      #
      next unless $!server-discovery{$server-name}.defined;

      # If promise is kept, the Server object is created and
      # is stored in $!servers.
      #
#say "CLP: $server-name, ", $!server-discovery{$server-name}.status;
      if $!server-discovery{$server-name}.status ~~ Kept {
        my MongoDB::Server $server = $!server-discovery{$server-name}.result;

        info-message("Kept: $server.name()");

        # Cleanup promise entry
        #
        $!server-discovery{$server-name}:delete;

        # Save server and start server monitoring.
        #
#        self!add-server($server);
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
#              self!add-Down-server($server-name);
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

  #-----------------------------------------------------------------------------
  method !start-server-promise ( $host, $port --> Promise ) {

    Promise.start( {

        trace-message("Try connect to server $host, $port");

        # Create Server object. Throws on failure.
        #
        my MongoDB::Server $server .= new( :$host, :$port, :$!uri-data);

        # Return Server object when server could connect
        #
        info-message("Server $server.name() accepted");

        $server;
      }
    );
  }

  #-----------------------------------------------------------------------------
  # Return number of actions left
  #
  method nbr-left-actions ( --> Int ) {

    # Investigate first before getting the nuber of servers. We get a
    # server ticket and must be removed again.
    #
    return self!cleanup-promises;
  }

  #-----------------------------------------------------------------------------
  # Called from thread above where Server object is created.
  #
  method !add-server ( MongoDB::Server:D $server ) {

    $!servers-semaphore.acquire;
    $!servers{$server.name} = {
      server => $server,
      status => $server.get-status,
      timestamp => now,
      server-data => {
        monitor => {},
        weighted-mean-rtt => 0
      }
    }
    $!servers-semaphore.release;

    info-message( "Server {$server.name} saved");
  }

  #-----------------------------------------------------------------------------
  # Called from thread above where Server object is created.
  #
  method !add-Down-server ( Str:D $server-name ) {

    $!servers{$server-name} = {
      status => Server-status::Down-server,
      timestamp => now
    }

    info-message( "Failed server $server-name saved");
  }

  #-----------------------------------------------------------------------------
  #
#TODO shutdown via Control.pm6
  method shutdown-server (
    MongoDB::Server $server is copy,
    Bool :$force = False
  ) {
return;

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

  #-----------------------------------------------------------------------------
  #
  method _take-out-server ( MongoDB::Server $server is copy ) {

say "$server.name() is down, change state";

    if $server.defined {

      # Server can be taken out before when a failure takes place in the
      # Wire module. Especially when shutdown-server() is called on
      # servers before version 3.2. Those servers just stop communicating.
      #
      self!remove-server($server) if $server.defined;
    }
  }


  #-----------------------------------------------------------------------------
  #
  method !remove-server ( MongoDB::Server $server is copy ) {

    for $!servers.values -> Hash $srv-struct {
      if $srv-struct<server> === $server {

        $srv-struct<status> = MongoDB::C-DOWN-SERVER;
        $srv-struct<timestamp> = now;
      }
    }
  }



