use v6.c;

use MongoDB;
use MongoDB::Uri;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Wire;
use BSON::Document;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
class Client {

  has MongoDB::TopologyType $!topology-type;

  # Store all found servers here. key is the name of the server which is
  # the server address/ip and its port number. This should be unique.
  #
  has Hash $!servers;
  has Semaphore $!servers-semaphore;

  has Array $!todo-servers;
#  has Bool $!processing-todo-list;
  has Semaphore $!todo-servers-semaphore;

  has Str $!master-servername;
  has Semaphore $!master-servername-semaphore;

  has Str $!uri;
  has Hash $!uri-data;

  has BSON::Document $.read-concern;
  has Str $!Replicaset;

  has Promise $!Background-discovery;

#`{{
  #-----------------------------------------------------------------------------
  # Explicitly create an object using the undefined class name to prevent
  # changes in the existing class when used as an invocant.
  #
  method new ( Str:D :$uri, BSON::Document :$read-concern ) {

say 'new client 0';
    my $x = MongoDB::Client.bless( :$uri, :$read-concern);
say 'new client 1';
    $x;
  }
}}
  #-----------------------------------------------------------------------------
  submethod BUILD (
    Str:D :$uri, BSON::Document :$read-concern, Int :$loop-time
  ) {

    $!topology-type = MongoDB::C-UNKNOWN-TPLGY;

    $!servers = {};
    $!servers-semaphore .= new(1);

    # Start as if we must process servers so the Boolean is set to True
    $!todo-servers = [];
#    $!processing-todo-list = True;
    $!todo-servers-semaphore .= new(1);

    $!master-servername = Nil;
    $!master-servername-semaphore .= new(1);

    # Store read concern
    $!read-concern =
      $read-concern.defined ?? $read-concern !! BSON::Document.new;

    # Parse the uri and get info in $uri-obj. Fields are protocol, username,
    # password, servers, database and options.
    #
    $!uri = $uri;

    # Copy some fields into $!uri-data hash which is handed over
    # to the server object..
    #
    my @item-list = <username password database options>;
    my MongoDB::Uri $uri-obj .= new(:$!uri);
    $!uri-data = %(@item-list Z=> $uri-obj.server-data{@item-list});

    debug-message("Found {$uri-obj.server-data<servers>.elems} servers in uri");

    # Setup todo list with servers to be processed, Safety net not needed yet
    # because threads are not started.
    for @($uri-obj.server-data<servers>) -> Hash $server-data {
      $!todo-servers.push("$server-data<host>:$server-data<port>");
    }

    # Background proces to handle server monitoring data
    $!Background-discovery = Promise.start( {

        loop {
          # This reading of the todo list might start too quick, reading before
          # anything is pushed onto the list by the main thread. Then
          # $!processing-todo-list togles to False which then produces failures
          # later when select-server or nbr-servers is called.
          #
#          sleep 1;

          # Start processing when something is found in todo hash
          $!todo-servers-semaphore.acquire;
          my Str $server-name = $!todo-servers.shift if $!todo-servers.elems;
          $!todo-servers-semaphore.release;

          if $server-name.defined {

            trace-message("Processing server $server-name");

            $!servers-semaphore.acquire;
            my Bool $server-processed = $!servers{$server-name}:exists;
            $!servers-semaphore.release;

            # Check if server was managed before
            if $server-processed {
              trace-message("Server $server-name already managed");
              next;
            }

#say "New server object: $server-name";
            my MongoDB::Server $server .= new(
              :$server-name, :$!uri-data, :$loop-time
            );

            # Start server monitoring process its data
#say "Init server object and start monitoring: $server-name";
            $server.server-init();
#say "Tap from monitor: $server-name";
            self!process-monitor-data($server);
          }

          else {

            # When there is no work take a nap!
            # This sleeping period is the moment we do not process the todo list
#            $!todo-servers-semaphore.acquire;
#            $!processing-todo-list = False;
#            $!todo-servers-semaphore.release;

            sleep 1;

#            $!todo-servers-semaphore.acquire;
#            $!processing-todo-list = True;
#            $!todo-servers-semaphore.release;
          }
        }
      }
    );
  }

  #-----------------------------------------------------------------------------
  method !process-monitor-data ( MongoDB::Server $server ) {

    my Str $server-name = $server.name;

    # Tap into the stream of monitor data
    my Tap $t = $server.tap-monitor( -> Hash $monitor-data {
#say "\nIn client, data from Monitor: ", ($monitor-data // {}).perl;

#        if $monitor-data.defined and $monitor-data<ok>:exists {
#          my Bool $found-new-servers = False;
#say "Monitor $server-name: ", $monitor-data.perl if $monitor-data.defined;

          # Make the processing of the monitor data atomic
#note "servers-semaphore.acquire";
          $!servers-semaphore.acquire;

          my Hash $prev-server = $!servers{$server-name}:exists
                         ?? $!servers{$server-name}
                         !! Nil;
#          $!servers-semaphore.release;

          $!master-servername-semaphore.acquire;
          my $msname = $!master-servername;
          $!master-servername-semaphore.release;

#say "MS ($server-name) name: {$msname//'-'}";

#          my Hash $h = {
#            server => $server,
#            status => $server.get-status,
#            timestamp => now,
#            server-data => $monitor-data
#          };

          # Store partial result as soon as possible
#          $!servers-semaphore.acquire;
#overschreven????
          $!servers{$server-name} = {
            server => $server,
            status => $server.get-status,
            timestamp => now,
            server-data => $monitor-data
          };
#say "Saved monitor data for $server-name = ", $!servers{$server-name}.perl;
#          $!servers-semaphore.release;

          # Only when data is ok
          if not $monitor-data.defined {

            error-message("No monitor data received");
          }

          # There are errors while monitoring
          elsif not $monitor-data<ok> {

            # Not found by DNS so big chance that it doesn't exist
            if $!servers{$server-name}<status> ~~ MongoDB::C-NON-EXISTENT-SERVER {

              $server.stop-monitor;
              error-message("Stopping monitor: $monitor-data<reason>");
            }

            # Connection failure
            elsif $!servers{$server-name}<status> ~~ MongoDB::C-DOWN-SERVER {

              # Check if the master server went down
              if $msname.defined and ($msname eq $server-name) {

                $!master-servername-semaphore.acquire;
                $!master-servername = Nil;
                $!master-servername-semaphore.release;
              }

              warn-message("Server is down: $monitor-data<reason>");
            }
          }


          # Monitoring data is ok
          else {

#say 'Master server name: ', $msname // '-';
#say 'Master prev stat: ', $prev-server<status>:exists 
#                  ?? $prev-server<status>
#                  !! '-';

#say "PMD: $server-name, $!servers{$server-name}<status>, ", $msname // '-';
            # Don't ever modify a rejected server
            if $prev-server<status>:exists
               and $prev-server<status> ~~ MongoDB::C-REJECTED-SERVER {

#              $!servers-semaphore.acquire;
              $!servers{$server-name}<status> = MongoDB::C-REJECTED-SERVER;
#              $!servers-semaphore.release;
            }

            # Check for double master servers
            elsif $!servers{$server-name}<status> ~~ any(
              MongoDB::C-MASTER-SERVER |
              MongoDB::C-REPLICASET-PRIMARY
            ) {
              # Is defined, be the second and rejected master server
              if $msname.defined {
                if $msname ne $server-name {
#                  $!servers-semaphore.acquire;
                  $!servers{$server-name}<status> = MongoDB::C-REJECTED-SERVER;
#                  $!servers-semaphore.release;
                  error-message("Server $server-name rejected, second master");
                }
              }

              # Not defined, be the first master server
              else {

                $!master-servername-semaphore.acquire;
                $!master-servername = $server-name;
                $!master-servername-semaphore.release;
              }
            }

            else {

#say "H4: $!servers{$server-name}<status>, ", $msname // '-', ', ', $server-name;
            }

            # When primary, find all servers and add to todo list
            if $!servers{$server-name}<status> ~~ MongoDB::C-REPLICASET-PRIMARY {

              my Array $hosts = $!servers{$server-name}<server-data><monitor><hosts>;
              for @$hosts -> $hostspec {

#              # Check if server is processed before
#              $!servers-semaphore.acquire;
#              my Bool $processed = $!servers{$hostspec}:exists;
#              $!servers-semaphore.release;
#
#              next if $processed;
#
#              # If not push onto todo list
                trace-message("Push $hostspec from primary list on todo list");
                $!todo-servers-semaphore.acquire;
                $!todo-servers.push($hostspec);
#                $found-new-servers = True;
                $!todo-servers-semaphore.release;
#say "Add $hostspec, $!todo-servers.elems()";
              }
            }

            # When secondary get its primary and add to todo list
            elsif $!servers{$server-name}<status> ~~ MongoDB::C-REPLICASET-SECONDARY {

              # Error when current master is not same as primary
              my $primary = $!servers{$server-name}<server-data><monitor><primary>;
              if $msname.defined and $msname ne $primary {
                error-message(
                  "Server $primary found but != current master $msname"
                );
              }

              # When defined w've already processed it, if not, go for it
              elsif not $msname.defined {

                trace-message("Push primary $primary on todo list");
                $!todo-servers-semaphore.acquire;
                $!todo-servers.push($primary);
#                $found-new-servers = True;
                $!todo-servers-semaphore.release;
#say "Add primary $primary, $!todo-servers.elems()";
              }
            }

#TODO $!master-servername must be able to change when server roles are changed
#TODO Define client topology
          }

#          # Store result
#          $!servers-semaphore.acquire;
#          $!servers{$server-name} = $h;
#say "Saved monitor data for $server-name = ", $!servers{$server-name}.perl;
#          $!servers-semaphore.release;

# Not necessary to check todo list and change the boolean here because the list
# is processed before setting the boolean
#        }

          # Release semaphore and also force unlocking when an exception
          # was thrown
#note "servers-semaphore.release";
          $!servers-semaphore.release;
          CATCH {
            default {
#note "servers-semaphore.release in exception";
              $!servers-semaphore.release;
              .rethrow;
            }
          }
      }
    );
  }

  #-----------------------------------------------------------------------------
  # Return number of servers
  method nbr-servers ( --> Int ) {

    self!check-discovery-process;
#    self!check-todo-process;

    $!servers-semaphore.acquire;
    my $nservers = $!servers.elems;
    $!servers-semaphore.release;

    $nservers;
  }

  #-----------------------------------------------------------------------------
  # Called from thread above where Server object is created.
  method server-status ( Str:D $server-name --> MongoDB::ServerStatus ) {

    self!check-discovery-process;
#    self!check-todo-process;

    $!servers-semaphore.acquire;
    my Hash $h = $!servers{$server-name}:exists
                 ?? $!servers{$server-name}
                 !! {};
    $!servers-semaphore.release;
#say "server-status: $server-name, ", $h.perl;

    my MongoDB::ServerStatus $sts = $h<status> // MongoDB::C-UNKNOWN-SERVER;
  }

  #-----------------------------------------------------------------------------
  # Selecting servers based on;
  # - read/write concern, depends on server version
  # - state of a server, e.g. to initialize a replica server or to get a slave
  #   or arbiter
  # - default is to get a master server
  #-----------------------------------------------------------------------------

#TODO use read/write concern for selection
#TODO must break loop when nothing is found

  # Read/write concern selection
  multi method select-server (
    BSON::Document:D :$read-concern!
    --> MongoDB::Server
  ) {

    self.select-server;
  }

  #-----------------------------------------------------------------------------
  # State of server selection
  multi method select-server (
    MongoDB::ServerStatus:D :$needed-state!,
    Int :$check-cycles is copy = -1
    --> MongoDB::Server
  ) {

    self!check-discovery-process;
#    self!check-todo-process;

    my Hash $h;

    WHILELOOP:
    while $check-cycles != 0 {

      # Take this into the loop because array can still change, might even
      # be empty when hastely called right after new()
      $!servers-semaphore.acquire;
      my @server-names = $!servers.keys;
      $!servers-semaphore.release;

      for @server-names -> $msname {
        $!servers-semaphore.acquire;
        my Hash $shash = $!servers{$msname};
        $!servers-semaphore.release;

        if $shash<status> == $needed-state {
          $h = $shash;
          last WHILELOOP;
        }
      }

      $check-cycles--;
      sleep 1;
    }

    if $h.defined and $h<server> {
      info-message("Server $h<server>.name() selected");
    }

    else {
      error-message('No typed server selected');
    }

    $h<server> // MongoDB::Server;
  }

  #-----------------------------------------------------------------------------
  # Default master server selection
  multi method select-server (
    Int :$check-cycles is copy = -1
    --> MongoDB::Server
  ) {

    self!check-discovery-process;
#    self!check-todo-process;

    my Hash $h;
    my Str $msname;
#    my Bool $found-master-server = False;

    # When $check-cycles in not set it will be -1, therefore $check-cycles
    # will not reach 0 and loop becomes infinite.
#    while not $found-master-server and $check-cycles != 0 {
    while $check-cycles != 0 {
      $!master-servername-semaphore.acquire;
      $msname = $!master-servername;
      $!master-servername-semaphore.release;

#note "select-server, {$msname//'-'}";
      if $msname.defined {
        $!servers-semaphore.acquire;
        $h = $!servers{$msname};
        $!servers-semaphore.release;
#        $found-master-server = ?$msname;
        last;
      }

      $check-cycles--;
      sleep 1;
    }

    $h<server> // MongoDB::Server;
  }

  #-----------------------------------------------------------------------------
  # Check if background process is still running
  method !check-discovery-process ( ) {

    if $!Background-discovery.status ~~ any(Broken|Kept) {
      fatal-message(
        'Discovery stopped ' ~
        ($!Background-discovery.status ~~ Broken
                         ?? $!Background-discovery.cause
                         !! ''
        )
      );
    }
  }

  #-----------------------------------------------------------------------------
  # Check if thread is working on todo list
#  method !check-todo-process ( ) {
#
#    my Bool $still-processing = True;
#    while $still-processing {
#
#      # Wait a little if a replicaset is to be handled it takes several cycles
#      # to find all servers
#      sleep 2 if $!uri-data<options><replicaSet>:exists;
#
#      $!todo-servers-semaphore.acquire;
#      $still-processing = $!processing-todo-list;
#      $!todo-servers-semaphore.release;
#
#      sleep 1 if $still-processing;
#    }
#  }

  #-----------------------------------------------------------------------------
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
    $!servers-semaphore.acquire;
    for $!servers.values.race(batch => 1) -> Hash $srv-struct {

      if $srv-struct<server>.defined {

        # Stop monitoring on server
        #
        $srv-struct<server>.stop-monitor;
        debug-message("Undefine server $srv-struct<server>.name()");
        $srv-struct<server> = Nil;
      }
    }

    $!servers-semaphore.release;
    debug-message("Client destroyed");
  }
}

