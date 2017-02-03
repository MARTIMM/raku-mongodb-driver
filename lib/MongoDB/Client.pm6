use v6.c;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

use MongoDB;
use MongoDB::Uri;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Wire;
use MongoDB::Authenticate::Credential;

use BSON::Document;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
class Client {

  has TopologyType $!topology-type;
  has TopologyType $!user-request-topology;

  # Store all found servers here. key is the name of the server which is
  # the server address/ip and its port number. This should be unique.
  #
  has Hash $!servers;
  has Array $!todo-servers;

  has Semaphore::ReadersWriters $!rw-sem;

  has Str $!uri;
  has Hash $.uri-data;

  has BSON::Document $.read-concern;
  has Str $!Replicaset;

  has Promise $!Background-discovery;
  has Bool $!repeat-discovery-loop;

  # https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst#client-implementation
  has MongoDB::Authenticate::Credential $.credential;

  #-----------------------------------------------------------------------------
  method new ( |c ) {

    # In case of an assignement like $c .= new(...) $c should be cleaned first
    if self.defined and $!servers.defined {
      warn-message('User client object still defined, will be cleaned first');
      self.cleanup;
    }

    MongoDB::Client.bless(|c);
  }

  #-----------------------------------------------------------------------------
  submethod BUILD (
    Str:D :$uri, BSON::Document :$read-concern,
    TopologyType :$topology-type = TT-Unknown
  ) {

    $!user-request-topology = $topology-type;
    $!topology-type = TT-Unknown;

    $!servers = {};
    $!todo-servers = [];

    # Initialize mutexes
    $!rw-sem .= new;
#    $!rw-sem.debug = True;

    $!rw-sem.add-mutex-names(
      <servers todo topology>,
      :RWPatternType(C-RW-WRITERPRIO)
    ) unless $!rw-sem.check-mutex-names(<servers todo master>);

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

    my %cred-data = %();
    my $set = sub ( *@k ) {
      my $sk = shift @k;
      for @k -> $rk {
        return if %cred-data{$sk};
        %cred-data{$sk} = $uri-obj.server-data{$rk}
          if ? $rk and ? $uri-obj.server-data{$rk};
      }
    };

    $set( 'username',                   'username');
    $set( 'password',                   'password');
    $set( 'auth-source',                'database', 'authSource', 'admin');
    $set( 'auth-mechanism',             'authMechanism');
    $set( 'auth-mechanism-properties',  'authMechanismProperties');
    $!credential .= new(|%cred-data);

    debug-message("Found {$uri-obj.server-data<servers>.elems} servers in uri");

    # Setup todo list with servers to be processed, Safety net not needed yet
    # because threads are not started.
    for @($uri-obj.server-data<servers>) -> Hash $server-data {
      debug-message("todo: $server-data<host>:$server-data<port>");
      $!todo-servers.push("$server-data<host>:$server-data<port>");
    }

    # Background proces to handle server monitoring data
    $!Background-discovery = Promise.start( {

        $!repeat-discovery-loop = True;
        repeat {

          # Start processing when something is found in todo hash
          my Str $server-name = $!rw-sem.writer(
            'todo', {
              ($!todo-servers.shift if $!todo-servers.elems) // Str;
            }
          );

          if $server-name.defined {

            trace-message("Processing server $server-name");
            my Bool $server-processed = $!rw-sem.reader(
              'servers', { $!servers{$server-name}:exists; }
            );

            # Check if server was managed before
            if $server-processed {
              trace-message("Server $server-name already managed");
              next;
            }

            # Create Server object
            my MongoDB::Server $server .= new( :client(self), :$server-name);

            # And start server monitoring
            $server.server-init;

#TODO symplify to value instead of Hash
            $!rw-sem.writer(
              'servers', { $!servers{$server-name} = { server => $server, } }
            );

            self!process-topology;
          }

          else {

            # When there is no work take a nap! This sleeping period is the
            # moment we do not process the todo list
            sleep 1;
          }

          CATCH {
            default {
               # Keep this .note in. It helps debugging when an error takes place
               # The error will not be seen before the result of Promise is read
               .note;
               .rethrow;
            }
          }

        } while $!repeat-discovery-loop;

        debug-message("server discovery loop stopped");
      }
    );
  }

  #-----------------------------------------------------------------------------
  method !process-topology ( ) {

note "process topology";
    $!rw-sem.writer( 'topology', {

    #TODO take user topology request into account
        # Calculate topology. Upon startup, the topology is set to
        # TT-Unknown. Here, the real value is calculated and set. Doing
        # it repeatedly it will be able to change dynamicaly.
        #
        my $topology = TT-Unknown;
        my Hash $servers = $!rw-sem.reader( 'servers', {$!servers.clone;});

        my Bool $found-standalone = False;
        my Bool $found-sharded = False;
        my Bool $found-replica = False;

        for $servers.keys -> $server-name {

          my ServerStatus $status = $servers{$server-name}<server>.get-status<status> // SS-Unknown;
note "server status of $server-name is $status";

          if $status ~~ SS-Standalone {
            if $found-standalone or $found-sharded or $found-replica {

              # cannot have more than one standalone servers
              $topology = TT-Unknown;
            }

            else {

              $found-standalone = True;
              $topology = TT-Single;
            }
          }

          elsif $status ~~ SS-Mongos {
            if $found-standalone or $found-replica {

              # cannot have other than shard servers
              $topology = TT-Unknown;
            }

            else {
              $found-sharded = True;
              $topology = TT-Sharded;
            }
          }

          elsif $status ~~ SS-RSPrimary {
            if $found-standalone or $found-sharded {

              # cannot have other than replica servers
              $topology = TT-Unknown;
            }

            else {

              $found-replica = True;
              $topology = TT-ReplicaSetWithPrimary;
            }
          }

          elsif $status ~~ any(
            SS-RSSecondary, SS-RSArbiter, SS-RSOther, SS-RSGhost
          ) {
            if $found-standalone or $found-sharded {

              # cannot have other than replica servers
              $topology = TT-Unknown;
            }

            else {

              $found-replica = True;
              $topology = TT-ReplicaSetNoPrimary;
            }
          }
        }

        debug-message("topology type set to $topology");
        $!topology-type = $topology;
      }
    );
  }

  #-----------------------------------------------------------------------------
  # Return number of servers
  method nbr-servers ( --> Int ) {

    self!check-discovery-process;
    $!rw-sem.reader( 'servers', {$!servers.elems;});
  }

  #-----------------------------------------------------------------------------
  # Called from thread above where Server object is created.
  method server-status ( Str:D $server-name --> ServerStatus ) {

    self!check-discovery-process;

    my Hash $h = $!rw-sem.reader(
      'servers', {
      my $x = $!servers{$server-name}:exists
              ?? $!servers{$server-name}<server>.get-status
              !! {};
      $x;
    });

    my ServerStatus $sts = $h<status> // SS-Unknown;
    debug-message("server-status: '$server-name', $sts");
    $sts
  }

  #-----------------------------------------------------------------------------
  method topology ( --> TopologyType ) {

    $!rw-sem.reader( 'topology', {$!topology-type});
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
    ServerStatus:D :$needed-state!,
    Int :$check-cycles is copy = -1
    --> MongoDB::Server
  ) {

#note "$*THREAD.id() select-server";
    self!check-discovery-process;
#note "$*THREAD.id() select-server check done";

    my Hash $h;
    repeat {

      # Take this into the loop because array can still change, might even
      # be empty when hastely called right after new()
      my Array $server-names = $!rw-sem.reader(
        'servers', {
           [$!servers.keys];
         }
       );
#note "$*THREAD.id() select-server {@$server-names}";
      for @$server-names -> $msname {
        my Hash $shash = $!rw-sem.reader(
          'servers', {
#note "$*THREAD.id() select-server :needed-state, {$msname//'-'}";
            my Hash $h;
            if $!servers{$msname}.defined {
#note "$*THREAD.id() select-server :needed-state, $!servers{$msname}<status>";
              $h = $!servers{$msname};
            }

            $h;
          }
        );

        $h = $shash if $shash<status> == $needed-state;
      }

      $check-cycles--;
      sleep 1;
    } while $h.defined or $check-cycles != 0;

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

    my Hash $h;
    my Str $msname;

    # When $check-cycles in not set it will be -1, therefore $check-cycles
    # will not reach 0 and loop becomes infinite.
    while $check-cycles != 0 {

      if $msname.defined {
        $h = $!rw-sem.reader( 'servers', {$!servers{$msname};});
        last;
      }

      $check-cycles--;
      sleep(1.5);
    }

    $h<server> // MongoDB::Server;
  }

  #-----------------------------------------------------------------------------
  # Add server to todo list.
  method add-servers ( Array $hostspecs ) {

    debug-message("push $hostspecs[*] on todo list");
    $!rw-sem.writer( 'todo', { $!todo-servers.append: |$hostspecs; });
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
  method database (
    Str:D $name, BSON::Document :$read-concern
    --> MongoDB::Database
  ) {

    my BSON::Document $rc =
       $read-concern.defined ?? $read-concern !! $!read-concern;

    MongoDB::Database.new( :client(self), :name($name), :read-concern($rc));
  }

  #-----------------------------------------------------------------------------
  method collection (
    Str:D $full-collection-name, BSON::Document :$read-concern
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
  # Forced cleanup
  method cleanup ( ) {

    # stop loop and wait for exit
    $!repeat-discovery-loop = False;
    $!Background-discovery.result;

    # Remove all servers concurrently. Shouldn't be many per client.
    $!rw-sem.writer(
      'servers', {

        for $!servers.values -> Hash $srv-struct {
          if $srv-struct<server>.defined {
            # Stop monitoring on server
            debug-message("cleanup server '$srv-struct<server>.name()'");
            $srv-struct<server>.cleanup;
            $srv-struct<server> = Nil;
          }
        }
      }
    );

    $!servers = Nil;
    $!todo-servers = Nil;

    debug-message("Client destroyed");
  }
}

