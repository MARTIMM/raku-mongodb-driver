use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::ServerPool

This class herds a group of servers which are added by a B<Client> object. Clients can be initialized with a URI that can result in the same set of servers. It is therefore possible that the same server is added from different clients.

=end pod

#-------------------------------------------------------------------------------
unit class MongoDB::ServerPool:auth<github:MARTIMM>;

use BSON::Document;

use MongoDB;
use MongoDB::Uri;
use MongoDB::ServerPool::Server;
use MongoDB::ObserverEmitter;

use Semaphore::ReadersWriters;
use OpenSSL::Digest;

#-------------------------------------------------------------------------------
my MongoDB::ServerPool $instance;

# Servers are stored using two hashes. One to store clients which the server
# provides and one to store the server. The key of the client is provided by
# the client itself as is the server key in the form of a server name
# 'server:port' which is unique. Several clients can set a server but the
# server is only created once. Cleaning up is done using the client key. The
# method checks if the server is used by other clients before removing the
# server. When done the client is also removed from its hash.

#TODO all data should go to the server do not save it here!!
#enum ServerPoolInfo < RefCount ServerObject ServerData >;
#enum ServerPoolInfo < ServerObject ServerData UriObject >;

# %( :client-id(Bool), ... )
has Hash $!clients-of-servers;

# %( :server-name($server-object), ... )
has Hash $!servers-in-pool;

has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!servers-in-pool = %();
  $!clients-of-servers = %();

  $!rw-sem .= new;
  #$!rw-sem.debug = True;
  $!rw-sem.add-mutex-names(
    < server-info client-info >, :RWPatternType(C-RW-WRITERPRIO));
  trace-message("ServerPool created");

  my MongoDB::ObserverEmitter $e .= new;
  $e.subscribe-observer(
    'topology-server',
    -> %topo-info {
      self.set-server-data(
        %topo-info<server-name>, :topology(%topo-info<topology>)
      );
    },
    :event-key('topology-server')
  );
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> MongoDB::ServerPool ) {
  $instance = self.bless unless $instance;
  $instance
}

#-------------------------------------------------------------------------------
#multi method add-server (
method add-server (
  Str:D $client-key, Str:D $server-name, MongoDB::Uri $uri-obj, *%server-data
  --> Bool
) {

  # assume we must create a new server
  my Bool $created-anew = False;

  # check if server was created before. if not create one and store in pool
  unless $!rw-sem.reader(
    'server-info', { $!servers-in-pool{$server-name}:exists }
  ) {

    %server-data //= %();

    my MongoDB::ServerPool::Server $server .= new(:$server-name);
    $!rw-sem.writer( 'server-info', {

        # Keep order: [ ServerObject, ServerData, UriObject] from enum
        # ServerPoolInfo. %server-data must be set like this otherwise
        # modify immutable value error later on.
        $!servers-in-pool{$server-name} = $server;
        $server.set-server-data( :$uri-obj, |%server-data);

        trace-message("$server-name added");
        $created-anew = True;
      } # writer block
    ); # writer
  }

  # set client info
  $!rw-sem.writer( 'client-info', {
      # check if client exists, if not, init
      $!clients-of-servers{$client-key} = %()
        unless $!clients-of-servers{$client-key}:exists;

      # check if done before
      if $!clients-of-servers{$client-key}{$server-name}:exists {
        trace-message("$server-name already added for client $client-key");
      }

      else {
        # add server to this client
        $!clients-of-servers{$client-key}{$server-name} = True;
        trace-message("Add $server-name for client $client-key");
      }
    }
  );

  $created-anew
}

#`{{
#-------------------------------------------------------------------------------
multi method set-server-data (
  MongoDB::ServerPool::Server:D $server, *%server-data
) {

  my Str $server-name = $server.name;
  if $!rw-sem.reader( 'server-info', {$!servers-in-pool{$server-name}:exists}) {

    trace-message("$server.name() data modified: %server-data.perl()");
    $!rw-sem.writer( 'server-info', {
        if $!servers-in-pool{$server-name}:exists {
          for %server-data.kv -> $k, $v {
            $!servers-in-pool{$server-name}[ServerData]{$k} = $v;
          }
        }
      } # writer block
    ); # writer
  }
}
}}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
method set-server-data ( Str $server-name, *%server-data ) {

  # use reader because locally it's reading servers in pool. the server
  # protects using a writer
  $!rw-sem.reader( 'server-info', {
      if $!servers-in-pool{$server-name}:exists {
        $!servers-in-pool{$server-name}.set-server-data(|%server-data);
      }
    }
  );
}

#`{{
#-------------------------------------------------------------------------------
multi method get-server-data (
  MongoDB::ServerPool::Server:D $server --> Hash
) {

  my Hash $result = %();
  my Str $server-name = $server.name;

  if $!rw-sem.reader( 'server-info', {$!servers-in-pool{$server-name}:exists}) {

    $result = $!rw-sem.reader( 'server-info', {
        $!servers-in-pool{$server-name}[ServerData]
      }
    )
  }

  $result
}
}}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
method get-server-data ( Str:D $server-name, *@items --> Any ) {

  my Hash $result = %();

  $!rw-sem.reader( 'server-info', {
      if $!servers-in-pool{$server-name}:exists {

        my $r = $!servers-in-pool{$server-name}.get-server-data(|@items);
note "r: $*THREAD.id(), ", $r.WHAT;
if $r ~~ Promise {
  note "r: ", $r.status;
  note "r: ", $r.result;
}
$result = $r;
      }
    }
  );

  $result
}

#-------------------------------------------------------------------------------
method get-server-names ( Str:D $client-key --> List ) {


  |$!rw-sem.reader( 'client-info', {
      trace-message(
        "client '$client-key', $!clients-of-servers{$client-key}.keys()"
      );

      $!clients-of-servers{$client-key}.keys
    }
  )
}

#-------------------------------------------------------------------------------
method select-server (
  BSON::Document $read-concern, Str $client-key
  --> MongoDB::ServerPool::Server
) {
  # get server names belonging to this client
  my Hash $selectable-servers =
    $!rw-sem.reader( 'client-info', { $!clients-of-servers{$client-key} } );

  my Hash $servers-in-pool =
    $!rw-sem.reader( 'server-info', { $!servers-in-pool } );

  # the uri object can be applied to all servers delivered by the client
  my MongoDB::Uri $uri-obj;
  my $o =
    $servers-in-pool{$selectable-servers.kv[0]}.get-server-data('uri-obj');
note "o: $*THREAD.id(), ", $o.WHAT;
if $o ~~ Promise {
note "o: ", $o.status;
note "o: ", $o.result;
}
$uri-obj = $o;

  my Str $selected-server;

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  # find suitable servers by topology type and operation type
  repeat {

    $servers-in-pool = $!rw-sem.reader( 'server-info', {
        $!servers-in-pool
      }
    );

    my Str @selected-servers = ();
    for $servers-in-pool.keys -> Str $server-name {
      next unless $selectable-servers{$server-name}:exists;

      my Hash $sdata = $servers-in-pool{$server-name}.get-server-data(
        <topology status>
      );
      my TopologyType $topology = $sdata<topology> // TT-NotSet;

#note "ss1 Servers: ", $servers-in-pool.keys,join(', ');
#note "ss1 Topology: $server-name, $topology";

      given $topology {
        when TT-Single {

          $selected-server = $server-name;
          last if $sdata<status> ~~ ST-Standalone;
        }

        when TT-ReplicaSetWithPrimary {

#TODO read concern
#TODO check replica set option in uri
          $selected-server = $server-name;
          last if $sdata<status> ~~ ST-RSPrimary;
        }

        when TT-ReplicaSetNoPrimary {

#TODO read concern
#TODO check replica set option in uri if ST-RSSecondary
          $selected-server = $server-name;
          @selected-servers.push: $server-name
            if $sdata<status> ~~ ST-RSSecondary;
        }

        when TT-Sharded {

          $selected-server = $server-name;
          @selected-servers.push: $server-name if $sdata<status> ~~ ST-Mongos;
        }
      }
    }

    # if no server selected but there are some in the array
    if !$selected-server and +@selected-servers {

      # if only one server in array, take that one
#      if @selected-servers.elems == 1 {
#        $selected-server = @selected-servers.pop;
#      }

      #TODO read / write concern, need primary / can use secondary?
      # now w're getting complex because we need to select from a number
      # of suitable servers.
#      else {
      unless @selected-servers.elems == 1 {

        my Array $slctd-svrs = [];
        my Duration $min-rtt-ms .= new(1_000_000_000);

        # get minimum rtt from server measurements
        for @selected-servers -> Str $server-name {
          my $wm-rtt-ms = $servers-in-pool{$server-name}.get-server-data(
            <weighted-mean-rtt-ms>
          );
#          my Hash $sdata = $servers-in-pool{$server-name}[ServerData];
          $min-rtt-ms = $wm-rtt-ms if $min-rtt-ms > $wm-rtt-ms;
        }

        # select those servers falling in the window defined by the
        # minimum round trip time and minimum rtt plus a treshold
        for @selected-servers -> Str $server-name {
          my $wm-rtt-ms = $servers-in-pool{$server-name}.get-server-data(
            <weighted-mean-rtt-ms>
          );
#          my Hash $sdata = $servers-in-pool{$server-name};
          $slctd-svrs.push: $server-name
            if $wm-rtt-ms <= (
              $min-rtt-ms + $uri-obj.options<localThresholdMS>
            );
        }

        # now choose one at random
        $selected-server = $slctd-svrs.pick;
      }
    }

    # done when a suitable server is found
    last if $selected-server.defined;

    # else wait for status and topology updates
    #TODO synchronize with monitor times
#    sleep $uri-obj.options<heartbeatFrequencyMS> / 1000.0;
    sleep 0.2;

  #TODO synchronize with serverSelectionTimeoutMS
  } while ((now - $t0) * 1000) < $uri-obj.options<serverSelectionTimeoutMS>;

  debug-message("Searched for {((now - $t0) * 1000).fmt('%.3f')} ms");

  if ?$selected-server {
    debug-message("Server '$selected-server' selected");
  }

  else {
    warn-message("No suitable server selected");
  }

  $!servers-in-pool{$selected-server};
}

#-------------------------------------------------------------------------------
method cleanup ( Str:D $client-key ) {

  # get server names of this client while removing the client
  my Hash $client-data = $!rw-sem.reader(
    'client-info', { $!clients-of-servers{$client-key}:delete; }
  );

  my @servers = $client-data.keys;
  trace-message("cleanup for client $client-key: $client-data.keys()");

  # skim through rest of the clients to gather used servernames
  my @other-servers = ();

  $!rw-sem.reader( 'client-info', {
      # get servernames and make the list with unique entries
      for $!clients-of-servers.kv -> Str $client-key, Hash $servers {
        @other-servers.push: $servers.keys;
      }
    } # reader code
  );  # reader

  @other-servers .= unique;

  # test the list against the removed clients server list and remove any
  # server name found with the other clients.
  my Int $idx;
  for @other-servers -> $osrvr {
    @servers.splice( $idx, 1) if $idx = @servers.first( $osrvr, :k);
  }

  # now we can remove the servers which are not in use by other clients
  for @servers -> $server-name {
    trace-message("cleanup server $server-name");

    # check if the name is still there, can be removed behind my back
    if $!rw-sem.reader(
      'server-info', {$!servers-in-pool{$server-name}:exists; }
    ) {
      my $server = $!rw-sem.writer(
        'server-info', {$!servers-in-pool{$server-name}:delete;}
      );

      $server.cleanup;
    }
  }

trace-message("leftover: " ~ $!servers-in-pool.perl);
}

=finish
#-------------------------------------------------------------------------------
method get-socket (
  Str $host, Int $port, Str :$username, Str :$password
  --> IO::Socket::INET
) {

  my IO::Socket::INET $socket;
  my Int $thread-id = $*THREAD.id();

  if $!socket-info{"$host $port $*THREAD.id()"}:exists {
    $socket = $!socket-info{"$host $port $*THREAD.id()"}<socket>;
  }

  else {
    try {
      $socket .= new( :$host, :$port);
      CATCH {
        default {
          # Retry for ipv6. this throws too if still failing
          $socket .= new( :$host, :$port, :family(PF_INET6));
        }
      }
    }

    $!socket-info{"$host $port $*THREAD.id()"} = %(
      :$socket, :$username, :$password
    ) if ?$socket;
  }

  $socket
}

#-------------------------------------------------------------------------------
multi method cleanup ( Str $host, Int $port ) {

  my Int $thread-id = $*THREAD.id();
  if $!socket-info{"$host $port $thread-id"}:exists {
    $!socket-info{"$host $port $thread-id"}<socket>.close;
    $!socket-info{"$host $port $thread-id"}:delete;
  }
}

#-------------------------------------------------------------------------------
multi method cleanup ( :$cleanup-all! ) {

  for $!socket-info.keys -> $socket-pool-item {
    $!socket-info{$socket-pool-item}<socket>.close;
    $!socket-info{$socket-pool-item}:delete;
  }
}

#-------------------------------------------------------------------------------
