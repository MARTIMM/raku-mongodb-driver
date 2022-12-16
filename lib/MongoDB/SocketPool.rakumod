#TL:1:MongoDB::SocketPool:
use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::SocketPool

B<MongoDB::SocketPool> provides a way to get a socket from a pool of sockets using a hostname and portnumber.

Its purpose is to reuse sockets whithout reconnectiing all the time and authenticating when needed.

Exceptions are thrown when opening a socket fails.

Several sockets must possibly be created for one server. The purpose of this is to;

=item Distinguish between several client objects.
=item With or without authentication for several credentials and mechanisms.

=head2 Example

my MongoDB::SocketPool $sockets;
$sockets .= instance;
my MongoDB::Socket $socket = $sockets.get-socket( 'localhost', 27017);
$socket.send($buffer);
$buffer = $socket.receive(20);
$sockets.cleanup( 'localhost', 27017);

=end pod

#-------------------------------------------------------------------------------
use MongoDB;
use MongoDB::Uri;
use MongoDB::SocketPool::Socket;

use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit class MongoDB::SocketPool:auth<github:MARTIMM>;

my MongoDB::SocketPool $instance;

# servers can have more opened sockets to control connections with or without
# authentication and with different credentials if authenticated. And different
# clients using the same servers. There is only one set of credentials per uri.
# if there is no authentication, username is set to an empty string and uri
# will not be set.

# ?? $!socket-info{client-key}{host port}{username}<socket> = socket
# ?? $!socket-info{client-key}{host port}{username}<uri> = uri-obj
# $!socket-info{client-key}{host port}{username} = socket
has Hash $!socket-info;

has Semaphore::ReadersWriters $!rw-sem;

#-------------------------------------------------------------------------------
#tm:1:BUILD:
submethod BUILD ( ) {
  trace-message("socket pool initialized");
  $!socket-info = {};

  $!rw-sem .= new;
  #$rw-sem.debug = True;
  $!rw-sem.add-mutex-names( <socketpool>, :RWPatternType(C-RW-WRITERPRIO));
}

#-------------------------------------------------------------------------------
#tm:1:new:
method new ( ) { !!! }

#-------------------------------------------------------------------------------
#tm:1:instance():
method instance ( --> MongoDB::SocketPool ) {
  $instance //= self.bless;

  $instance
}

#-------------------------------------------------------------------------------
#tm:1:get-socket:
# Getting a socket will return an opened socket. It will first search for an
# existing one, if not found creates a new and stores it with the current
# thread id.
method get-socket (
  Str:D $host, Int:D $port, MongoDB::Uri :$uri-obj
  --> MongoDB::SocketPool::Socket
) {

  my MongoDB::SocketPool::Socket $socket;
  my Str $client-key;
  my Str $username;
#`{{
  state Int $cleanup-count = 1;

  # every ten times a cleanup check is done on all ports. get-socket is called
  # regularly from Monitor.
  if $cleanup-count > 10 {
    $cleanup-count = 0;

    my Hash $si = $!rw-sem.writer( 'socketpool', { $!socket-info; });

    for $si.keys -> $client {
      for $si{$client}.keys -> $server-name {
        for $si{$client}{$server-name}.keys -> $un {
          my $s = $si{$client}{$server-name}{$un};
          $si{$client}{$server-name}{$un}:delete unless $s.check-open;
        }
      }
    }
  }
  $cleanup-count++;
}}

#  if $uri-obj.defined {
    $client-key = $uri-obj.client-key;
    $username = $uri-obj.credential.username;
#`{{
  }

  # no uri object - client key must be generated and mostly comes from
  # monitor which does not get a uri object because it does its checks
  # for all servers from several clients whithout authenticating.
  else {
    $client-key = '__MONITOR__CLIENT_KEY__';
    $username = '';
  }
}}

  trace-message("get-socket: $host, $port, $username, Client key: $client-key");

  $!rw-sem.writer( 'socketpool', {
      $!socket-info{$client-key} = %()
        unless $!socket-info{$client-key}:exists;

      $!socket-info{$client-key}{"$host $port"} = %()
        unless $!socket-info{$client-key}{"$host $port"}:exists;
    }
  );

  if $!rw-sem.reader( 'socketpool', {
      $!socket-info{$client-key}{"$host $port"}{$username}:exists; }
  ) {
    $socket = $!rw-sem.reader( 'socketpool', {
        $!socket-info{$client-key}{"$host $port"}{$username};
      }
    );

    trace-message("socket found in pool: server $host:$port, user '$username', sock id $socket.sock-id()");
  }

  # check if there is a socket and not closed
  if !($socket.defined and $socket.check-open) {
    if ? $username {
      $socket .= new( :$host, :$port, :$uri-obj);

      trace-message(
        "socket created: server $host:$port, user '$username' sock id $socket.sock-id() " ~ $socket.is-open ?? '' !! 'failed to open'
      );

      $socket = Nil unless $socket.is-open;
    }

    else {
      $socket .= new( :$host, :$port);
      trace-message("socket created: server $host:$port sock id $socket.sock-id()");
    }

    if $socket {
      $!rw-sem.writer( 'socketpool', {
          $!socket-info{$client-key}{"$host $port"}{$username} = $socket;
        }
      );
    }
  }

  $socket
}

#-------------------------------------------------------------------------------
#tm:1:cleanup:
# close and remove a socket belonging to the server on the current thread
method cleanup ( Str $client-key, Str $server-name ) {
#note "c: $client-key, $server-name, {$!socket-info{$client-key}{$server-name}//'-'}";

  $!rw-sem.writer( 'socketpool', {
      my Hash $info-cl-srv =
        $!socket-info{$client-key}{$server-name}:delete // %();
trace-message("$server-name: $info-cl-srv.gist");

      for $info-cl-srv.keys -> $un {
        my $s = $info-cl-srv{$un};
        $s.close;

        if ? $un {
          trace-message("cleanup socket for server $server-name and user $un");
        }

        else {
          trace-message("cleanup socket for server $server-name");
        }
      }
    }
  );
}

#-------------------------------------------------------------------------------
