use v6;

#TODO readconcern does not have to be a BSON::Document. no encoding!

use MongoDB;
use MongoDB::Uri;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
#use MongoDB::Wire;
use MongoDB::Authenticate::Credential;
use MongoDB::ObserverEmitter;

use BSON::Document;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit class MongoDB::Client:auth<github:MARTIMM>;

# topology-set is used to block the server-select() process when topology
# still needs to be calculated.
has TopologyType $!topology-type;
#  has TopologyType $!user-request-topology;
has Bool $!topology-set;

# Store all found servers here. key is the name of the server which is
# the server address/ip and its port number. This should be unique. The
# data is a Hash of Hashes.
has Hash $!servers;

has Semaphore::ReadersWriters $!rw-sem;

has Str $!uri;
has MongoDB::Uri $.uri-obj;

has BSON::Document $.read-concern;
has Str $!Replicaset;

#  has Promise $!background-discovery;
has Bool $!repeat-discovery-loop;

# Only for single threaded implementations according to mongodb documents
# has Bool $!server-selection-try-once = False;
# has Int $!socket-check-interval-ms = 5000;

# Cleaning up is done concurrently so the test on a variable like $!servers
# to be undefined, will not work. Instead check if the below variable is True
# to see if destroying the client is started.
has Bool $!cleanup-started = False;

#-------------------------------------------------------------------------------
method new ( |c ) {

  # In case of an assignement like $c .= new(...) $c should be cleaned first
  if self.defined and not $!cleanup-started {

    warn-message('User client object still defined, will be cleaned first');
    self.cleanup;
  }

  MongoDB::Client.bless(|c);
}

#-------------------------------------------------------------------------------
#TODO pod doc arguments
submethod BUILD (
  Str:D :$uri, BSON::Document :$read-concern,
) {

  $!topology-type = TT-NotSet;
  $!topology-set = False;

  $!servers = %();

  # Initialize mutexes
  $!rw-sem .= new;
#    $!rw-sem.debug = True;

  $!rw-sem.add-mutex-names(
    <servers todo topology>, :RWPatternType(C-RW-WRITERPRIO)
  );

#TODO check version: read-concern introduced in version 3.2
  # Store read concern or initialize to default
  $!read-concern = $read-concern // BSON::Document.new: (
    mode => RCM-Primary,
#TODO  next key only when max-wire-version >= 5 ??
#      max-staleness-seconds => 90,
#      must be > C-SMALLEST-MAX-STALENEST-SECONDS
#           or > $!heartbeat-frequency-ms + $!idle-write-period-ms
    tag-sets => [BSON::Document.new(),]
  );

  # Parse the uri and get info in $!uri-obj. Fields are protocol, username,
  # password, servers, database and options.
  $!uri = $uri;
  $!uri-obj .= new(:$!uri);

  # the keyed uri is used to notify the proper client, there can be
  # more than one active
  my MongoDB::ObserverEmitter $e .= new;
  $e.subscribe-observer(
    $!uri-obj.keyed-uri ~ ' process topology',
    -> List $server-info { self!process-topology(|$server-info); },
    :event-key($!uri-obj.keyed-uri ~ ' process topology')
  );

  $e.subscribe-observer(
    $!uri-obj.keyed-uri ~ ' add servers',
    -> @new-hosts { self!add-servers(@new-hosts); },
    :event-key($!uri-obj.keyed-uri ~ ' add servers')
  );

  trace-message("Found {$!uri-obj.servers.elems} servers in uri");
  # Setup todo list with servers to be processed, Safety net not needed yet
  # because threads are not started.
  for @($!uri-obj.servers) -> Hash $server-data {
    my Str $server-name = "$server-data<host>:$server-data<port>";
    debug-message("Initialize server object for $server-name");

    # create Server object
    my MongoDB::Server $server .= new(
      :client(self), :$server-name, :$!uri-obj
    );

    # and start server monitoring
#    $server.server-init;
    #$!servers{$server-name} = $server;

    # set name same as server has made it
    $server-name = $server.name();
    $!servers{$server-name} = %(
      :server($server), :status(TT-Unknown), :!ismaster
    );
  }
} # method

#-------------------------------------------------------------------------------
method !process-topology (
  Str $server-name, ServerType $server-status, Bool $is-master
) {

  # update server data
  self!update-server( $server-name, $server-status, $is-master);
note "server info updated for $server-name with $server-status, $is-master";

  # find topology
  my TopologyType $topology = TT-Unknown;
  my Hash $servers = $!rw-sem.reader( 'servers', {$!servers.clone;});
  my Int $servers-count = 0;

  my Bool $found-standalone = False;
  my Bool $found-sharded = False;
  my Bool $found-replica = False;

  for $servers.keys -> $server-name {
    $servers-count++;

    # check status of server
    given $servers{$server-name}<status> {
      when ST-Standalone {
#        $servers-count++;

        # cannot have more than one standalone servers
        if $found-standalone or $found-sharded or $found-replica {
          $topology = TT-Unknown;
        }

        else {
          # set standalone server
          $found-standalone = True;
          $topology = TT-Single;
        }
      }

      when ST-Mongos {
#        $servers-count++;

        # cannot have other than shard servers
        if $found-standalone or $found-replica {
          $topology = TT-Unknown;
        }

        else {
          $found-sharded = True;
          $topology = TT-Sharded;
        }
      }

#TODO test same set of replicasets -> otherwise also TT-Unknown
      when ST-RSPrimary {
#        $servers-count++;

        # cannot have other than replica servers
        if $found-standalone or $found-sharded {
          $topology = TT-Unknown;
        }

        else {
          $found-replica = True;
          $topology = TT-ReplicaSetWithPrimary;
        }
      }

      when any( ST-RSSecondary, ST-RSArbiter, ST-RSOther, ST-RSGhost ) {
#        $servers-count++;

        # cannot have other than replica servers
        if $found-standalone or $found-sharded {
          $topology = TT-Unknown;
        }

        else {
          $found-replica = True;
          $topology //= TT-ReplicaSetNoPrimary;
#            unless $topology ~~ TT-ReplicaSetWithPrimary;
        }
      }
    } # given $status
  } # for $servers.keys -> $server-name

#note "process-topology: $topology";

  # One of the servers is not ready yet
  if $topology !~~ TT-NotSet {

    if $servers-count == 1 and $!uri-obj.options<replicaSet>:!exists {
      $topology = TT-Single;
    }

    $!rw-sem.writer( 'topology', {
        $!topology-type = $topology;
        $!topology-set = True;
      }
    );
  }

  info-message("Client topology is $topology");
}

#-------------------------------------------------------------------------------
method !update-server (
  Str $server-name, ServerType $server-status, Bool $is-master
) {

  $!rw-sem.writer(
    'servers', {
      $!servers{$server-name}<status> = $server-status;
      $!servers{$server-name}<ismaster> = $is-master;
    }
  );
}

#`{{
#-------------------------------------------------------------------------------
method process-topology-old ( ) {

  $!rw-sem.writer( 'topology', { $!topology-set = False; });

#TODO take user topology request into account
  # Calculate topology. Upon startup, the topology is set to
  # TT-Unknown. Here, the real value is calculated and set. Doing
  # it repeatedly it will be able to change dynamicaly.
  #
  my TopologyType $topology = TT-Unknown;
  my Hash $servers = $!rw-sem.reader( 'servers', {$!servers.clone;});
  my Int $servers-count = 0;

  my Bool $found-standalone = False;
  my Bool $found-sharded = False;
  my Bool $found-replica = False;

  for $servers.keys -> $server-name {

    my ServerType $status =
      $servers{$server-name}.get-status<status> // ST-Unknown;

    # check status of server
    given $status {
      when ST-Standalone {
        $servers-count++;
        if $found-standalone or $found-sharded or $found-replica {

          # cannot have more than one standalone servers
          $topology = TT-Unknown;
        }

        else {

          # set standalone server
          $found-standalone = True;
          $topology = TT-Single;
        }
      }

      when ST-Mongos {
        $servers-count++;
        if $found-standalone or $found-replica {

          # cannot have other than shard servers
          $topology = TT-Unknown;
        }

        else {
          $found-sharded = True;
          $topology = TT-Sharded;
        }
      }

#TODO test same set of replicasets -> otherwise also TT-Unknown
      when ST-RSPrimary {
        $servers-count++;
        if $found-standalone or $found-sharded {

          # cannot have other than replica servers
          $topology = TT-Unknown;
        }

        else {

          $found-replica = True;
          $topology = TT-ReplicaSetWithPrimary;
        }
      }

      when any( ST-RSSecondary, ST-RSArbiter, ST-RSOther, ST-RSGhost ) {
        $servers-count++;
        if $found-standalone or $found-sharded {

          # cannot have other than replica servers
          $topology = TT-Unknown;
        }

        else {

          $found-replica = True;
          $topology = TT-ReplicaSetNoPrimary
            unless $topology ~~ TT-ReplicaSetWithPrimary;
        }
      }
    } # given $status
  } # for $servers.keys -> $server-name

  # One of the servers is not ready yet
  if $topology !~~ TT-NotSet {

    if $servers-count == 1 and $!uri-obj.options<replicaSet>:!exists {
      $topology = TT-Single;
    }

    $!rw-sem.writer( 'topology', {
        $!topology-type = $topology;
        $!topology-set = True;
      }
    );
  }

  info-message("Client topology is $topology");
}
}}

#-------------------------------------------------------------------------------
# Return number of servers
method nbr-servers ( --> Int ) {

  $!rw-sem.reader( 'servers', {$!servers.elems;});
}

#-------------------------------------------------------------------------------
# Get the server status
method server-status ( Str:D $server-name --> ServerType ) {

  #! Wait until topology is set
  until $!rw-sem.reader( 'topology', { $!topology-set }) {
    sleep 0.5;
  }

  my Hash $h = $!rw-sem.reader(
    'servers', {
    my $x = $!servers{$server-name}:exists
            ?? $!servers{$server-name}<server>.get-status
            !! {};
    $x;
  });

  my ServerType $sts = $h<status> // ST-Unknown;
#    debug-message("server-status: '$server-name', $sts");
  $sts;
}

#-------------------------------------------------------------------------------
method topology ( --> TopologyType ) {

  #! Wait until topology is set
  until $!rw-sem.reader( 'topology', { $!topology-set }) {
    sleep 0.5;
  }

  $!rw-sem.reader( 'topology', {$!topology-type});
}

#-------------------------------------------------------------------------------
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
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Request specific servername
multi method select-server ( Str:D :$servername! --> MongoDB::Server ) {

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  my MongoDB::Server $selected-server;

  # find suitable servers by topology type and operation type
  repeat {

    #! Wait until topology is set
    until $!rw-sem.reader( 'topology', { $!topology-set }) {
      sleep 0.5;
    }

    $selected-server = $!rw-sem.reader( 'servers', {
note "ss0 Servers: ", $!servers.keys;
note "ss0 Request: $selected-server.name()";
        $!servers{$servername}:exists
                ?? $!servers{$servername}<server>
                !! MongoDB::Server;
      }
    );

    last if ? $selected-server;
    sleep $!uri-obj.options<heartbeatFrequencyMS> / 1000.0;
  } while ((now - $t0) * 1000) < $!uri-obj.options<serverSelectionTimeoutMS>;

  debug-message("Searched for {(now - $t0) * 1000} ms");

  if ?$selected-server {
    debug-message("Server '$selected-server.name()' selected");
  }

  else {
    warn-message("No suitable server selected");
  }

  $selected-server;
}


#TODO pod doc
#TODO use read/write concern for selection
#TODO must break loop when nothing is found

#-------------------------------------------------------------------------------
# Read/write concern selection
multi method select-server (
  BSON::Document :$read-concern is copy
  --> MongoDB::Server
) {

  $read-concern //= $!read-concern;
  my MongoDB::Server $selected-server;

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  #! Wait until topology is set
  until $!rw-sem.reader( 'topology', { $!topology-set }) {
note 'wait 0.5';
    sleep 0.5;
  }

  # find suitable servers by topology type and operation type
  repeat {

    my MongoDB::Server @selected-servers = ();
    my Hash $servers = $!rw-sem.reader( 'servers', {$!servers.clone});
    my TopologyType $topology = $!rw-sem.reader( 'topology', {$!topology-type});

note "ss1 Servers: ", $servers.keys;
note "ss1 Topology: $topology";

    given $topology {
      when TT-Single {

        for $servers.keys -> $sname {
          $selected-server = $servers{$sname}<server>;
          my Hash $sdata = $selected-server.get-status;
          last if $sdata<status> ~~ ST-Standalone;
        }
      }

      when TT-ReplicaSetWithPrimary {

#TODO read concern
#TODO check replica set option in uri
        for $servers.keys -> $sname {
          $selected-server = $servers{$sname}<server>;
          my Hash $sdata = $selected-server.get-status;
          last if $sdata<status> ~~ ST-RSPrimary;
        }
      }

      when TT-ReplicaSetNoPrimary {

#TODO read concern
#TODO check replica set option in uri if ST-RSSecondary
        for $servers.keys -> $sname {
          my $s = $servers{$sname}<server>;
          my Hash $sdata = $s.get-status;
          @selected-servers.push: $s if $sdata<status> ~~ ST-RSSecondary;
        }
      }

      when TT-Sharded {

        for $servers.keys -> $sname {
          my $s = $servers{$sname}<server>;
          my Hash $sdata = $s.get-status;
          @selected-servers.push: $s if $sdata<status> ~~ ST-Mongos;
        }
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
          $slctd-svrs.push: $svr
            if $svr-sts<weighted-mean-rtt-ms> <= (
              $min-rtt-ms + $!uri-obj.options<localThresholdMS>
            );
        }

        $selected-server = $slctd-svrs.pick;
      }
    }

    # done when a suitable server is found
    last if $selected-server.defined;

    # else wait for status and topology updates
#TODO synchronize with monitor times
    sleep $!uri-obj.options<heartbeatFrequencyMS> / 1000.0;

  } while ((now - $t0) * 1000) < $!uri-obj.options<serverSelectionTimeoutMS>;

  debug-message("Searched for {(now - $t0) * 1000} ms");

  if ?$selected-server {
    debug-message("Server '$selected-server.name()' selected");
  }

  else {
    warn-message("No suitable server selected");
  }

  $selected-server;
}

#-------------------------------------------------------------------------------
# Add server to todo list.
method !add-servers ( @new-hosts ) {

  trace-message("push @new-hosts[*] on todo list");

  for @new-hosts -> Str $server-name is copy {

    debug-message("Initialize server object for $server-name");

    # create Server object
    my MongoDB::Server $server .= new(
      :client(self), :$server-name, :$!uri-obj
    );

    # and start server monitoring
#    $server.server-init;
    #$!servers{$server-name} = $server;

    # set name same as server has made it
    $server-name = $server.name();
    $!servers{$server-name} = %(
      :server($server), :status(TT-Unknown), :!ismaster
    );
  }
}

#-------------------------------------------------------------------------------
method database (
  Str:D $name, BSON::Document :$read-concern
  --> MongoDB::Database
) {

  my BSON::Document $rc =
     $read-concern.defined ?? $read-concern !! $!read-concern;

  MongoDB::Database.new( :client(self), :name($name), :read-concern($rc));
}

#-------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------
# Forced cleanup
#
# cleanup cannot be done in separate thread because everything must be cleaned
# up before other tasks are performed. the client inserts new data while
# removing them here. the last subtest of 110-client failed because of this.
method cleanup ( ) {

  $!cleanup-started = True;

  # some timing to see if this cleanup can be improved
  my Instant $t0 = now;

  # stop loop and wait for exit
  if $!repeat-discovery-loop {
    $!repeat-discovery-loop = False;
#      $!background-discovery.result;
  }

  # Remove all servers concurrently. Shouldn't be many per client.
  $!rw-sem.writer(
    'servers', {

      for $!servers.values -> Hash $server-info {
        my MongoDB::Server $server = $server-info<server>;
        if $server.defined {
          # Stop monitoring on server
          $server.cleanup;
          debug-message(
            "server '$server.name()' destroyed after {(now - $t0)} sec"
          );
        }
      }
    }
  );

  # unsubscribe observers
  my MongoDB::ObserverEmitter $e .= new;
  $e.unsubscribe-observer($!uri-obj.keyed-uri ~ ' process topology');
  $e.unsubscribe-observer($!uri-obj.keyed-uri ~ ' add servers');

  $!servers = Nil;
  $!rw-sem.rm-mutex-names(<servers todo topology>);
  debug-message("Client destroyed after {(now - $t0)} sec");
}
