use v6.c;

#TODO readconcern does not have to be a BSON::Document. no encoding!

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

  # https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#mongoclient-configuration
  has Int $!local-threshold-ms;
  has Int $!server-selection-timeout-ms;
  has Int $!heartbeat-frequency-ms;
  has Int $!idle-write-period-ms;
  constant smallest-max-staleness-seconds = 90;

  # Only for single threaded implementations
  # has Bool $!server-selection-try-once = False;
  # has Int $!socket-check-interval-ms = 5000;

  #-----------------------------------------------------------------------------
  method new ( |c ) {

    # In case of an assignement like $c .= new(...) $c should be cleaned first
    if self.defined and $!servers.defined {
      warn-message('User client object still defined, will be cleaned first');
      self.cleanup;
      sleep 0.5;
    }

    MongoDB::Client.bless(|c);
  }

  #-----------------------------------------------------------------------------
#TODO pod doc arguments
  submethod BUILD (
    Str:D :$uri, BSON::Document :$read-concern,
    TopologyType :$topology-type = TT-Unknown,
    Int :$local-threshold-ms = 100,
    Int :$server-selection-timeout-ms = 30000,
    Int :$heartbeat-frequency-ms = 10000,
    Int :$idle-write-period-ms = 10000,
  ) {

#TODO some or all are also settable in uri
    $!user-request-topology = $topology-type;
    $!topology-type = TT-Unknown;

    $!server-selection-timeout-ms = $server-selection-timeout-ms;
    $!local-threshold-ms = $local-threshold-ms;
    $!heartbeat-frequency-ms = $heartbeat-frequency-ms;
    $!idle-write-period-ms = $idle-write-period-ms;

    $!servers = {};
    $!todo-servers = [];

    # Initialize mutexes
    $!rw-sem .= new;
#    $!rw-sem.debug = True;

    $!rw-sem.add-mutex-names(
      <servers todo topology>,
      :RWPatternType(C-RW-WRITERPRIO)
    ) unless $!rw-sem.check-mutex-names(<servers todo master>);

#TODO check version: read-concern introduced in version 3.2
    # Store read concern or initialize to default
    $!read-concern = $read-concern // BSON::Document.new: (
      mode => RCM-Primary,
#TODO  next key only when max-wire-version >= 5 ??
#      max-staleness-seconds => 90,
#      must be > smallest-max-staleness-seconds
#           or > $!heartbeat-frequency-ms + $!idle-write-period-ms
      tag-sets => [BSON::Document.new(),]
    );

    # Parse the uri and get info in $uri-obj. Fields are protocol, username,
    # password, servers, database and options.
    $!uri = $uri;

    # Copy some fields into $!uri-data hash which is handed over
    # to the server object..
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
            $server.server-init($!heartbeat-frequency-ms);

#TODO symplify to value instead of Hash
            $!rw-sem.writer( 'servers', {$!servers{$server-name} = $server;});

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

          my ServerStatus $status = $servers{$server-name}.get-status<status> // SS-Unknown;

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
              ?? $!servers{$server-name}.get-status
              !! {};
      $x;
    });

    my ServerStatus $sts = $h<status> // SS-Unknown;
    debug-message("server-status: '$server-name', $sts");
    $sts;
  }

  #-----------------------------------------------------------------------------
  method topology ( --> TopologyType ) {

    $!rw-sem.reader( 'topology', {$!topology-type});
  }

  #-----------------------------------------------------------------------------
  # Selecting servers based on;
  #
  # - Record the server selection start time
  # - If the topology wire version is invalid, raise an error
  # - Find suitable servers by topology type and operation type
  # - If there are any suitable servers, choose one at random from those within
  #   the latency window and return it; otherwise, continue to step #5
  # - Request an immediate topology check, then block the server selection
  #   thread until the topology changes or until the server selection timeout
  #   has elapsed
  # - If more than serverSelectionTimeoutMS milliseconds have elapsed since the
  #   selection start time, raise a server selection error
  # - Goto Step #2
  #-----------------------------------------------------------------------------

#TODO pod doc
#TODO use read/write concern for selection
#TODO must break loop when nothing is found

  # Read/write concern selection
  multi method select-server (
    BSON::Document :$read-concern is copy
    --> MongoDB::Server
  ) {

    $read-concern //= $!read-concern;
    my Hash $servers = $!rw-sem.reader( 'servers', {$!servers.clone});
    my TopologyType $topology = $!rw-sem.reader( 'topology', {$!topology-type});
    my MongoDB::Server $selected-server;
    my MongoDB::Server @selected-servers = ();

    # record the server selection start time
    my Instant $t0 = now;

    # find suitable servers by topology type and operation type
    repeat {

      if $topology ~~ TT-Single {

        for $servers.keys -> $sname {
          $selected-server = $servers{$sname};
          my Hash $sdata = $selected-server.get-status;
          last if $sdata<status> ~~ SS-Standalone;
        }
      }

      elsif $topology ~~ TT-ReplicaSetWithPrimary {

        for $servers.keys -> $sname {
          $selected-server = $servers{$sname};
          my Hash $sdata = $selected-server.get-status;
          last if $sdata<status> ~~ SS-RSPrimary;
        }
      }

      elsif $topology ~~ TT-ReplicaSetNoPrimary {

        for $servers.keys -> $sname {
          my $s = $servers{$sname};
          my Hash $sdata = $s.get-status;
          @selected-servers.push: $s if $sdata<status> ~~ SS-RSSecondary;
        }
      }

      elsif $topology ~~ TT-Sharded {

        for $servers.keys -> $sname {
          my $s = $servers{$sname};
          my Hash $sdata = $s.get-status;
          @selected-servers.push: $s if $sdata<status> ~~ SS-Mongos;
        }
      }

      # if no server selected but there are some in the array
      if !$selected-server and +@selected-servers {

        # if only one server in array, take that one
        if @selected-servers.elems == 1 {
          $selected-server = @selected-servers.pop;
        }

        # now w're getting complex because we need to select from a number
        # of suitable servers.
        else {

          my Array $slctd-svrs = [];
          my Duration $min-rtt-ms .= new(1_000_000_000);

          # get minimum rtt from server measurements
          for @selected-servers -> MongoDB::Server $svr {
            my Hash $svr-sts = $svr.get-status;
            $min-rtt-ms = $svr-sts<weighted-mean-rtt-ms>
              if $min-rtt-ms > $svr-sts<weighted-mean-rtt-ms>;
          }

          # select those servers falling in the window defined by the
          # minimum round trip time and minimum rtt plus a treshold
          for @selected-servers -> $svr {
            my Hash $svr-sts = $svr.get-status;
            $slctd-svrs.push: $svr if $svr-sts<weighted-mean-rtt-ms>
                                      <= ($min-rtt-ms + $!local-threshold-ms);
          }

          $selected-server = $slctd-svrs.pick;
        }
      }

      # done when a suitable server is found
      last if $selected-server.defined;

      # else wait for status and topology updates
#TODO synchronize with monitor times
      sleep $!heartbeat-frequency-ms/1000.0;

note "diff {(now - $t0) * 1000}";
    } while ((now - $t0) * 1000) < $!server-selection-timeout-ms;

    error-message("No suitable server selected") unless ?$selected-server;
    $selected-server;
  }

#`{{
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

    if $h.defined {
      info-message("Server $h.name() selected");
    }

    else {
      error-message('No typed server selected');
    }

    $h // MongoDB::Server;
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

    $h // MongoDB::Server;
  }
}}

  #-----------------------------------------------------------------------------
  # Request specific servername
  multi method select-server ( Str:D :$servername! --> MongoDB::Server ) {

    self!check-discovery-process;

    my Hash $h = $!rw-sem.reader( 'servers', { $!servers{$servername} // {}; });
    $h // MongoDB::Server;
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

    # some timing to see if this cleanup can be improved
    my Instant $t0 = now;

    # stop loop and wait for exit
    $!repeat-discovery-loop = False;
    $!Background-discovery.result;

    # Remove all servers concurrently. Shouldn't be many per client.
    $!rw-sem.writer(
      'servers', {

        for $!servers.values -> MongoDB::Server $server {
          if $server.defined {
            # Stop monitoring on server
            $server.cleanup;
            debug-message("server '$server.name()' cleaned after {now - $t0}");
          }
        }
      }
    );

    $!servers = Nil;
    $!todo-servers = Nil;

    debug-message("Client destroyed after {now - $t0}");
  }
}

