#TL:1:MongoDB::Client

use v6.d;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::Client

Class to define connections to servers

=head1 Description

This class is your most often used class. It maintains the connection to the servers specified in the given uri. In the background it starts a monitor (only once) and manage the server pool.

The options which can be used in the uri are in the following tables. See also L<this information|https://docs.mongodb.com/manual/reference/connection-string/#connection-string-options> for more details.


=head1 Synopsis
=head2 Declaration

  unit class MongoDB::Client;


=head2 Uml Diagram

![](images/Client.svg)


=head1 See Also

=item MongoDB::Uri; For Uri handling.
=item MongoDB::Database; Accessing the database using C<.run-command()>.
=item MongoDB::Collection; Less often used to use the C<.find()> method on a collection.


=head1 Example

  my MongoDB::Client $client .= new(:uri<mongodb://>);
  my MongoDB::Database $people-db = $client.database('people');

  my BSON::Document $request .= new: (
    insert => 'famous-people',
    documents => [ (
        name => 'Larry',
        surname => 'Wall',
      ),
    ]
  );

  my BSON::Document $doc = $people-db.run-command($request);
  say $doc<ok> ?? 'insert request ok' !! 'failed to insert';

=end pod

#-------------------------------------------------------------------------------
use MongoDB;
use MongoDB::Uri;
use MongoDB::ServerPool::Server;
use MongoDB::ServerPool;
use MongoDB::Server::Monitor;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::ObserverEmitter;

use BSON::Document;
use Semaphore::ReadersWriters;

INIT {
  # start monitoring in a separate thread as early as possible
  MongoDB::Server::Monitor.instance;
}

#-------------------------------------------------------------------------------
unit class MongoDB::Client:auth<github:MARTIMM>:ver<0.1.1>;

#-------------------------------------------------------------------------------
=begin pod
=head1 Types
=end pod

#-------------------------------------------------------------------------------
has Array $!topology-description = [];

#-------------------------------------------------------------------------------
has Bool $!topology-set;

#-------------------------------------------------------------------------------
has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
=begin pod
=head2 uri-obj

The uri object after parsing the uri string. All information about the connection can be found here such as host and port number.

  has MongoDB::Uri $.uri-obj;

=end pod

#TE:1:$.uri-obj:
has MongoDB::Uri $.uri-obj;

#-------------------------------------------------------------------------------
has Str $!uri;

#-------------------------------------------------------------------------------
has Str $!Replicaset;

#-------------------------------------------------------------------------------
# Cleaning up is done concurrently so the test on a variable like $!servers
# to be undefined, will not work. Instead check if the below variable is True
# to see if destroying the client is started.
has Bool $!cleanup-started = False;

#-------------------------------------------------------------------------------
# Settings according to mongodb specification
# See https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#heartbeatfrequencyms
# names are written in camelback form, here all lowercase with dashes.
# serverSelectionTryOnce and socketCheckIntervalMS are not supported because
# this is a multi-threaded implementation.
#has Int $!local-threshold-ms;
#has Int $!server-selection-timeout-ms;
#has Int $!heartbeat-frequency-ms;

#-------------------------------------------------------------------------------
method new ( |c ) {

  # In case of an assignement like $c .= new(…) or $c.new(…) $c
  # should be cleaned first

  if self.defined and not $!cleanup-started {
#    note "Client with uri $!uri destroyed.";
    warn-message("Client with uri $!uri destroyed.");
    self.cleanup;
  }

  MongoDB::Client.bless(|c);
}

#-------------------------------------------------------------------------------
=begin pod
=head1 Methods
=head2 new

Create a C<MongoDB::Client> object. The servers are reachable in both ipv4 and ipv6 domains. The ipv4 domain is tried first and after a failure ipv6 is tried. To specify a specific address, the following formats are possible; C<mongodb://127.0.0.1:27017> for ipv4 or C<mongodb://[::1]:27017> for ipv6.

Defined as

  new ( Str:D :$!uri! )

=item :uri; Uri to describe servers and options

B<Note>. It is important to keep the following in mind to prevent memory leakage. The object must be cleaned up by hand before the variable is reused. This is because the Client object creates some background processes to keep an eye on the server and to update server object states and topology.

  my MongoDB::Client $client .= new(:uri(…));
  … work with object …
  $client.cleanup;

Some help is given by the object creation. When it notices that the object is defined along with some internal variables, it will destroy that object first before continuing. This also means that you must not use another C<MongoDB::Client> object to create a new one!

When used for the first time, no leakage is possible

  my MongoDB::Client $c1, $c2;
  $c1 .= new(:uri(…));

In the next step, object C<$c1> will be destroyed because C<.new()> will check if the object is defined. So, do not do this unless you want that behavior.

  $c2 = $c1.new(:uri(…));

This is ok however, because we want to overwrite the object anyway

  $c2 .= new(:uri(…));

And this might result in memory leakage if C<DESTROY()> cannot cleanup the object properly, because C<$c2> was already defined. With an extra note that in the background servers mentioned in C<$c2> will continue to be monitored resulting in loss of performance for the rest of the program!

  $c2 = MongoDB::Client.new(:uri(…));

Note that the servers named in the uri must have something in common such as a replica set. Servers are refused when there is some problem between them e.g. both are master servers. In such situations another C<MongoDB::Client> object should be created for the other server.

=end pod

#TM:1:new:
submethod BUILD ( Str:D :$!uri! ) {

  # set a few specification settings
  #$!local-threshold-ms = C-LOCALTHRESHOLDMS;
  #$!server-selection-timeout-ms = C-SERVERSELECTIONTIMEOUTMS;
  #$!heartbeat-frequency-ms = C-HEARTBEATFREQUENCYMS;


  $!topology-description[Topo-type] = TT-NotSet;
  $!topology-set = False;
  trace-message("init client, topology set to {TT-NotSet}");

  # initialize mutexes
  $!rw-sem .= new;
#    $!rw-sem.debug = True;

  $!rw-sem.add-mutex-names(
    <servers todo topology>, :RWPatternType(C-RW-WRITERPRIO)
  );

  # parse the uri and get info in $!uri-obj. fields are protocol, username,
  # password, servers, database and options.
  $!uri-obj .= new(:$!uri);

  # set the heartbeat frequency by emitting the value found in the URI
  # to the monitor thread
  my MongoDB::ObserverEmitter $event-manager .= new;
  $event-manager.emit(
    'set heartbeatfrequency ms',
    $!uri-obj.options<heartbeatFrequencyMS>
  );

  # Setup todo list with servers to be processed, Safety net not needed
  # because threads are not yet started.
  trace-message("Found {$!uri-obj.servers.elems} servers in uri");
  for @($!uri-obj.servers) -> Hash $server-data {
    my Str $server-name = "$server-data<host>:$server-data<port>";

    if !$event-manager.check-subscription(
      "$!uri-obj.client-key() $server-name process topology"
    ) {
      # This client receives the data from a server in a List to be
      # processed by process-topology().
      $event-manager.subscribe-observer(
        $server-name ~ ' process topology',
        -> List $server-data { self!process-topology(|$server-data); },
        :event-key("$!uri-obj.client-key() $server-name process topology")
      );

      # This client gets new host information from the server. it is
      # possible that hosts are processed before.
      $event-manager.subscribe-observer(
        $server-name ~ ' add servers',
        -> @new-hosts { self!add-servers(@new-hosts); },
        :event-key("$!uri-obj.client-key() $server-name add servers")
      );
    }

    # A server is stored in a pool and can be shared among different clients.
    # The information comes from some server to these clients. Therefore the
    # key must be a server name attached to some string. The folowing observer
    # steps must be done per added server.

    # create Server object
    my MongoDB::ServerPool $server-pool .= instance;

    # This client gets new host information from the server. it is
    # possible that hosts are processed before.
    my Bool $created = $server-pool.add-server(
      $!uri-obj.client-key, $server-name
    );

    unless $created {
#trace-message("Server $server-name already there, try to find topology");
      $server-pool.set-server-data( $server-name, :$!uri-obj);
      self!process-topology( $server-name, ServerType, Bool);
    }
  }
}

#-------------------------------------------------------------------------------
#`{{
Can do this

  my MongoDB::Client $c .= new(:uri<mongodb//server:port/>;
  …
  $c = Nil; # destroyed after some time by garbage collector, but when?
  …
  $c = MongoDB::Client.new(:uri<mongodb//server:port/>;

Server can be removed when DESTROY is called while $c is just initialized again with the same server. This is possible because servers are stored per client using a client key which is generated in Uri using the uri string and the time. Therefore when a server is used by another client too, the server is not removed.
}}

submethod DESTROY ( ) {

  if self.defined and not $!cleanup-started {

#    note "Garbage collect: Destroying client, uri: $!uri";
    warn-message("Garbage collect: Destroying client, uri: $!uri");
    self.cleanup;
  }
}

#-------------------------------------------------------------------------------
#TM:1:database
=begin pod
=head2 database

Create a database object. In mongodb a database and its collections are only
created when data is written in a collection.

  method database ( Str:D $name --> MongoDB::Database )

=end pod
method database ( Str:D $name --> MongoDB::Database ) {
  MongoDB::Database.new( :$!uri-obj, :name($name))
}

#-------------------------------------------------------------------------------
#TM:1:collection
=begin pod
=head2 collection

Create a collection. A shortcut to define a database and collection at once. The names for the database and collection are given in the string full-collection-name. This is a string of two names separated by a dot '.'.

A name like C<contacts.family> means to create and/or access a database C<contacts> with a collection C<family>.

  method collection ( Str:D $full-collection-name --> MongoDB::Collection )

=end pod
method collection ( Str:D $full-collection-name --> MongoDB::Collection ) {

#TODO check for dot in the name
  ( my $db-name, my $cll-name) = $full-collection-name.split( '.', 2);
  my MongoDB::Database $db .= new( :$!uri-obj, :name($db-name));
  $db.collection($cll-name)
}

#-------------------------------------------------------------------------------
#TM:1:cleanup
=begin pod
=head2 cleanup

Stop any background work on the Server object as well as the Monitor object. The cleanup all structures so the object can be cleaned further by the Garbage Collector later.

  method cleanup ( )

=end pod

# cleanup cannot be done in separate thread because everything must be cleaned
# up before other tasks are performed.
method cleanup ( ) {

  $!cleanup-started = True;

  # some timing to see if this cleanup can be improved
  my Instant $t0 = now;

  my MongoDB::ServerPool $server-pool .= instance;
  my MongoDB::ObserverEmitter $e .= new;
  for @($server-pool.get-server-names($!uri-obj.client-key)) -> Str $sname {
    $e.unsubscribe-observer("$!uri-obj.client-key() $sname process topology");
    $e.unsubscribe-observer("$!uri-obj.client-key() $sname add servers");
  }

  # Remove all servers concurrently. Shouldn't be many per client.
  $server-pool.cleanup($!uri-obj.client-key);

  $!rw-sem.rm-mutex-names(<servers todo topology>);
  debug-message("Client destroyed after {(now - $t0)} sec");
}

#-------------------------------------------------------------------------------
#TM:1:server-status
=begin pod
=head2 server-status

Return the status of some server.

  method server-status ( Str:D $server-name --> ServerType )

=end pod

method server-status ( Str:D $server-name --> ServerType ) {

  #! Wait until topology is set
  until $!rw-sem.reader( 'topology', { $!topology-set }) {
    sleep 0.5;
  }

  my MongoDB::ServerPool $server-pool .= instance;
  my ServerType $sts = $server-pool.get-server-data( $server-name, 'status');

  $sts // ST-Unknown
}

#-------------------------------------------------------------------------------
#TM:1:topology
=begin pod
=head2 topology

Return the topology of which the set of servers represents.

  method topology ( --> TopologyType )

=end pod
method topology ( --> TopologyType ) {

  #! Wait until topology is set
  until $!rw-sem.reader( 'topology', { $!topology-set }) {
    sleep 0.5;
  }

  $!rw-sem.reader( 'topology', {$!topology-description[Topo-type]});
}


#TODO pod doc
#TODO use read/write concern for selection
#TODO must break loop when nothing is found
#-------------------------------------------------------------------------------
# No doc, is used internally but must be public for other classes
method select-server ( --> MongoDB::ServerPool::Server ) {

  #! Wait until topology is set
  until $!rw-sem.reader( 'topology', { $!topology-set }) {
#note "wait 0.5: $*THREAD.id()";
    sleep 0.3;
  }

#  my Array $topology-description = $!rw-sem.reader(
#    'topology', { $!topology-description }
#  );
#note "topo: ", $topology-description.perl;

  my MongoDB::ServerPool $server-pool .= instance;
  $server-pool.select-server($!uri-obj.client-key);
}

#-------------------------------------------------------------------------------
#---[ Private methods ]---------------------------------------------------------
#-------------------------------------------------------------------------------
# Add server to todo list.
method !add-servers ( @new-hosts ) {

  trace-message("push @new-hosts[*] on todo list");
try {
  my MongoDB::ObserverEmitter $event-manager .= new;
  my MongoDB::ServerPool $server-pool .= instance;
  for @new-hosts -> Str $server-name {

    # A server is stored in a pool and can be shared among different clients.
    # The information comes from some server to these clients. Therefore the
    # key must be a server name attached to some string. The folowing observer
    # steps must be done per added server.

#    unless $!observed-servers{$server-name} {

    if !$event-manager.check-subscription(
      "$!uri-obj.client-key() $server-name process topology"
    ) {
      # this client receives the data from a server in a List to be processed by
      # process-topology().
      $event-manager.subscribe-observer(
        $server-name ~ ' process topology',
        -> List $server-data { self!process-topology(|$server-data); },
        :event-key("$!uri-obj.client-key() $server-name process topology")
      );

      # this client gets new host information from the server. it is
      # possible that hosts are processed before.
      $event-manager.subscribe-observer(
        $server-name ~ ' add servers',
        -> @new-hosts { self!add-servers(@new-hosts); },
        :event-key("$!uri-obj.client-key() $server-name add servers")
      );
    }

    # create Server object, if server already existed, get the
    # info from server immediately
    my Bool $created = $server-pool.add-server(
      $!uri-obj.client-key, $server-name
    );
    unless $created {
      $server-pool.set-server-data( $server-name, :$!uri-obj);
#trace-message("Server $server-name already there, try to find topology");
#      self!process-topology( $server-name, ServerType, Bool);
    }
  }
CATCH {.note;}
}
}

#-------------------------------------------------------------------------------
method !process-topology (
  Str:D $new-server-name, ServerType $server-status, Bool $is-master
) {
  # update server data
#  self!update-server( $new-server-name, $server-status, $is-master);

  my MongoDB::ServerPool $server-pool .= instance;

  if $server-status.defined and $is-master.defined {
    $server-pool.set-server-data(
      $new-server-name, :status($server-status), :$is-master
    );
    trace-message("server info updated for $new-server-name with $server-status, $is-master");
  }

  else {
    trace-message("server info updated for $new-server-name");
  }


  # find topology
  my TopologyType $topology = TT-Unknown;
#  my Hash $servers = $!rw-sem.reader( 'servers', { $!servers.clone; });
  my Int $servers-count = 0;

  my Bool $found-standalone = False;
  my Bool $found-sharded = False;
  my Bool $found-replica = False;

#  my @server-list = |($server-pool.get-server-names($!uri-obj.client-key));
#trace-message("client '$!uri-obj.keyed-obj()'");

  for @($server-pool.get-server-names($!uri-obj.client-key)) -> $server-name {
#  for $servers.keys -> $server-name {
    $servers-count++;

    # check status of server
    my ServerType $sts = $server-pool.get-server-data( $server-name, 'status');
    given $sts {
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

  # If one of the servers is not ready yet, topology is still TT-NotSet
  unless $topology ~~ TT-NotSet {

    # make it single under some conditions
    $topology = TT-Single
      if $servers-count == 1 and $!uri-obj.options<replicaSet>:!exists;


    $!rw-sem.writer( 'topology', {
        $!topology-description[Topo-type] = $topology;
        $!topology-set = True;
      }
    );
  }

  # set topology info in ServerPool to store with the server
  $server-pool.set-server-data( $new-server-name, :$topology);

  info-message("Client '$!uri-obj.client-key()' topology is $topology");
}


=finish






#-------------------------------------------------------------------------------
# Only for single threaded implementations according to mongodb documents
# has Bool $!server-selection-try-once = False;
# has Int $!socket-check-interval-ms = 5000;



#`{{ canot overide =
#-------------------------------------------------------------------------------
sub infix:<=>( MongoDB::Client $a is rw, MongoDB::Client $b ) is export {
  if $a.defined {
    warn-message('Old client object is defined, will be forcebly cleaned');
    $a.cleanup;
  }

  $a := $b;
}
}}

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
        $!topology-description[Topo-type] = $topology;
        $!topology-set = True;
      }
    );
  }

  info-message("Client topology is $topology");
}
}}

#`{{ not used?
#-------------------------------------------------------------------------------
# Return number of servers
method nbr-servers ( --> Int ) {

  $!rw-sem.reader( 'servers', {$!servers.elems;});
}
}}

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

#`{{
#-------------------------------------------------------------------------------
# Request specific servername
multi method select-server ( Str:D :$servername! --> MongoDB::ServerPool::Server ) {

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  my MongoDB::ServerPool::Server $selected-server;

  # find suitable servers by topology type and operation type
  repeat {

    #! Wait until topology is set
    until $!rw-sem.reader( 'topology', { $!topology-set }) {
      sleep 0.5;
    }

    $selected-server = $!rw-sem.reader( 'servers', {
#note "ss0 Servers: ", $!servers.keys;
#note "ss0 Request: $selected-server.name()";
        $!servers{$servername}:exists
                ?? $!servers{$servername}<server>
                !! MongoDB::ServerPool::Server;
      }
    );

    last if ? $selected-server;
    sleep $!uri-obj.options<heartbeatFrequencyMS> / 1000.0;
  } while ((now - $t0) * 1000) < $!uri-obj.options<serverSelectionTimeoutMS>;

  debug-message("Searched for {((now - $t0) * 1000).fmt('%.3f')} ms");

  if ?$selected-server {
    debug-message("Server '$selected-server.name()' selected");
  }

  else {
    warn-message("No suitable server selected");
  }

  $selected-server;
}
}}

#`{{
#-------------------------------------------------------------------------------
# Read/write concern selection
#multi method select-server (
method select-server ( --> MongoDB::ServerPool::Server ) {

  my MongoDB::ServerPool::Server $selected-server;

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  #! Wait until topology is set
  until $!rw-sem.reader( 'topology', { $!topology-set }) {
note "wait 0.5: $*THREAD.id()";
    sleep 0.5;
  }

  # find suitable servers by topology type and operation type
  repeat {

    my MongoDB::ServerPool::Server @selected-servers = ();
    my Hash $servers = $!rw-sem.reader( 'servers', {$!servers.clone});
    my TopologyType $topology = $!rw-sem.reader(
      'topology', {$!topology-description[Topo-type]
    });

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
        for @selected-servers -> MongoDB::ServerPool::Server $svr {
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

  debug-message("Searched for {((now - $t0) * 1000).fmt('%.3f')} ms");

  if ?$selected-server {
    debug-message("Server '$selected-server.name()' selected");
  }

  else {
    warn-message("No suitable server selected");
  }

  $selected-server;
}
}}
