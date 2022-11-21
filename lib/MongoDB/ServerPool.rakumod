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

# Servers are stored using two hashes. One to store clients which have the
# servers in their topology and one to store the server. The key of the client
# is provided by the client itself as is the server key in the form of a server
# name 'server:port' which is unique. Several clients can set a server but the
# server is only created once. Cleaning up is done using the client key. The
# method checks if the server is used by other clients before removing the
# server. When done the client is removed from the hash.

# $!clients-of-servers{client-id}{server-name} = *
has Hash $!clients-of-servers;

# $!servers-in-pool{server-name} = $server-object
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
}

#-------------------------------------------------------------------------------
method new ( ) { !!! }

#-------------------------------------------------------------------------------
method instance ( --> MongoDB::ServerPool ) {
  $instance //= self.bless;
  $instance
}

#-------------------------------------------------------------------------------
#multi method add-server (
method add-server ( Str:D $client-key, Str:D $server-name --> Bool ) {

  # assume we didn't have to create a new server
  my Bool $created-anew = False;

  # check if server was created before. if not, create one and store in pool
  unless $!rw-sem.reader(
    'server-info', { $!servers-in-pool{$server-name}:exists }
  ) {
    my MongoDB::ServerPool::Server $server .= new(:$server-name);
    $!rw-sem.writer( 'server-info', {

        $!servers-in-pool{$server-name} = $server;
        $server.set-data( :status(ST-Unknown), :!ismaster);

        $created-anew = True;
      }
    );

    trace-message("$server-name added");
  }

  # set client info
  $!rw-sem.writer( 'client-info', {
      # check if client exists, if not, init
trace-message("client $client-key does not exist") unless $!clients-of-servers{$client-key}:exists;
      $!clients-of-servers{$client-key} = %()
        unless $!clients-of-servers{$client-key}:exists;
    }
  );

  # check if client already had this server added
  if $!rw-sem.reader(
    'client-info', { $!clients-of-servers{$client-key}{$server-name}:exists; }
  ) {
    trace-message("$server-name already added for client $client-key");
  }

  else {
    # add server to this client
    $!rw-sem.writer(
      'client-info', { $!clients-of-servers{$client-key}{$server-name} = True; }
    );
    trace-message("Add $server-name for client $client-key");
  }

  $created-anew
}

#-------------------------------------------------------------------------------
method set-server-data ( Str $server-name, *%server-data ) {

trace-message("Set data for $server-name");
  # use reader because locally it's reading servers in pool. the server
  # protects using a writer
  $!rw-sem.reader( 'server-info', {
      if $!servers-in-pool{$server-name}:exists {
        $!servers-in-pool{$server-name}.set-data(|%server-data);
      }
    }
  );
}

#-------------------------------------------------------------------------------
method get-server-data ( Str:D $server-name, *@items --> Any ) {

  my Any $result;

  if $!rw-sem.reader(
    'server-info', { $!servers-in-pool{$server-name}:exists; }
  ) {
    $result = $!servers-in-pool{$server-name}.get-data(|@items);
  }

  $result
}

#-------------------------------------------------------------------------------
method get-server-names ( Str:D $client-key --> Array ) {

  my Array $cos = [ |( $!rw-sem.reader(
        'client-info', { $!clients-of-servers{$client-key}.keys; }
      )
    )
  ];

  trace-message("client '$client-key', $cos.perl()");

  $cos;
}

#-------------------------------------------------------------------------------
method select-server ( Str $client-key --> MongoDB::ServerPool::Server ) {
#  sleep 10;
  my Str $selected-server;

  # record the server selection start time. used also in debug message
  my Instant $t0 = now;

  # the uri object can be applied to all servers delivered by the client
  my MongoDB::Uri $uri-obj;

  my Hash $selectable-servers;
  my Hash $servers-in-pool;

  # find suitable servers by topology type and operation type
  loop {

    # get server names belonging to this client
    $selectable-servers =
      $!rw-sem.reader( 'client-info', { $!clients-of-servers{$client-key} } );

    $servers-in-pool =
      $!rw-sem.reader( 'server-info', { $!servers-in-pool } );


    $servers-in-pool = $!rw-sem.reader( 'server-info', {
        $!servers-in-pool
      }
    );

    my Str @selected-servers = ();
    for $servers-in-pool.keys -> Str $server-name {
      next unless $selectable-servers{$server-name}:exists;

      my Hash $sdata = $servers-in-pool{$server-name}.get-data(
        <topology status>
      );
      my TopologyType $topology = $sdata<topology> // TT-NotSet;

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

      #TODO read / write concern, need primary / can use secondary?
      # now w're getting complex because we need to select from a number
      # of suitable servers.
      unless @selected-servers.elems == 1 {

        my Array $slctd-svrs = [];
        my Duration $min-rtt-ms .= new(1_000_000_000);

        # get minimum rtt from server measurements
        for @selected-servers -> Str $server-name {
          my $wm-rtt-ms = $servers-in-pool{$server-name}.get-data(
            <weighted-mean-rtt-ms>
          );

          $min-rtt-ms = $wm-rtt-ms if $min-rtt-ms > $wm-rtt-ms;
        }

        # select those servers falling in the window defined by the
        # minimum round trip time and minimum rtt plus a treshold
        for @selected-servers -> Str $server-name {
          my $wm-rtt-ms = $servers-in-pool{$server-name}.get-data(
            <weighted-mean-rtt-ms>
          );

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

##`{{
    # pick first server to get uri object. options are the same for all
    # servers belonging to the client-id
    $uri-obj = $servers-in-pool{
      $selectable-servers.kv[0]
    }.get-data('uri-obj') // MongoDB::Uri;

    # object might not be set yet
    if $uri-obj.defined {

      # give up when serverSelectionTimeoutMS is passed
      last
        unless ((now - $t0) * 1000) < $uri-obj.options<serverSelectionTimeoutMS>;
    }
#}}

    # wait for some arbitrary short period
    sleep 0.1;
  }

  debug-message("Searched for {((now - $t0) * 1000).fmt('%.3f')} ms");

  if ?$selected-server {
    debug-message("Server '$selected-server' selected");
  }

  else {
    warn-message("No suitable server selected");
  }

#  $!servers-in-pool{$selected-server};
  if $selected-server.defined {
    $!rw-sem.reader( 'server-info', { $!servers-in-pool{$selected-server}; })
  }

  else {
    MongoDB::ServerPool::Server
  }
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

    my $server = $!rw-sem.writer(
      'server-info', {$!servers-in-pool{$server-name}:delete;}
    );

    $server.cleanup($client-key) if $server.defined;
    trace-message("cleaned up server $server-name");
  }

#trace-message("leftover: " ~ $!servers-in-pool.perl);
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
