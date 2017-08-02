use v6;

use MongoDB;
use MongoDB::Wire;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;
use MongoDB::Authenticate::Credential;
use MongoDB::Authenticate::Scram;

use BSON::Document;
use Semaphore::ReadersWriters;
use Auth::SCRAM;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
class Server {

  # Used by Socket
  has Str $.server-name;
  has PortType $.server-port;

  has ClientType $!client;

  # As in MongoDB::Uri without servers name and port. So there are
  # database, username, password and options
  has MongoDB::Authenticate::Credential $!credential;

  has Array[MongoDB::Server::Socket] $!sockets;
  has Bool $!server-is-registered;

  # Server status data. Must be protected by a semaphore because of a thread
  # handling monitoring data.
  has Hash $!server-sts-data;
  has Semaphore::ReadersWriters $!rw-sem;
  has Tap $!server-tap;

  #-----------------------------------------------------------------------------
  # Server must make contact first to see if server exists and reacts. This
  # must be done in the background so Client starts this process in a thread.
  #
  submethod BUILD (
    ClientType:D :$!client,
    Str:D :$server-name
  ) {

    $!rw-sem .= new;
#    $!rw-sem.debug = True;
    $!rw-sem.add-mutex-names(
      <s-select s-status>, :RWPatternType(C-RW-WRITERPRIO)
    );

    $!credential := $!client.credential;

    $!sockets = Array[MongoDB::Server::Socket].new;
    $!server-is-registered = False;

    # Save name and port of the server
    ( my $host, my $port) = split( ':', $server-name);
    $!server-name = $host;
    $!server-port = $port.Int;

    $!server-sts-data = {
      :status(SS-NotSet), :!is-master, :error(''),
    };
  }

  #-----------------------------------------------------------------------------
  # Server initialization
  method server-init ( ) {

    # Start monitoring
    my MongoDB::Server::Monitor $m .= instance;
    $m.set-heartbeat($!client.heartbeat-frequency-ms);
    $m.register-server(self);
    $!server-is-registered = True;

    # Tap into monitor data
    $!server-tap = self.tap-monitor( -> Hash $monitor-data {

#note "\n$*THREAD.id() In server, data from Monitor: ", ($monitor-data // {}).perl;

        # See also https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/server-discovery-and-monitoring.rst#parsing-an-ismaster-response
        if $monitor-data<server-name> eq self.name {
#        try {

          my Bool $is-master = False;
          my ServerStatus $server-status = SS-Unknown;

          # test monitor defined boolean field ok
          if $monitor-data<ok> {

            # Used to get a socket an decide on type of authentication
            my $mdata = $monitor-data<monitor>;

            # test mongod server defined field ok for state of returned document
            # this is since newer servers return info about servers going down
            if $mdata<ok> == 1e0 {
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
                $!server-sts-data<status> = SS-Unknown;

              } # writer block
            ); # writer
          } # else

          # Set the status with the new value
          info-message("Server status of {self.name()} is $server-status");

          # Let the client find the topology using all found servers
          # in the same rhythm as the heartbeat loop of the monitor
          # (of each server)
          $!client.process-topology;

#`{{
          CATCH {
            default {
              .note;

              # Set the status with the  value
              error-message("{.message}, {self.name()} {SS-Unknown}");
              $!rw-sem.writer( 's-status', {
                  $!server-sts-data = {
                    :status(SS-Unknown), :!is-master, :error(.message),
                  }
                } # block
              ); # writer
            } # default
          } # CATCH
        } # try
}}
        } # if $monitor-data<server> eq self.name

      } # tap block
    ); # tap
  } # method

  #-----------------------------------------------------------------------------
  method !process-status ( BSON::Document $mdata --> List ) {

    my Bool $is-master = False;
    my ServerStatus $server-status = SS-Unknown;

    # Shard server
    if $mdata<msg>:exists and $mdata<msg> eq 'isdbgrid' {
      $server-status = SS-Mongos;
    }

    # Replica server in preinitialization state
    elsif ? $mdata<isreplicaset> {
      $server-status = SS-RSGhost;
    }

    elsif ? $mdata<setName> {
      $is-master = ? $mdata<ismaster>;
      if $is-master {
        $server-status = SS-RSPrimary;
        $!client.add-servers([|@($mdata<hosts>),]) if $mdata<hosts>:exists;
      }

      elsif ? $mdata<secondary> {
        $server-status = SS-RSSecondary;
        $!client.add-servers([$mdata<primary>,]) if $mdata<primary>:exists;
      }

      elsif ? $mdata<arbiterOnly> {
        $server-status = SS-RSArbiter;
      }

      else {
        $server-status = SS-RSOther;
      }
    }

    else {
      $server-status = SS-Standalone;
      $is-master = ? $mdata<ismaster>;
    }

    ( $server-status, $is-master);
  }

  #-----------------------------------------------------------------------------
  method get-status ( --> Hash ) {

    $!rw-sem.reader( 's-status', { $!server-sts-data } );
  }

  #-----------------------------------------------------------------------------
  # Make a tap on the Supply. Use act() for this so we are sure that only this
  # code runs whithout any other parrallel threads.
  #
  method tap-monitor ( |c --> Tap ) {

    MongoDB::Server::Monitor.instance.get-supply.tap(|c);
  }

  #-----------------------------------------------------------------------------
  # Search in the array for a closed Socket.
  # By default authentiction is needed when user/password info is found in the
  # uri data. Monitor, however does not need this so therefore it is made
  # optional.

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
      for @$skts -> $socket {
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

#TODO check must be made on autenticate flag only and determined from server
    # We can only authenticate when all 3 data are True and when the socket is
    # created.
    if $created-anew and $authenticate
       and (? $!client.uri-data<username> or ? $!client.uri-data<password>) {

      # get authentication mechanism
      my Str $auth-mechanism = $!credential.auth-mechanism;
      if not $auth-mechanism {
        my Int $max-version = $!rw-sem.reader(
          's-status', {$!server-sts-data<max-wire-version>}
        );
        $auth-mechanism = $max-version < 3 ?? 'MONGODB-CR' !! 'SCRAM-SHA-1';
        trace-message("Wire version is $max-version");
        trace-message("Authenticate with '$auth-mechanism'");
      }

      $!credential.auth-mechanism(:$auth-mechanism);

      given $auth-mechanism {

        # Default in version 3.*
        when 'SCRAM-SHA-1' {

          my MongoDB::Authenticate::Scram $client-object .= new(
            :$!client, :db-name($!client.uri-data<database>)
          );

          my Auth::SCRAM $sc .= new(
            :username($!client.uri-data<username>),
            :password($!client.uri-data<password>),
            :$client-object,
          );

          my $error = $sc.start-scram;
          if ?$error {
            fatal-message("Authentication fail for $!client.uri-data<username>: $error");
          }

          else {
            trace-message("$!client.uri-data<username> authenticated");
          }
        }

        # Default in version 2.*
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
      }
    }

    # Return a usable socket which is opened and authenticated upon if needed.
    $found-socket;
  }

  #-----------------------------------------------------------------------------
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
      :$number-to-skip, :number-to-return,
      :server(self), :$authenticate
    );

    ( $doc, $rtt // 0);
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
      :$number-to-skip, :number-to-return,
      :server(self), :$authenticate
    );
  }

  #-----------------------------------------------------------------------------
  method name ( --> Str ) {

    return [~] $!server-name // '-', ':', $!server-port // '-';
  }

  #-----------------------------------------------------------------------------
  # Forced cleanup
  method cleanup ( ) {

    # Its possible that server monitor is not defined when a server is
    # non existent or some other reason.
    $!server-tap.close if $!server-tap.defined;

    # Because of race conditions it is possible that Monitor still requests
    # for sockets(via Wire) to get server information. Next variable must be
    # checked before proceding in get-socket(). But even then, the request
    # could be started just before this happens. Well anyways, when a socket is
    # returned to Wire for the final act, won't hurt because the mongod server
    # is not dead because of this cleanup. The data retrieved from the server
    # just not processed anymore and in the next loop of Monitor it will see
    # that the server is un-registered.
    $!server-is-registered = False;
    MongoDB::Server::Monitor.instance.unregister-server(self);

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
    $!server-tap = Nil;
  }
}
