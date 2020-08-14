#TL:1:MongoDB::Server::Socket

use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::Server::Socket

B<MongoDB::Server::Socket> is an encapsulation of B<IO::Socket::INET>. You can open, close, read and write.

Exceptions are thrown when operations on a socket fails.

=end pod

#-------------------------------------------------------------------------------
use MongoDB;
use MongoDB::Authenticate::Credential;
use MongoDB::Authenticate::Scram;
#use MongoDB::Client;
#use MongoDB::Database;
use MongoDB::Uri;

use BSON::Document;
#use Semaphore::ReadersWriters;
use Auth::SCRAM;

#-------------------------------------------------------------------------------
unit class MongoDB::SocketPool::Socket:auth<github:MARTIMM>;

has IO::Socket::INET $!socket;
has Bool $!is-open;
has Instant $!time-last-used;

#has MongoDB::Uri $!uri-obj;

#has MongoDB::Authenticate::Credential $credential;

#has Int $.thread-id;
#  has Bool $!must-authenticate;

#`{{
#TODO deprecate
has MongoDB::ServerClassType $.server;

#-------------------------------------------------------------------------------
#TODO deprecate
multi submethod BUILD ( MongoDB::ServerClassType:D :$!server ) {

  trace-message("open socket $!server.server-name(), $!server.server-port()");

  try {
    $!socket .= new( :host($!server.server-name), :port($!server.server-port));
    CATCH {
      default {
        # Retry for ipv6
        $!socket .= new(
          :host($!server.server-name),
          :port($!server.server-port),
          :family(PF_INET6)
        );
      }
    }
  }

  # we arrive here when there is no exception
  $!is-open = True;
  $!time-last-used = now;
};
}}

#-------------------------------------------------------------------------------
#multi
submethod BUILD ( Str:D :$host, Int:D :$port, MongoDB::Uri :$uri-obj? ) {

  trace-message("open socket $host, $port, authenticate: " ~ $uri-obj.defined);

  try {
    $!socket .= new( :$host, :$port);
    CATCH {
      default {
        trace-message('open socket to $host, $port, PF-INET: ' ~ .message);

        # Retry for ipv6, throws when fails
        $!socket .= new( :$host, :$port, :family(PF_INET6));
      }
    }
  }

  # we arrive here when there is no exception
  $!is-open = True;
  $!time-last-used = now;

  # authenticate if object exists.
  if $uri-obj.defined {
    # if credentials are defined, try to authenticate
    self.close unless self!authenticate($uri-obj);
  }
}

#-------------------------------------------------------------------------------
submethod DESTROY ( ) {

  # close connection is any
  $!socket.close if $!is-open;
}

#-------------------------------------------------------------------------------
method !authenticate ( MongoDB::Uri:D $uri-obj --> Bool ) {

  # assume failure
  my Bool $authenticated-ok = False;

  my MongoDB::Authenticate::Credential $credential = $uri-obj.credential;

  # this socket is for a server which is controlled by a client which has given
  # the uri object. the client has its key from this uri object.
  my Str $client-key = $uri-obj.keyed-uri;

  # username and password should be defined and non empty
  if ? $credential.username and ? $credential.password {

    # get authentication mechanism
    my Str $auth-mechanism = $credential.auth-mechanism // 'SCRAM-SHA-1';

#    $credential.auth-mechanism(:$auth-mechanism);

    given $auth-mechanism {

      # default in version 3.*
      when 'SCRAM-SHA-1' {

#        my MongoDB::Authenticate::Scram $client-object .= new(
#          :$!client, :db-name($credential.auth-source)
#        );
        my MongoDB::Authenticate::Scram $client-object .= new(
          MongoDB::Database.new(:name($credential.auth-source))
        );

        my Auth::SCRAM $sc .= new(
          :username($credential.username),
          :password($credential.password),
          :$client-object,
        );

        my $error = $sc.start-scram;
        if ?$error {
          error-message(
            "Authentication fail for $credential.username(): $error"
          );
        }

        else {
          trace-message("$credential.username() authenticated");
          $authenticated-ok = True;
        }
      }

      # since version 4.*
      when 'SCRAM-SHA-256' {
        warn-message(
          "Authentication mechanism 'SCRAM-SHA-256' is not yet supported"
        );
      }

      # removed from version 4.*. will not be supported!!
      when 'MONGODB-CR' {
        warn-message(
          "Authentication mechanism 'MONGODB-CR' will not be supported"
        );
      }

      when 'MONGODB-X509' {
        warn-message(
          "Authentication mechanism 'MONGODB-X509' is not yet supported"
        );
      }

      # Kerberos
      when 'GSSAPI' {
        warn-message(
          "Authentication mechanism 'GSSAPI' is not yet supported"
        );
      }

      # LDAP SASL
      when 'PLAIN' {
        warn-message(
          "Authentication mechanism 'PLAIN' is not yet supported"
        );
      }

    } # given $auth-mechanism
  } # if ?$credential.username and ?$credential.password


  $authenticated-ok
}

#-------------------------------------------------------------------------------
method check-open ( --> Bool ) {

#  return True if $!is-open;

  if (now - $!time-last-used) > MAX-SOCKET-UNUSED-OPEN {

    debug-message(
      "close socket, timeout after {now - $!time-last-used} sec"
    );

    $!socket.close;
    $!is-open = False;
  }

  $!is-open;
}

#-------------------------------------------------------------------------------
method send ( Buf:D $b --> Nil ) {

#  fatal-message("thread $*THREAD.id() is not owner of this socket")
#    unless $!thread-id == $*THREAD.id();

  fatal-message("socket is closed") unless $!socket.defined;

  trace-message("socket send, size: $b.elems()");
  $!socket.write($b);
  $!time-last-used = now;
}

#-------------------------------------------------------------------------------
method receive ( int $nbr-bytes --> Buf ) {

#  fatal-message("thread $*THREAD.id() is not owner of this socket")
#    unless $!thread-id == $*THREAD.id();

  fatal-message("socket not opened") unless $!socket.defined;

  my Buf $bytes = $!socket.read($nbr-bytes);
  $!time-last-used = now;
  trace-message(
    "socket receive, requested $nbr-bytes bytes, received $bytes.elems()"
  );

  $bytes;
}

#-----------------------------------------------------------------------------
# Read number of bytes from server. When not enough bytes are received
# an error is thrown.
method receive-check ( int $nbr-bytes --> Buf ) {

  fatal-message("socket is closed") unless $!socket.defined;

  my Buf $bytes = $!socket.read($nbr-bytes);
  if $bytes.elems == 0 {
    # No data, try again
    $bytes = $!socket.receive($nbr-bytes);
    fatal-message("No response from server") if $bytes.elems == 0;
  }

  if 0 < $bytes.elems < $nbr-bytes {
    # Not 0 but too little, try to get the rest of it
    $bytes.push($!socket.receive($nbr-bytes - $bytes.elems));
    fatal-message("Response corrupted") if $bytes.elems < $nbr-bytes;
  }

  trace-message("socket receive, received size $bytes.elems()");

  $!time-last-used = now;
  $bytes
}

#-------------------------------------------------------------------------------
method close ( ) {

#  fatal-message("thread $*THREAD.id() is not owner of this socket")
#    unless $!thread-id == $*THREAD.id();

  $!socket.close if $!socket.defined;
  $!socket = Nil;

  trace-message("Close socket");
  $!is-open = False;
  $!time-last-used = now;
}

#-------------------------------------------------------------------------------
method close-on-fail ( ) {

  # An Exception can be thrown and caught in another thread. When then a
  # socket must close it should be able to do so
  #fatal-message("thread $*THREAD.id() is not owner of this socket")
  #  unless $!thread-id == $*THREAD.id();

#  warn-message("close exception where thread $*THREAD.id() is not owner of this socket")
#    unless $!thread-id == $*THREAD.id();
  trace-message("'close' socket on failure");
  $!socket = Nil;
  $!is-open = False;
  $!time-last-used = now;
}

#-------------------------------------------------------------------------------
method cleanup ( ) {

  # closing a socket can throw exceptions
  try {
    if $!socket.defined {
      $!socket.close;
      $!socket = Nil;
#      trace-message(
#        "socket cleaned for $!server.name() in thread $!thread-id"
#      );
    }

    else {
      $!socket = Nil;
    }

    $!is-open = False;

    CATCH {
      $!socket = Nil;
      $!is-open = False;
    }
  }
}
