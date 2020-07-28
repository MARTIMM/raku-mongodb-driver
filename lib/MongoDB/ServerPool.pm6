use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::ServerPool


=end pod

#-------------------------------------------------------------------------------
unit class MongoDB::ServerPool:auth<github:MARTIMM>;

use BSON::Document;

use MongoDB;
use MongoDB::Uri;
use MongoDB::ServerPool::Server;

use Semaphore::ReadersWriters;
use OpenSSL::Digest;

#-------------------------------------------------------------------------------
my MongoDB::ServerPool $instance;

#enum ServerPoolInfo < ServerObject ClientKey ServerPoolKey ServerData >;
enum ServerPoolInfo < ServerObject ServerData >;

# hash key is 'server:port' string which should be unique and cannot belong
# to multiple topologies.
has Hash $!servers-in-pool;

has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  $!servers-in-pool = {};

  $!rw-sem .= new;
  #$!rw-sem.debug = True;
  $!rw-sem.add-mutex-names(
    <server-info>, :RWPatternType(C-RW-WRITERPRIO)
  );

  trace-message("ServerPool created");
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
  Str:D $client-key, Str:D $server-name, *%server-data
) {
  my MongoDB::ServerPool::Server $s .= new( :$client-key, :$server-name);
  self.add-server( $client-key, $s, |%server-data);
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method add-server (
  Str:D $client-key, Str:D $host, Int $port = 27017, *%server-data
) {
  my MongoDB::ServerPool::Server $s .= new( :$client-key, :$host, :$port);
  self.add-server( $client-key, $s, |%server-data);
#  trace-message("Server $host with port $port added to ServerPool");
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method add-server (
  Str:D $client-key, MongoDB::ServerPool::Server:D $server, *%server-data
) {

  my Str $server-name = $server.name;
  %server-data //= %();

  $!rw-sem.writer( 'server-info', {
      $!servers-in-pool{$client-key} = %()
        unless $!servers-in-pool{$client-key}:exists;

      if $!servers-in-pool{$client-key}{$server-name}:exists {
        trace-message("$server-name added before for client $client-key");
#`{{
        # Modify the poolkey of all entries having the same client key
        my Str $pool-key = $!servers-in-pool{$server-name}[ServerPoolKey];
        for $!servers-in-pool.kv -> Str $sname, Array $sinfo {
          next if $sname eq $server-name;
          if $sinfo[ClientKey] eq $client-key and
             $sinfo[ServerPoolKey] ne $pool-key {

            trace-message(
              "ServerPool key $sinfo[ServerPoolKey] modified to $pool-key"
            );
            $sinfo[ServerPoolKey] = $pool-key;
          }
        }
}}
      }

      else {

#`{{
        my Str $pool-key;
        for $!servers-in-pool.kv -> Str $sname, Array $sinfo {
          if $sinfo[ClientKey] eq $client-key {
            $pool-key = $sinfo[ServerPoolKey];
            last;
          }
        }

        $pool-key //= sha256($server-name.encode)>>.fmt('%02X').join;
}}
        trace-message("$server-name added for client $client-key");

        # Keep order: ServerObject, ServerData from enum ServerPoolInfo.
        # %server-data must be set like this otherwise modify immutable
        # value error later on.
        $!servers-in-pool{$client-key}{$server-name} = [
          $server, %(|%server-data)
        ];
      }
    } # writer block
  ); # writer
}

#-------------------------------------------------------------------------------
multi method modify-server-data (
  Str:D $client-key, MongoDB::ServerPool::Server:D $server, *%server-data
) {

  my Str $server-name = $server.name;
  if $!servers-in-pool{$client-key}:exists and
     $!servers-in-pool{$client-key}{$server-name}:exists {

    trace-message("$server.name() data modified: %server-data.perl()");
    $!rw-sem.writer( 'server-info', {
        if $!servers-in-pool{$client-key}{$server-name}:exists {
          for %server-data.kv -> $k, $v {
            $!servers-in-pool{$client-key}{$server-name}[ServerData]{$k} = $v;
          }
        }
      } # writer block
    ); # writer
  }
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method modify-server-data (
  Str:D $client-key, Str $server-name, *%server-data
) {

  if $!servers-in-pool{$client-key}:exists and
     $!servers-in-pool{$client-key}{$server-name}:exists {

    trace-message("$server-name data modified: %server-data.perl()");
  #  my Str $server-name = $server.name;
    $!rw-sem.writer( 'server-info', {
        if $!servers-in-pool{$client-key}{$server-name}:exists {
          for %server-data.kv -> $k, $v {
#            note $!servers-in-pool{$client-key}{$server-name}[ServerData].perl;
#            note "KV: $k, $v";
            $!servers-in-pool{$client-key}{$server-name}[ServerData]{$k} = $v;
          }
        }
      } # writer block
    ); # writer
  }
}

#-------------------------------------------------------------------------------
multi method get-server-data (
  Str:D $client-key, MongoDB::ServerPool::Server:D $server --> Hash
) {

  my Hash $result = %();
  my Str $server-name = $server.name;

  if $!servers-in-pool{$client-key}:exists and
     $!servers-in-pool{$client-key}{$server-name}:exists {

    $!rw-sem.reader( 'server-info', {
        $result = $!servers-in-pool{$client-key}{$server-name}[ServerData]
      }
    )
  }

note "gsd: $result.perl()";

  $result
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method get-server-data (
  Str:D $client-key, Str:D $server-name --> Hash
) {

  my Hash $result = %();

  if $!servers-in-pool{$client-key}:exists and
     $!servers-in-pool{$client-key}{$server-name}:exists {

    $!rw-sem.reader( 'server-info', {
        $result = $!servers-in-pool{$client-key}{$server-name}[ServerData]
      }
    )
  }

note "gsd: $result.perl()";

  $result
}

#-------------------------------------------------------------------------------
method get-server-names ( Str:D $client-key --> Array ) {
#note "k: $client-key: ", $!servers-in-pool.keys;
#note "c: $client-key: ", $!servers-in-pool{$client-key}.keys;
  my Array $result = [];
  if $!servers-in-pool{$client-key}:exists {
    $result = [$!servers-in-pool{$client-key}.keys];
  }

  $result
}

#`{{
#-------------------------------------------------------------------------------
multi method get-server-pool-key ( Str $host, Int $port --> Str ) {

  my Str $server-pool-key;

  my Str $server-name = "$host:$port";
  $server-pool-key = $!servers-in-pool{$server-name}[ServerPoolKey]
    if $!servers-in-pool{$server-name}:exists;

  $server-pool-key
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method get-server-pool-key ( Str $client-key --> Str ) {

  my Str $server-pool-key;

  for $!servers-in-pool.kv -> Str $sname, Array $sinfo {
    if $sinfo[ClientKey] eq $client-key {
      $server-pool-key = $sinfo[ServerPoolKey];
      last;
    }
  }

  $server-pool-key
}
}}

#-------------------------------------------------------------------------------
method select-server (
  BSON::Document $read-concern, Str:D $client-key, Array $topology-description,
  MongoDB::Uri $uri-obj
  --> MongoDB::ServerPool::Server
) {

  my Str $selected-server;

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  # find suitable servers by topology type and operation type
  my TopologyType $topology = $topology-description[Topo-type];
  repeat {

    my Hash $servers-in-pool = $!rw-sem.reader( 'server-info', {
        $!servers-in-pool
      }
    );

    my Str @selected-servers = ();

note "ss1 Servers: ", $servers-in-pool{$client-key}.keys,join(', ');
note "ss1 Topology: $topology";

    given $topology {
      when TT-Single {

        for $servers-in-pool{$client-key}.kv -> $sname, $sinfo {
          $selected-server = $sname;
          my Hash $sdata = $sinfo[ServerData];
          last if $sdata<status> ~~ ST-Standalone;
        }
      }

      when TT-ReplicaSetWithPrimary {

#TODO read concern
#TODO check replica set option in uri
        for $servers-in-pool{$client-key}.kv -> $sname, $sinfo {
          $selected-server = $sname;
          my Hash $sdata = $sinfo[ServerData];
          last if $sdata<status> ~~ ST-RSPrimary;
        }
      }

      when TT-ReplicaSetNoPrimary {

#TODO read concern
#TODO check replica set option in uri if ST-RSSecondary
        for $servers-in-pool{$client-key}.kv -> $sname, $sinfo {
          $selected-server = $sname;
          my Hash $sdata = $sinfo[ServerData];
          @selected-servers.push: $sname
            if $sdata<status> ~~ ST-RSSecondary;
        }
      }

      when TT-Sharded {

        for $servers-in-pool{$client-key}.kv -> $sname, $sinfo {
          $selected-server = $sname;
          my Hash $sdata = $sinfo[ServerData];
          @selected-servers.push: $sname
            if $sdata<status> ~~ ST-Mongos;
        }
      }
    }

    # if no server selected but there are some in the array
    if !$selected-server and +@selected-servers {

      # if only one server in array, take that one
      if @selected-servers.elems == 1 {
        $selected-server = @selected-servers.pop;
      }

      #TODO read / write concern, need primary / can use secondary?
      # now w're getting complex because we need to select from a number
      # of suitable servers.
      else {

        my Array $slctd-svrs = [];
        my Duration $min-rtt-ms .= new(1_000_000_000);

        # get minimum rtt from server measurements
        for @selected-servers -> Str $sname {
          my Hash $sdata = $servers-in-pool{$client-key}{$sname}[ServerData];
          $min-rtt-ms = $sdata<weighted-mean-rtt-ms>
            if $min-rtt-ms > $sdata<weighted-mean-rtt-ms>;
        }

        # select those servers falling in the window defined by the
        # minimum round trip time and minimum rtt plus a treshold
        for @selected-servers -> Str $sname {
          my Hash $sdata = $servers-in-pool{$client-key}{$sname};
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
    sleep $uri-obj.options<heartbeatFrequencyMS> / 1000.0;

  #TODO synchronize with serverSelectionTimeoutMS
  } while ((now - $t0) * 1000) < $uri-obj.options<serverSelectionTimeoutMS>;

  debug-message("Searched for {((now - $t0) * 1000).fmt('%.3f')} ms");

  if ?$selected-server {
    debug-message("Server '$selected-server' selected");
  }

  else {
    warn-message("No suitable server selected");
  }

  $!servers-in-pool{$client-key}{$selected-server}[ServerObject];
}

#-------------------------------------------------------------------------------
method cleanup ( $client-key ) {

  $!rw-sem.writer( 'server-info', {
      for $!servers-in-pool{$client-key}.kv -> $sname, $sinfo {
        $sinfo[ServerObject].cleanup;
      }

      $!servers-in-pool{$client-key}:delete;
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
