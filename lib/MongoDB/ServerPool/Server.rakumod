#TL:1:MongoDB::ServerPool::Server:

use v6;

use MongoDB;
#use MongoDB::Wire;
#use MongoDB::Client;
use MongoDB::Uri;
#use MongoDB::Server::Monitor;
use MongoDB::SocketPool;
use MongoDB::SocketPool::Socket;
#use MongoDB::Authenticate::Credential;
#use MongoDB::Authenticate::Scram;
use MongoDB::ObserverEmitter;

use BSON::Document;
use Semaphore::ReadersWriters;
#use Auth::SCRAM;

#-------------------------------------------------------------------------------
unit class MongoDB::ServerPool::Server:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
#TM:1:host:
# name and port is kept separated for use by Socket.
has Str $.host;

#TM:1:port:
has Int $.port;

#TM:1:name:
has Str $.name;

#TM:1:server-is-registered:
has Bool $.server-is-registered;
has Hash $!server-data;

# server status data. Must be protected by a semaphore because different threads
# may access the data. $!host and $!port is set when initialized, after that
# only read so no special handling needed.
has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
#TM:1:new(:$server-name):
multi submethod BUILD ( Str:D :$server-name! ) {

  if $server-name ~~ m/ '[' $<ip6addr> = ( .*? ) ']' / {
    my $h = $!host = $/<ip6addr>.Str;
    my Str $p = $server-name;
    $p ~~ s/'[' $h ']:'//;
    $!port = $p.Int;
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
#TM:1:!init:
method !init ( ) {

  # server status is unsetled
  $!server-data = %( :status(ST-Unknown), :!is-master, :error('') );

  $!rw-sem .= new;
  #$!rw-sem.debug = True;
  $!rw-sem.add-mutex-names(
    <server-data registered>, :RWPatternType(C-RW-WRITERPRIO)
  );

  $!server-is-registered = False;
  $!name = self!set-server-name;

  trace-message("Server object for $!name initialized");

  # Set the heartbeat frequency
  my MongoDB::ObserverEmitter $event-manager .= new;

  $event-manager.subscribe-observer(
    $!name ~ ' monitor data',
    -> Hash $monitor-data { self!process-monitor-data($monitor-data); },
    :event-key($!name ~ ' monitor data')
  );

  # Now we can register a server
  $event-manager.emit( 'register server', self);
  $!server-is-registered = True;
}

#-------------------------------------------------------------------------------
#TM:0:!process-monitor-data:
method !process-monitor-data ( Hash $monitor-data ) {

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

      ( $server-status, $is-master) = self!process-status($mdata);

      $!rw-sem.writer( 'server-data', {
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

    $!rw-sem.writer( 'server-data', {
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

  # the keyed uri is used to notify the proper client, there can be
  # more than one active
  my MongoDB::ObserverEmitter $notify-client;
  $notify-client.emit(
    $!name ~ ' process topology', ( $!name, $server-status, $is-master)
  );
}

#-------------------------------------------------------------------------------
#tm:0:!process-status:
method !process-status ( BSON::Document $mdata --> List ) {

  my Bool $is-master = False;
  my ServerType $server-status = ST-Unknown;
  my MongoDB::ObserverEmitter $notify-client;

#debug-message(
#  "Types: {$mdata<msg>:exists}, {$mdata<isreplicaset>:exists}, {? $mdata<setName>:exists}"
#);

  # Shard server
  if $mdata<msg>:exists and $mdata<msg> eq 'isdbgrid' {
    $server-status = ST-Mongos;
  }

  # Replica server in preinitialization state
  elsif $mdata<isreplicaset>:exists {
    $server-status = ST-RSGhost;
  }

  elsif $mdata<setName>:exists {
    $is-master = ? $mdata<ismaster>;
    if $is-master {
#debug-message("Types: is master");
      $server-status = ST-RSPrimary;
      $notify-client.emit(
        $!name ~ ' add servers', @($mdata<hosts>)
      ) if $mdata<hosts>:exists;
    }

    elsif $mdata<secondary>:exists {
#debug-message("Types: is secondary");
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
#debug-message("sts $server-status, $is-master");

  ( $server-status, $is-master)
}

#-------------------------------------------------------------------------------
#TM:1:get-data:
# if 0 items, return all data in a Hash
# if one item, return value of item
# if more items, return items and values in a Hash
method get-data ( *@items --> Any ) {

#note "its: @items.perl()";
  my Any $data;

  if @items.elems == 0 {
    $data = $!rw-sem.reader( 'server-data', {$!server-data});
    trace-message("$!host:$!port return all data: $data.perl()");
  }

  elsif @items.elems == 1 {
    $data = $!rw-sem.reader( 'server-data', {$!server-data{@items[0]}});
    trace-message(
      "$!host:$!port return data item: @items[0], $data.perl()"
    );
  }

  else {
    my $sd = $!rw-sem.reader( 'server-data', {$!server-data{@items}});

    $data = %(%(@items Z=> @$sd).grep({.value.defined}));
    trace-message(
      "$!host:$!port return data items: @items.perl(), $data.perl()"
    );
  }

  $data
}

#-------------------------------------------------------------------------------
#TM:1:set-data:
method set-data ( *%items ) {

  my $sd = $!rw-sem.writer( 'server-data', {
      $!server-data = %( |$!server-data, |%items);
    }
  );

  trace-message("$!host:$!port data modified: $sd.perl()");
}

#-------------------------------------------------------------------------------
#TM:0:get-socket:
method get-socket ( MongoDB::Uri :$uri-obj --> MongoDB::SocketPool::Socket ) {
  trace-message("get socket $!host:$!port, $uri-obj.gist()");

  my MongoDB::SocketPool $socket-pool .= instance;
  $socket-pool.get-socket( self.host, self.port, :$uri-obj);
}

#-------------------------------------------------------------------------------
#TM:0:close-socket:
method close-socket ( MongoDB::Uri :$uri-obj ) {

  trace-message("close socket $uri-obj.gist()");

  my MongoDB::SocketPool $socket-pool .= instance;
  $socket-pool.cleanup( $uri-obj.client-key, $!host, $!port);
}

#-------------------------------------------------------------------------------
#tm:1:!set-server-name
method !set-server-name ( --> Str ) {

  my Str $name;

  # check for ipv6 addresses
  if $!host ~~ / ':' / {
    $name = [~] '[', $!host, ']:', $!port;
  }

  # ipv4 and domainnames are printed the same
  else {
    $name = [~] $!host, ':', $!port;
  }

  $name
}

#-------------------------------------------------------------------------------
#tm:0:cleanup:
# Forced cleanup on behalf of the client
method cleanup ( Str $client-key ) {

  # Because of race conditions it is possible that Monitor still requests
  # for sockets(via Wire) to get server information. Next variable must be
  # checked before proceding in get-socket(). But even then, the request
  # could be started just before this happens. Well anyways, when a socket is
  # returned to Wire for the final act, won't hurt because the mongod server
  # is not dead because of this cleanup. The data retrieved from the server
  # will not be processed anymore and in the next loop of Monitor it will see
  # that the server is un-registered.
  $!rw-sem.writer( 'registered', {$!server-is-registered = False;});

  my MongoDB::ObserverEmitter $event-manager .= new;
  $event-manager.unsubscribe-observer($!name ~ ' monitor data');
  $event-manager.emit( 'unregister server', self);

  # Clear all sockets
  my MongoDB::SocketPool $socket-pool .= instance;
  $socket-pool.cleanup( $client-key, $!host, $!port);
  trace-message("Sockets cleared for $client-key");
}
