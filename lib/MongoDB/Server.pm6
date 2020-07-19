use v6;

use MongoDB;
use MongoDB::Uri;
use MongoDB::Wire;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;
use MongoDB::Authenticate::Credential;
use MongoDB::Authenticate::Scram;
use MongoDB::ObserverEmitter;

use BSON::Document;
use Semaphore::ReadersWriters;
use Auth::SCRAM;

#-------------------------------------------------------------------------------
unit class MongoDB::Server:auth<github:MARTIMM>;

enum ServerDescription <
  Srv-address Srv-error Srv-roundTripTime Srv-lastWriteDate Srv-opTime
  Srv-type Srv-minWireVersion, Srv-maxWireVersion Srv-me Srv-hosts
  Srv-passives Srv-arbiters Srv-tags Srv-setName Srv-setVersion
  Srv-electionId Srv-primary Srv-lastUpdateTime
  Srv-logicalSessionTimeoutMinutes Srv-topologyVersion
>;
has Array $server-description = [];

# name and port is separated for use by Socket.
has Str $.server-name;
has PortType $.server-port;

has ClientType $.client;

has Array[MongoDB::Server::Socket] $!sockets;
has Bool $!server-is-registered;

# server status data. Must be protected by a semaphore because of a thread
# handling monitoring data.
has Hash $!server-sts-data;
has Semaphore::ReadersWriters $!rw-sem;
#has Tap $!server-tap;

# part of key for observer keys
has Str $!client-key;
has Str $!server-key;
#-------------------------------------------------------------------------------
submethod BUILD ( ClientType:D :$!client, Str:D :$server-name ) {

  # server status is unsetled
  $!server-sts-data = { :status(ST-Unknown), :!is-master, :error('') };

  $!rw-sem .= new;
#    $!rw-sem.debug = True;
  $!rw-sem.add-mutex-names(
    <s-select s-status>, :RWPatternType(C-RW-WRITERPRIO)
  );

  $!sockets = Array[MongoDB::Server::Socket].new;
  $!server-is-registered = False;

  # save name and port of the server. Servername and port are always
  # 'hostname:port' format, even when ipv6. The port number is always
  # present at this point, extracting it from the end from the spec.
  my Int $port = $!server-port = [$server-name.split(':')].pop.Int;
  $!server-name = $server-name;
  $!server-name ~~ s/ ':' $port $//;

  # Remove the brackets if they are there. ipv6 addresses have them.
  $!server-name ~~ s/^ '[' //;
  $!server-name ~~ s/ ']' $//;

  trace-message("Server object for {self.name} initialized");

  # set the heartbeat frequency
  my MongoDB::ObserverEmitter $event-manager .= new;

  # observe results from monitor only for this particular server. use the
  # key generated in the uri object and the servername to prevent other
  # servers to interprete data not meant for them.
  $!client-key = $!client.uri-obj.keyed-uri;
  $!server-key = $!client.uri-obj.keyed-uri ~ self.name;
  $event-manager.subscribe-observer(
    $!server-key ~ ' monitor data',
    -> Hash $monitor-data { self!process-monitor-data($monitor-data); },
    :event-key($!server-key ~ ' monitor data')
  );

  # now we can register a server
#note "Register a server: {self.name()}";
  $event-manager.emit( 'register server', self);
  $!server-is-registered = True;
}

#-------------------------------------------------------------------------------
method !process-monitor-data ( Hash $monitor-data ) {

  my Bool $is-master = False;
  my ServerType $server-status = ST-Unknown;

  # test monitor defined boolean field ok
  if $monitor-data<ok> {

    # used to get a socket and decide on type of authentication
    my $mdata = $monitor-data<monitor>;

    # test mongod server defined field ok for state of returned document
    # this is since newer servers return info about servers going down
    if ?$mdata and $mdata<ok>:exists and $mdata<ok> == 1e0 {
#note "MData: $monitor-data.perl()";
      ( $server-status, $is-master) = self!process-status($mdata);

      $!rw-sem.writer( 's-status', {
          $!server-sts-data = {
            :status($server-status), :$is-master, :error(''),
            :max-wire-version($mdata<maxWireVersion>.Int),
            :min-wire-version($mdata<minWireVersion>.Int),
            :weighted-mean-rtt-ms($monitor-data<weighted-mean-rtt-ms>),
          }
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
          $!server-sts-data<error> = $monitor-data<reason>;
        }

        else {
          $!server-sts-data<error> = 'Server did not respond';
        }

        $!server-sts-data<is-master> = False;
        $!server-sts-data<status> = ST-Unknown;

        ( $server-status, $is-master) = ( ST-Unknown, False);

      } # writer block
    ); # writer
  } # else

  # Set the status with the new value
  info-message("Server status of {self.name()} is $server-status");

  # Let the client find the topology using all found servers
  # in the same rhythm as the heartbeat loop of the monitor
  # (of each server)
  #$!client.process-topology;

  # the keyed uri is used to notify the proper client, there can be
  # more than one active
  my MongoDB::ObserverEmitter $notify-client;
  $notify-client.emit(
    $!client-key ~ ' process topology',
    ( self.name, $server-status, $is-master)
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
      #$!client.add-servers([|@($mdata<hosts>),]) if $mdata<hosts>:exists;
      $notify-client.emit(
        $!client-key ~ ' add servers', @($mdata<hosts>)
      ) if $mdata<hosts>:exists;
    }

    elsif ? $mdata<secondary> {
      $server-status = ST-RSSecondary;
      #$!client.add-servers([$mdata<primary>,]) if $mdata<primary>:exists;
      $notify-client.emit(
        $!client-key ~ ' add servers', @($mdata<primary>)
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
method get-status ( --> Hash ) {

  $!rw-sem.reader( 's-status', { $!server-sts-data } );
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
# By default authentiction is needed when user/password info is found in the
# uri data. Monitor however, does not need this and therefore monitor is
# using raw-query with :!authenticate.

# When a new socket is opened and it fails, it will not be stored because the
# thrown exception is catched in Wire where the call is done. This also means
# that calling new must be done outside any semaphore locks

method get-socket ( Bool :$authenticate = True --> MongoDB::Server::Socket ) {

  # If server is not registered then the server is cleaned up
  return MongoDB::Server::Socket unless $!server-is-registered;

  # Use return value to see if authentication is needed.
  my Bool $created-anew = False;

#note "$*THREAD.id() Get sock, authenticate = $authenticate";

  # Get a free socket entry
  my MongoDB::Server::Socket $found-socket;

  # Check all sockets first if timed out
  my Array[MongoDB::Server::Socket] $skts = $!rw-sem.reader(
    's-select', { $!sockets; }
  );

  # check defined sockets if they must be cleared
  for @$skts -> $socket is rw {

    next unless $socket.defined;

    if $socket.check {
      $socket = MongoDB::Server::Socket;
      trace-message("Socket cleared for {self.name}");
    }
  }

  # Search for socket
  for @$skts -> $socket is rw {

    next unless $socket.defined;

    if $socket.thread-id == $*THREAD.id()
       and $socket.server.name eq self.name {

      $found-socket = $socket;
      trace-message("Socket found for {self.name}");

      last;
    }
  }

  # If none is found insert a new Socket in the array
  if not $found-socket.defined {

    # search for an empty slot
    my Bool $slot-found = False;
    for @$skts -> $socket is rw {
      if not $socket.defined {
        $found-socket = $socket .= new(:server(self));
        $created-anew = True;
        $slot-found = True;
        trace-message("New socket inserted for {self.name}");
      }
    }

    # Or, when no empty slot id found, add the socket to the end
    if not $slot-found {
      $found-socket .= new(:server(self));
      $created-anew = True;
      $!sockets.push($found-socket);
      trace-message("New socket created for {self.name}");
    }
  }

  $!rw-sem.writer( 's-select', {$!sockets = $skts;});

#TODO (from sockets) Sockets must initiate a handshake procedure when socket is opened. Perhaps
#  not needed because the monitor is keeping touch and known the type of the
#  server which is communicated to the Server and Client object
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
          's-status', {$!server-sts-data<max-wire-version>}
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

  # Return a usable socket which is opened and authenticated upon if needed.
  $found-socket;
}

#-------------------------------------------------------------------------------
multi method raw-query (
  Str:D $full-collection-name, BSON::Document:D $query,
  Int :$number-to-skip = 0, Int :$number-to-return = 1,
  Bool :$authenticate = True, Bool :$timed-query!
  --> List
) {

  # Be sure the server is still active
  return ( BSON::Document, 0) unless $!server-is-registered;

  my BSON::Document $doc;
  my Duration $rtt;

  ( $doc, $rtt) = MongoDB::Wire.new.timed-query(
    $full-collection-name, $query,
    :$number-to-skip, :$number-to-return,
    :server(self), :$authenticate
  );

  ( $doc, $rtt // Duration.new(0));
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method raw-query (
  Str:D $full-collection-name, BSON::Document:D $query,
  Int :$number-to-skip = 0, Int :$number-to-return = 1,
  Bool :$authenticate = True
  --> BSON::Document
) {
  # Be sure the server is still active
  return BSON::Document unless $!server-is-registered;

  debug-message("server directed query on collection $full-collection-name on server {self.name}");

  MongoDB::Wire.new.query(
    $full-collection-name, $query,
    :$number-to-skip, :$number-to-return,
    :server(self), :$authenticate
  );
}

#-------------------------------------------------------------------------------
method name ( --> Str ) {

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

  $name
}

#-------------------------------------------------------------------------------
# Forced cleanup
method cleanup ( ) {

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
  $event-manager.unsubscribe-observer($!server-key ~ ' monitor data');
  $event-manager.emit( 'unregister server', self);

  # Clear all sockets
  $!rw-sem.writer( 's-select', {
      for @$!sockets -> $socket {
        next unless ?$socket;
        $socket.cleanup;
        trace-message("socket cleaned for $socket.server.name() in thread $socket.thread-id()");
      }
    }
  );

  trace-message("Sockets cleared");

  $!client = Nil;
  $!sockets = Nil;
#  $!server-tap = Nil;
}
