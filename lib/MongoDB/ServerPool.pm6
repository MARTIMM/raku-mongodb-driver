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

#enum ServerPoolInfo < ServerObject ClientKey ServerPoolKey ServerData >;
enum ServerPoolInfo < RefCount ServerObject ServerData >;

# hash key is 'server:port' string which should be unique and cannot belong
# to multiple topologies.
has Hash $!servers-in-pool;

has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!servers-in-pool = {};

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
multi method add-server (
  Str:D $server-name, *%server-data
) {
  if $!rw-sem.reader(
    'server-info', { $!servers-in-pool{$server-name}:!exists }
  ) {
    my MongoDB::ServerPool::Server $s .= new(:$server-name);
    self.add-server( $s, |%server-data);
  }

  else {
    trace-message("$server-name already added");
    $!servers-in-pool{$server-name}[RefCount]++;
  }
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method add-server (
  Str:D $host, Int $port = 27017, *%server-data
) {
  my Str $server-name = $host ~~ /':'/ ?? "[$host]:$port" !! "$host:$port";
  if $!rw-sem.reader(
    'server-info', { $!servers-in-pool{$server-name}:!exists }
  ) {
    my MongoDB::ServerPool::Server $s .= new( :$host, :$port);
    self.add-server( $s, |%server-data);
  }

  else {
    trace-message("$server-name already added");
    $!servers-in-pool{$server-name}[RefCount]++;
  }
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method add-server (
  MongoDB::ServerPool::Server:D $server, *%server-data
) {

  my Str $server-name = $server.name;
  %server-data //= %();

  $!rw-sem.writer( 'server-info', {
      if $!servers-in-pool{$server-name}:exists {
        trace-message("$server-name already added");
        $!servers-in-pool{$server-name}[RefCount]++;
      }

      else {

        trace-message("$server-name added");

        # Keep order: ServerObject, ServerData from enum ServerPoolInfo.
        # %server-data must be set like this otherwise modify immutable
        # value error later on.
        $!servers-in-pool{$server-name} = [
          0, $server, %(|%server-data)
        ];
      }
    } # writer block
  ); # writer
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
  BSON::Document $read-concern, MongoDB::Uri $uri-obj, Hash $selectable-servers
  --> MongoDB::ServerPool::Server
) {

  my Str $selected-server;

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  # find suitable servers by topology type and operation type
  repeat {

    my Hash $servers-in-pool = $!rw-sem.reader( 'server-info', {
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
    sleep 0.3;

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
method cleanup ( $server-name ) {

  $!rw-sem.writer( 'server-info', {
      if $!servers-in-pool{$server-name}:exists {
        $!servers-in-pool{$server-name}[RefCount]--;
        if $!servers-in-pool{$server-name}[RefCount] == 0 {
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
