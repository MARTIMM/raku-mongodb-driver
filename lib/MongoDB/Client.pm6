
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
  has Bool $!processing-todo-list;
  has Semaphore $!todo-servers-semaphore;

  has Str $!master-servername;
  has Semaphore $!servername-semaphore;

  has Str $!uri;

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
    $!processing-todo-list = True;
    $!todo-servers-semaphore .= new(1);

    $!master-servername = Nil;
    $!servername-semaphore .= new(1);

    # Store read concern
    #
    $!read-concern =
      $read-concern.defined ?? $read-concern !! BSON::Document.new;

    # Parse the uri and get info in $uri-obj. Fields are protocol, username,
    # password, servers, database and options.
    #
    $!uri = $uri;

    # Copy some fields into $uri-data hash which is handed over
    # to the server object..
    #
    my @item-list = <username password database options>;
    my MongoDB::Uri $uri-obj .= new(:$!uri);
    my Hash $uri-data = %(@item-list Z=> $uri-obj.server-data{@item-list});

    debug-message("Found {$uri-obj.server-data<servers>.elems} servers in uri");

    # Setup todo list with servers to be processed
#    $!todo-servers-semaphore.acquire;
    for @($uri-obj.server-data<servers>) -> Hash $server-data {
      $!todo-servers.push("$server-data<host>:$server-data<port>");
    }
#    $!todo-servers-semaphore.release;


    # Background proces to handle server monitoring data
    $!Background-discovery = Promise.start( {

        loop {
          # This reading of the todo list might start too quick, reading before
          # anything is pushed onto the list by the main thread. Then
          # $!processing-todo-list togles to False which then produces failures
          # later when select-server or nbr-servers is called.
          #
          sleep 1;

          # Start processing when something is found in todo hash
          $!todo-servers-semaphore.acquire;
          my Str $server-name = $!todo-servers.shift if $!todo-servers.elems;
          $!todo-servers-semaphore.release;

          if $server-name.defined {

            trace-message("Processing server $server-name");

#say "a0: $server-name: $!processing-todo-list";
            $!servers-semaphore.acquire;
#say "a1: $server-name";
            my Bool $server-processed = $!servers{$server-name}:exists;
            $!servers-semaphore.release;

            # Check if server was managed before
            if $server-processed {
              trace-message("Server $server-name already managed");
              next;
            }

#say "a2: $server-name";
            my MongoDB::Server $server .= new(
              :$server-name, :$uri-data, :$loop-time
            );
#say "a3a: $server-name";

            # Start server monitoring process its data
            $server.server-init();
            self!process-monitor-data($server);
          }

          else {

            # When there is no work take a nap!
            # This sleeping period is the moment we do not process the todo list
            $!todo-servers-semaphore.acquire;
            $!processing-todo-list = False;
            $!todo-servers-semaphore.release;

            sleep 5;

            $!todo-servers-semaphore.acquire;
            $!processing-todo-list = True;
            $!todo-servers-semaphore.release;
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

        my Bool $found-new-servers = False;
#say "Monitor $server.name(): $monitor-data<ok>" if $monitor-data.defined;
#say "Monitor $server.name(): ", $monitor-data.perl if $monitor-data.defined;

        $!servers-semaphore.acquire;
        my Hash $prev-server = $!servers{$server-name}:exists
                       ?? $!servers{$server-name}
                       !! Nil;
        $!servers-semaphore.release;

        $!servername-semaphore.acquire;
        my $sname = $!master-servername;
        $!servername-semaphore.release;

        my Hash $h = {
          server => $server,
          status => $server.get-status,
          timestamp => now,
          server-data => $monitor-data // {}
        };

        # Only when data is ok
        if not $monitor-data.defined {

          error-message("No monitor data received");
        }

        # There are errors while monitoring
        elsif not $monitor-data<ok> {

          # Not found by DNS so big chance that it doesn't exist
          if $h<status> ~~ MongoDB::C-NON-EXISTENT-SERVER {

            $server.stop-monitor;
            error-message("Stopping monitor: $monitor-data<reason>");
          }

          # Connection failure
          elsif $h<status> ~~ MongoDB::C-DOWN-SERVER {

            # Check if the master server went down
            if $sname.defined and ($sname eq $server.name) {

#say "H1: $h<status>, ", $sname // '-', ', ', $server.name;
              $!servername-semaphore.acquire;
              $!master-servername = Nil;
              $!servername-semaphore.release;
            }

            warn-message("Server is down: $monitor-data<reason>");
          }
        }


        # Monitoring data is ok
        else {

#say 'Master server name: ', $sname // '-';
#say 'Master prev stat: ', $prev-server<status>:exists 
#                  ?? $prev-server<status>
#                  !! '-';

          # Don't ever modify a rejected server
          if $prev-server<status>:exists
             and $prev-server<status> ~~ MongoDB::C-REJECTED-SERVER {

#say "H0: $h<status>, ", $sname // '-', ', ', $server.name;
            $h<status> = MongoDB::C-REJECTED-SERVER;
          }

#`{{
          # Check if the master server went down
          elsif $h<status> ~~ MongoDB::C-DOWN-SERVER 
                and $sname eq $server.name {

#say "H1: $h<status>, ", $sname // '-', ', ', $server.name;
            $!servername-semaphore.acquire;
            $!master-servername = Nil;
            $!servername-semaphore.release;
          }
}}

          # Check for double master servers
          elsif $h<status> ~~ any(
            MongoDB::C-MASTER-SERVER |
            MongoDB::C-REPLICASET-PRIMARY
          ) {
#say "H2: $h<status>, ", $sname // '-', ', ', $server.name;
            # Is defined, be the second and rejected master server
            if $sname.defined {
              if $sname ne $server.name {
                $h<status> = MongoDB::C-REJECTED-SERVER;
                error-message("Server $server.name() rejected, second master");
              }
            }

            # Not defined, be the first master server
            else {
#say "H3: $h<status>, ", $sname // '-', ', ', $server.name;
              $!servername-semaphore.acquire;
              $!master-servername = $server.name;
              $!servername-semaphore.release;
            }
          }

          else {

#say "H4: $h<status>, ", $sname // '-', ', ', $server.name;
          }

          # When primary, find all servers and process them
          if $h<status> ~~ MongoDB::C-REPLICASET-PRIMARY {

#say "H5: $h<server-data>.perl()";
            my Array $hosts = $h<server-data><monitor><hosts>;
#say "H6a: $hosts";
            for @$hosts -> $hostspec {
              $!servers-semaphore.acquire;
              my Bool $processed = $!servers{$hostspec}:exists;
              $!servers-semaphore.release;

#say "H6b: $hostspec, $processed";
              next if $processed;

              $!todo-servers-semaphore.acquire;
              $!todo-servers.push($hostspec);
              $found-new-servers = True;
              $!todo-servers-semaphore.release;
            }
          }

          # When secondary get its primary and process if not yet found
          elsif $h<status> ~~ MongoDB::C-REPLICASET-SECONDARY {

            # Error when current master is not same as primary
            my $primary = $h<server-data><monitor><primary>;
#say "H6c: $primary, ", $sname // '-';
            if $sname.defined and $sname ne $primary {
              error-message(
                "Server $primary found but != current master $sname"
              );
            }

            # When defined w've already processed it, if not, go for it
            elsif not $sname.defined {
#say "H6d: $primary";
              $!todo-servers-semaphore.acquire;
              $!todo-servers.push($primary);
              $found-new-servers = True;
              $!todo-servers-semaphore.release;
#say "H6e";
            }
          }

#TODO $!master-servername must be able to change when server roles are changed
#TODO Define client topology
        }

        # Store result
        $!servers-semaphore.acquire;
        $!servers{$server.name} = $h;
#say "Saved monitor data for $server.name() = ", $!servers{$server.name}.perl;
        $!servers-semaphore.release;

        # Make a note if more servers are to be processed
# Not necessary to do that here because the list is processed before setting
# the boolean
#        $!todo-servers-semaphore.acquire;
#        $!processing-todo-list = $found-new-servers;
#        $!todo-servers-semaphore.release;
#say "H6f: Processing after $server.name(): $!processing-todo-list";
#say "\nWait for next from monitor";
#say ' ';
      }
    );
  }

  #-----------------------------------------------------------------------------
  # Return number of servers
  method nbr-servers ( --> Int ) {

    self!check-discovery-process;

    my Bool $still-processing = True;
    while $still-processing {
      $!todo-servers-semaphore.acquire;
      $still-processing = $!processing-todo-list;
      $!todo-servers-semaphore.release;
#say "nbr-servers, still processing: $still-processing";
      sleep 1;
    }

    $!servers-semaphore.acquire;
    my $nservers = $!servers.elems;
    $!servers-semaphore.release;

    $nservers;
  }

  #-----------------------------------------------------------------------------
  # Called from thread above where Server object is created.
  method server-status ( Str:D $server-name --> MongoDB::ServerStatus ) {

    self!check-discovery-process;
    self!check-todo-process;

    $!servers-semaphore.acquire;
    my Hash $h = $!servers{$server-name}:exists
                 ?? $!servers{$server-name}
                 !! {};
    $!servers-semaphore.release;

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
    MongoDB::ServerStatus:D :$needed-state!
    --> MongoDB::Server
  ) {

    self!check-discovery-process;
    self!check-todo-process;

#    my Bool $still-processing = True;
#    while $still-processing {
#      $!todo-servers-semaphore.acquire;
#      $still-processing = $!processing-todo-list;
#      $!todo-servers-semaphore.release;
#say "select-server 2, still processing: $still-processing";
#      sleep 1;
#    }

#    my Int $test-count = 12;
    my Hash $h;

#    whileLoopLabel: while $test-count-- {

      $!servers-semaphore.acquire;
      my @server-names = $!servers.keys;
      $!servers-semaphore.release;

      for @server-names -> $sname {
        $!servers-semaphore.acquire;
        my Hash $shash = $!servers{$sname};
        $!servers-semaphore.release;

        if $shash<status> ~~ $needed-state {
          $h = $shash;
          last;
#          last whileLoopLabel;
        }
      }

#      sleep 1;
#    }

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
  multi method select-server ( --> MongoDB::Server ) {

    self!check-discovery-process;
    self!check-todo-process;

#    my Bool $still-processing = True;
#    while $still-processing {
#      $!todo-servers-semaphore.acquire;
#      $still-processing = $!processing-todo-list;
#      $!todo-servers-semaphore.release;
#say "select-server 3, still processing: $still-processing";
#      sleep 1;
#    }

#    my Int $test-count = 12;
    my Hash $h;
    my Str $msname;

#    while $test-count-- {

      $!servername-semaphore.acquire;
      $msname = $!master-servername;
      $!servername-semaphore.release;

      if $msname.defined {
        $!servers-semaphore.acquire;
        $h = $!servers{$msname};
        $!servers-semaphore.release;
#        last;
      }
#
#      sleep 1;
#    }

    if ?$msname {
      info-message("Master server $msname selected");
    }

    else {
      error-message('No master server selected');
    }
#say 'Select server: ', ($h // {}).perl;
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
  method !check-todo-process ( ) {

    my Bool $still-processing = True;
    while $still-processing {
      $!todo-servers-semaphore.acquire;
      $still-processing = $!processing-todo-list;
      $!todo-servers-semaphore.release;
#say "select-server 2, still processing: $still-processing";
      sleep 1;
    }
  }

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

