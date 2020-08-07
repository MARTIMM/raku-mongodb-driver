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

#enum ServerPoolInfo < RefCount ServerObject ServerData >;
enum ServerPoolInfo < ServerObject ServerData UriObject >;

has Hash $!clients-of-servers;
has Hash $!servers-in-pool;

has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!servers-in-pool = %();
  $!clients-of-servers = %();

  $!rw-sem .= new;
  #$!rw-sem.debug = True;
  $!rw-sem.add-mutex-names( <server-info>, :RWPatternType(C-RW-WRITERPRIO));
  trace-message("ServerPool created");

  my MongoDB::ObserverEmitter $e .= new;
  $e.subscribe-observer(
    'topology-server',
    -> %topo-info {
      self.modify-server-data(
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
) {

  # set client info
  $!rw-sem.writer( 'server-info', {
      # check if client exists, if not, init
      $!clients-of-servers{$client-key} = %()
        unless $!clients-of-servers{$client-key}:exists;

      # add server to this client
      $!clients-of-servers{$client-key}{$server-name} = True;
    } # writer block
  ); # writer

  if $!rw-sem.reader(
    'server-info', { $!servers-in-pool{$server-name}:exists }
  ) {

    trace-message("$server-name already added");
#    $!servers-in-pool{$server-name}[RefCount]++;
  }

  else {

    %server-data //= %();

    $!rw-sem.writer( 'server-info', {

        if $!servers-in-pool{$server-name}:exists {
          trace-message("$server-name already added");
#          $!servers-in-pool{$server-name}[RefCount]++;
        }

        else {

          my MongoDB::ServerPool::Server $server .= new(:$server-name);

          # Keep order: ServerObject, ServerData, UriObject from enum
          # ServerPoolInfo. %server-data must be set like this otherwise
          # modify immutable value error later on.
          $!servers-in-pool{$server-name} = [
            $server, %(|%server-data), $uri-obj
          ];

          trace-message("$server-name added");
        }
      } # writer block
    ); # writer
  }
}

#-------------------------------------------------------------------------------
multi method modify-server-data (
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

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method modify-server-data ( Str $server-name, *%server-data ) {

  if $!rw-sem.reader( 'server-info', {$!servers-in-pool{$server-name}:exists}) {

    $!rw-sem.writer( 'server-info', {
        if $!servers-in-pool{$server-name}:exists {
          for %server-data.kv -> $k, $v {
            $!servers-in-pool{$server-name}[ServerData]{$k} = $v;
          }
        }
      } # writer block
    ); # writer

    trace-message("$server-name data modified: %server-data.perl()");
  }
}

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

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method get-server-data ( Str:D $server-name --> Hash ) {

  my Hash $result = %();

  if $!rw-sem.reader( 'server-info', {$!servers-in-pool{$server-name}:exists}) {

    $result = $!rw-sem.reader( 'server-info', {
        $!servers-in-pool{$server-name}[ServerData]
      }
    )
  }

  $result
}

#-------------------------------------------------------------------------------
method get-server-names ( --> Array ) {

  [$!servers-in-pool.keys];
}

#-------------------------------------------------------------------------------
method select-server (
  BSON::Document $read-concern, Str $client-key
  --> MongoDB::ServerPool::Server
) {

  # get server names belonging to this client
  my Hash $selectable-servers =
    $!rw-sem.reader( 'server-info', { $!clients-of-servers{$client-key} } );

  my Hash $servers-in-pool =
    $!rw-sem.reader( 'server-info', { $!servers-in-pool } );

  # the uri object can be applied to all servers delevered by the client
  my MongoDB::Uri $uri-obj =
    $servers-in-pool{$selectable-servers.kv[0]}[UriObject];

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
    for $servers-in-pool.keys -> $server-name {
      next unless $selectable-servers{$server-name}:exists;

      my Hash $sdata = $servers-in-pool{$server-name}[ServerData];
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
        for @selected-servers -> Str $sname {
          my Hash $sdata = $servers-in-pool{$sname}[ServerData];
          $min-rtt-ms = $sdata<weighted-mean-rtt-ms>
            if $min-rtt-ms > $sdata<weighted-mean-rtt-ms>;
        }

        # select those servers falling in the window defined by the
        # minimum round trip time and minimum rtt plus a treshold
        for @selected-servers -> Str $sname {
          my Hash $sdata = $servers-in-pool{$sname};
          $slctd-svrs.push: $sname
            if $sdata<weighted-mean-rtt-ms> <= (
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

  $!servers-in-pool{$selected-server}[ServerObject];
}

#-------------------------------------------------------------------------------
method cleanup ( Str:D $client-key ) {

  # get server names of this client while removing the client
  my Hash $client-data = $!rw-sem.writer( 'server-info', {
       $!clients-of-servers{$client-key}:delete;
    }
  );

  my @servers = $client-data.keys;

  # skim through rest of the clients to gather used servernames
  my @other-servers = ();
  my $clients-of-servers =
    $!rw-sem.reader( 'server-info', { $!clients-of-servers; });

  # get servernames and make the list with unique entries
  for $clients-of-servers.kv -> Str $client-key, Hash $servers {
    @other-servers.push: $servers.keys;
  }
  @other-servers .= unique;

  # test the list against the removed clients server list and remove any server
  # name found with the other clients.
  my Int $idx;
  for @other-servers -> $osrvr {
    @servers.splice( $idx, 1) if $idx = @servers.first( $osrvr, :k);
  }

  $!rw-sem.writer( 'server-info', {
      # now we can remove the servers which are not in use by other clients
      for @servers -> $server-name {
        # check if the name is still there, can be removed behind my back
        if $!servers-in-pool{$server-name}:exists {
          $!servers-in-pool{$server-name}[ServerObject].cleanup;
          $!servers-in-pool{$server-name}:delete;
        }
      }
    }
  );
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
