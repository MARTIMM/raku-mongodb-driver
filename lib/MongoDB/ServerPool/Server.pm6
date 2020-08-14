#TL:1:MongoDB::ServerPool::Server:

use v6;

use MongoDB;
use MongoDB::Wire;
#use MongoDB::Client;
use MongoDB::Uri;
use MongoDB::Server::Monitor;
use MongoDB::SocketPool;
use MongoDB::SocketPool::Socket;
use MongoDB::Authenticate::Credential;
use MongoDB::Authenticate::Scram;
use MongoDB::ObserverEmitter;

use BSON::Document;
use Semaphore::ReadersWriters;
use Auth::SCRAM;

#-------------------------------------------------------------------------------
unit class MongoDB::ServerPool::Server:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
## name and port is kept separated for use by Socket.
#TM:1:host():
has Str $.host;

#TM:1:port():
has Int $.port;

#TM:1:name():
has Str $.name;

#TM:1:server-is-registered():
has Bool $.server-is-registered;

# server status data. Must be protected by a semaphore because of a thread
# handling monitoring data.
has Hash $!server-data;
has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
#TM:1:new(:$server-name)
multi submethod BUILD ( Str:D :$server-name! ) {

  if $server-name ~~ m/ $<ip6addr> = ('[' .*? ']') / {
    my $h = $!host = $/<ip6addr>.Str;
    $!port = $server-name;
    $!port ~~ s/$h ':'//;
  }

  else {
    ( $!host, $!port ) = map(
      -> $h, $p { ($h, ($p //= 27017).Int) }, $server-name.split(':')
    )[0];
  }

  self!init();
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#TM:1:new(:host,:port)
multi submethod BUILD ( Str:D :$!host!, Int :$!port = 27017 ) {

  self!init();
}

#-------------------------------------------------------------------------------
method !init ( ) {

#  trace-message("Server $!host on $!port initialization");

  # server status is unsetled
  $!server-data = %( :status(ST-Unknown), :!is-master, :error('') );

  $!rw-sem .= new;
  #$!rw-sem.debug = True;
  $!rw-sem.add-mutex-names(
    <s-select s-status>, :RWPatternType(C-RW-WRITERPRIO)
  );

  $!server-is-registered = False;

#`{{
  # save name and port of the server. Servername and port are always
  # 'hostname:port' format, even when ipv6. The port number is always
  # present at this point, extracting it from the end from the spec.
  my Int $port = $!server-port = [$server-name.split(':')].pop.Int;
  $!server-name = $server-name;
  $!server-name ~~ s/ ':' $port $//;

  # Remove the brackets if they are there. ipv6 addresses have them.
  $!server-name ~~ s/^ '[' //;
  $!server-name ~~ s/ ']' $//;
}}
  $!name = self!set-server-name;

  trace-message("Server object for $!name initialized");

  # set the heartbeat frequency
  my MongoDB::ObserverEmitter $event-manager .= new;

  # observe results from monitor only for this particular server. use the
  # key generated in the uri object and the servername to prevent other
  # servers to interprete data not meant for them.
#  $!server-key = $!client-key ~ $!name;
  $event-manager.subscribe-observer(
    $!name ~ ' monitor data',
    -> Hash $monitor-data { self!process-monitor-data($monitor-data); },
    :event-key($!name ~ ' monitor data')
  );

  # now we can register a server
#note "Register a server: $!name";
  $event-manager.emit( 'register server', self);
  $!server-is-registered = True;
}

#-------------------------------------------------------------------------------
method !process-monitor-data ( Hash $monitor-data ) {

#note 'pmd: ', $monitor-data.perl;

  my Bool $is-master = False;
  my ServerType $server-status = ST-Unknown;

  # test monitor result. when the doc is not ok, the doc contains
  # failure information
  if $monitor-data<ok> {

    # used to get a socket and decide on type of authentication
    my $mdata = $monitor-data<monitor>;

    # test mongod server defined field ok for state of returned document
    # this is since newer servers return info about servers going down
    if ?$mdata and $mdata<ok>:exists and $mdata<ok> == 1e0 {

#note "MData: $monitor-data.perl()";
      ( $server-status, $is-master) = self!process-status($mdata);

      $!rw-sem.writer( 's-status', {
          $!server-data = %(
            :status($server-status), :$is-master, :error(''),
            :max-wire-version($mdata<maxWireVersion>.Int),
            :min-wire-version($mdata<minWireVersion>.Int),
            :weighted-mean-rtt-ms($monitor-data<weighted-mean-rtt-ms>),
          )
        } # writer block
      ); # writer
    } # if $mdata<ok> == 1e0

    else {
      if ?$mdata and $mdata<ok>:!exists {
        warn-message("Missing field in doc {$mdata.perl}");
      }

      else {
        warn-message("Unknown error: {($mdata // '-').perl}");
      }

      ( $server-status, $is-master) = ( ST-Unknown, False);
    }
  } # if $monitor-data<ok>

  # Server did not respond or returned an error
  else {

    $!rw-sem.writer( 's-status', {
        if $monitor-data<reason>:exists {
          $!server-data<error> = $monitor-data<reason>;
        }

        else {
          $!server-data<error> = 'Server did not respond';
        }

        $!server-data<is-master> = False;
        $!server-data<status> = ST-Unknown;

        ( $server-status, $is-master) = ( ST-Unknown, False);

      } # writer block
    ); # writer
  } # else

  # Set the status with the new value
  info-message("Server status of $!name is $server-status");

  # Let the client find the topology using all found servers
  # in the same rhythm as the heartbeat loop of the monitor
  # (of each server)
  #$!client.process-topology;

  # the keyed uri is used to notify the proper client, there can be
  # more than one active
  my MongoDB::ObserverEmitter $notify-client;
  $notify-client.emit(
    $!name ~ ' process topology', ( $!name, $server-status, $is-master)
  );
}

#-------------------------------------------------------------------------------
method !process-status ( BSON::Document $mdata --> List ) {

  my Bool $is-master = False;
  my ServerType $server-status = ST-Unknown;
  my MongoDB::ObserverEmitter $notify-client;

  # Shard server
  if $mdata<msg>:exists and $mdata<msg> eq 'isdbgrid' {
    $server-status = ST-Mongos;
  }

  # Replica server in preinitialization state
  elsif ? $mdata<isreplicaset> {
    $server-status = ST-RSGhost;
  }

  elsif ? $mdata<setName> {
    $is-master = ? $mdata<ismaster>;
    if $is-master {
      $server-status = ST-RSPrimary;
      $notify-client.emit(
        $!name ~ ' add servers', @($mdata<hosts>)
      ) if $mdata<hosts>:exists;
    }

    elsif ? $mdata<secondary> {
      $server-status = ST-RSSecondary;
      $notify-client.emit(
        $!name ~ ' add servers', @($mdata<primary>)
      ) if $mdata<primary>:exists;
    }

    elsif ? $mdata<arbiterOnly> {
      $server-status = ST-RSArbiter;
    }

    else {
      $server-status = ST-RSOther;
    }
  }

  else {
    $server-status = ST-Standalone;
    $is-master = ? $mdata<ismaster>;
  }

  ( $server-status, $is-master)
}

#-------------------------------------------------------------------------------
#TM:1:get-data():
# if 0 items, return all data in a Hash
# if one item, return value of item
# if more items, return items and values in a Hash
method get-data ( *@items --> Any ) {

#note "its: @items.perl()";
  my Any $data;

  if @items.elems == 0 {
    $data = $!rw-sem.reader( 's-status', {$!server-data});
    trace-message("$!host:$!port return all data: $data.perl()");
  }

  elsif @items.elems == 1 {
    $data = $!rw-sem.reader( 's-status', {$!server-data{@items[0]}});
    trace-message(
      "$!host:$!port return data item: @items[0], $data.perl()"
    );
  }

  else {
    my $sd = $!rw-sem.reader( 's-status', {$!server-data{@items}});

    $data = %(%(@items Z=> @$sd).grep({.value.defined}));
    trace-message(
      "$!host:$!port return data items: @items.perl(), $data.perl()"
    );
  }

  $data
}

#-------------------------------------------------------------------------------
#TM:1:set-data():
method set-data ( *%items ) {

  my $sd = $!rw-sem.writer( 's-status', {
      $!server-data = %( |$!server-data, |%items);
    }
  );

  trace-message("$!host:$!port data modified: $sd.perl()");
}

#`{{
#-------------------------------------------------------------------------------
# Make a tap on the Supply. Use act() for this so we are sure that only this
# code runs whithout any other parrallel threads.
#
method tap-monitor ( |c --> Tap ) {

  MongoDB::Server::Monitor.instance.get-supply.tap(|c);
}
}}

#-------------------------------------------------------------------------------
# Search in the array for a closed Socket.
# By default authentication is needed when user/password info is found in the
# uri data. Monitor however, does not need this and therefore monitor is
# using raw-query with :!authenticate.

# When a new socket is opened and it fails, it will not be stored because the
# thrown exception is catched in Wire where the call is done. This also means
# that calling new must be done outside any semaphore locks
method get-socket (
  Bool :$authenticate = True --> MongoDB::SocketPool::Socket
) {
  trace-message( "Get socket, authenticate = $authenticate");

  my MongoDB::SocketPool $socket-pool .= instance;
  $socket-pool.get-socket( self.host, self.port
    #, Str :$username, Str :$password
  );
}

#`{{
method get-socket (
  Bool :$authenticate = True --> MongoDB::SocketPool::Socket
) {

  # If server is not registered then the server is cleaned up
  return MongoDB::SocketPool::Socket unless $!server-is-registered;

  # Use return value to see if authentication is needed.
  my Bool $created-anew = False;

note "$*THREAD.id() Get sock, authenticate = $authenticate";

  # Get a free socket entry
  my MongoDB::SocketPool::Socket $found-socket;

  # Check all sockets first if timed out
  my Array[MongoDB::SocketPool::Socket] $skts = $!rw-sem.reader(
    's-select', { $!sockets; }
  );

  # check defined sockets if they must be cleared
  for @$skts -> $socket is rw {

    next unless $socket.defined;

    unless $socket.check-open {
      $socket = MongoDB::SocketPool::Socket;
      trace-message("Socket cleared for {$!name}");
    }
  }

  # Search for socket
  for @$skts -> $socket is rw {

    next unless $socket.defined;

    #if $socket.thread-id == $*THREAD.id() and $socket.server.name eq $!name {
    if $socket.server.name eq $!name {

      $found-socket = $socket;
      trace-message("Socket found for $!name");

      last;
    }
  }

  # If none is found insert a new Socket in the array
  unless $found-socket.defined {

    # search for an empty slot
    my Bool $slot-found = False;
    for @$skts -> $socket is rw {
      if not $socket.defined {
        $found-socket = $socket .= new( :$!host, :$!port); #(:server(self));
        $created-anew = True;
        $slot-found = True;
        trace-message("New socket inserted for $!name");
      }
    }

    # Or, when no empty slot id found, add the socket to the end
    if not $slot-found {
      $found-socket .= new( :$!host, :$!port); #(:server(self));
      $created-anew = True;
      $!sockets.push($found-socket);
      trace-message("New socket created for $!name");
    }
  }

  $!rw-sem.writer( 's-select', {$!sockets = $skts;});

#`{{
#TODO (from sockets) Sockets must initiate a handshake procedure when socket
# is opened. Perhaps not needed because the monitor is keeping touch and knows
# the type of the server which is communicated to the Server and Client object
#TODO When authentication is needed it must be done on every opened socket
#TODO check must be made on autenticate flag only and determined from server

  # We can only authenticate when all 3 data are True and when the socket is
  # created.
  if $created-anew and $authenticate {
    my MongoDB::Authenticate::Credential $credential =
      $!client.uri-obj.credential;

    if ?$credential.username and ?$credential.password {

      # get authentication mechanism
      my Str $auth-mechanism = $credential.auth-mechanism;
      if not $auth-mechanism {
        my Int $max-version = $!rw-sem.reader(
          's-status', {$!server-data<max-wire-version>}
        );
        $auth-mechanism = $max-version < 3 ?? 'MONGODB-CR' !! 'SCRAM-SHA-1';
        trace-message("Wire version is $max-version");
        trace-message("Authenticate with '$auth-mechanism'");
      }

      $credential.auth-mechanism(:$auth-mechanism);

      given $auth-mechanism {

        # Default in version 3.*
        when 'SCRAM-SHA-1' {

          my MongoDB::Authenticate::Scram $client-object .= new(
            :$!client, :db-name($credential.auth-source)
          );

          my Auth::SCRAM $sc .= new(
            :username($credential.username),
            :password($credential.password),
            :$client-object,
          );

          my $error = $sc.start-scram;
          if ?$error {
            fatal-message("Authentication fail for $credential.username(): $error");
          }

          else {
            trace-message("$credential.username() authenticated");
          }
        }

        # Default in version 2.* NOTE: will not be supported!!
        when 'MONGODB-CR' {

        }

        when 'MONGODB-X509' {

        }

        # Kerberos
        when 'GSSAPI' {

        }

        # LDAP SASL
        when 'PLAIN' {

        }

      } # given $auth-mechanism
    } # if ?$credential.username and ?$credential.password
  } # if $created-anew and $authenticate
}}

  # Return a usable socket which is opened and authenticated upon if needed.
  $found-socket;
}
}}

#-------------------------------------------------------------------------------
multi method raw-query (
  Str:D $full-collection-name, BSON::Document:D $query,
  Int :$number-to-skip = 0, Int :$number-to-return = 1,
  Bool :$authenticate = True, Bool :$time-query = False
  --> List
) {

  # Be sure the server is still active
  return ( BSON::Document, Duration.new(0)) unless $!server-is-registered;

  my BSON::Document $doc;
  my Duration $rtt;

  my MongoDB::Wire $w .= new;
  ( $doc, $rtt) = $w.query(
    $full-collection-name, $query,
    :$number-to-skip, :$number-to-return,
    :server(self), :$authenticate, :$time-query
  );

  ( $doc, $rtt);
}

#`{{
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method raw-query (
  Str:D $full-collection-name, BSON::Document:D $query,
  Int :$number-to-skip = 0, Int :$number-to-return = 1,
  Bool :$authenticate = True
  --> BSON::Document
) {
  # Be sure the server is still active
  return BSON::Document unless $!server-is-registered;

  debug-message("server directed query on collection $full-collection-name on server $!name");

  MongoDB::Wire.new.query(
    $full-collection-name, $query,
    :$number-to-skip, :$number-to-return,
    :server(self), :$authenticate, :!time-query
  );
}
}}

#-------------------------------------------------------------------------------
method !set-server-name ( --> Str ) {

#`{{
  my Str $name = $!server-name // '-';
  my Str $port = "$!server-port" // '-';

  # check for undefined name and/or port
  if $name eq '-' or $port eq '-' {
    $name = '-:-';
  }

  # check for ipv6 addresses
  elsif $name ~~ / ':' / {
    $name = [~] '[', $name, ']:', $port;
  }

  # ipv4 and domainnames are printed the same
  else {
    $name = [~] $name , ':', $port;
  }
}}

  my Str $name;

  # check for ipv6 addresses
  if $!host ~~ / ':' / {
    $name = [~] '[', $!host, ']:', $!port;
  }

  # ipv4 and domainnames are printed the same
  else {
    $name = [~] $!host , ':', $!port;
  }

  $name
}

#-------------------------------------------------------------------------------
# Forced cleanup on behalf of the client
method cleanup ( Str $client-key ) {

  # It's possible that server monitor is not defined when a server is
  # non existent or some other reason.
#  $!server-tap.close if $!server-tap.defined;

  # Because of race conditions it is possible that Monitor still requests
  # for sockets(via Wire) to get server information. Next variable must be
  # checked before proceding in get-socket(). But even then, the request
  # could be started just before this happens. Well anyways, when a socket is
  # returned to Wire for the final act, won't hurt because the mongod server
  # is not dead because of this cleanup. The data retrieved from the server
  # will not be processed anymore and in the next loop of Monitor it will see
  # that the server is un-registered.
  $!server-is-registered = False;
  my MongoDB::ObserverEmitter $event-manager .= new;
  $event-manager.unsubscribe-observer($!name ~ ' monitor data');
  $event-manager.emit( 'unregister server', self);

  # Clear all sockets
  my MongoDB::SocketPool $socket-pool .= instance;
#  $socket-pool.cleanup(:all);
  $socket-pool.cleanup($client-key);
#`{{
  $!rw-sem.writer( 's-select', {
      for @$!sockets -> $socket {
        next unless ?$socket;
      }
    }
  );
}}
  trace-message("Sockets cleared");

#  $!client = Nil;
#  $!sockets = Nil;
#  $!server-tap = Nil;
}
