#TL:1:MongoDB::Server::Socket

use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::Server::Socket

B<MongoDB::Server::Socket> is an encapsulation of B<IO::Socket::INET>. You can open, close, read and write.

Exceptions are thrown when operations on a socket fails.

=end pod

#-------------------------------------------------------------------------------
use NativeCall;

use MongoDB;
use MongoDB::Authenticate::Credential;
use MongoDB::Authenticate::Scram;
use MongoDB::Uri;

use BSON::Document;
use Semaphore::ReadersWriters;
use Auth::SCRAM;

use OpenSSL;
use OpenSSL::SSL;
use OpenSSL::NativeLib;

#use MongoDB::SocketPool::SocketIO;

#-------------------------------------------------------------------------------
sub SSL_use_PrivateKey_file( OpenSSL::SSL::SSL, Str, int32 --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_use_certificate_file( OpenSSL::SSL::SSL, Str, int32 --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_check_private_key( OpenSSL::SSL::SSL --> int32 )
  is native(&ssl-lib)
  {*}

#-------------------------------------------------------------------------------
unit class MongoDB::SocketPool::Socket:auth<github:MARTIMM>;
#also does MongoDB::SocketPool::SocketIO;

#has IO::Socket::INET $!socket;

#has Bool $.is-open;
#has Instant $!time-last-used;
#has Semaphore::ReadersWriters $.rw-sem;

my $sock-count = 0;
#has Int $.sock-id;

has Bool $!do-tls = False;

# Following attributes are filled from URI options when tls is requested
has $!certificate-file = '';
has $!privatekey-file = '';

has IO::Socket::INET $!socket;
has OpenSSL $!ssl;

has Hash $!options;

has Bool $.is-open;
has Instant $!time-last-used;
has Semaphore::ReadersWriters $.rw-sem;
has Int $.sock-id;

#-------------------------------------------------------------------------------
#tm:1:new():
submethod BUILD ( Str:D :$host, Int:D :$port, MongoDB::Uri :$uri-obj ) {

  # initialize mutexes
  $!rw-sem .= new;
#    $!rw-sem.debug = True;

  # protect $!socket and $!time-last-used. $!is-open is protected using 'socket'
  $!rw-sem.add-mutex-names( <socket time>, :RWPatternType(C-RW-WRITERPRIO));

  trace-message(
    "open socket $host, $port, authenticate user: " ~ (
      $uri-obj.defined ?? $uri-obj.credential.username !! '<no authentication>'
    )
  );

  self.check-tls($uri-obj.options);
  self.connect( $host, $port);
#`{{
  try {
    $!socket = IO::Socket::INET.new( :$host, :$port);
    CATCH {
      default {
        trace-message("open socket to $host, $port, PF-INET: " ~ .message);

        # Retry for ipv6, throws when fails
        $!socket = IO::Socket::INET.new( :$host, :$port, :family(PF_INET6));
      }
    }
  }
}}

  # we arrive here when there is no exception
  $!is-open = True;
  $!sock-id = $sock-count++;
  $!time-last-used = now;

  # authenticate if object exists and username/password not empty.
  if $uri-obj.defined and
     ?$uri-obj.credential.username and
     ?$uri-obj.credential.password {

    self.close unless self!authenticate( $host, $port, $uri-obj);
  }

  # can be closed when authentication failed
  if $!is-open {
    trace-message(
      "socket id: $!sock-id, for $host, $port, authenticate user: " ~ (
        $uri-obj.defined ?? $uri-obj.credential.username !! '<no authentication>'
      )
    );
  }

  else {
    trace-message(
      "socket id: $!sock-id, for $host, $port, authenticate user " ~ $uri-obj.credential.username ~ ' failed'
    );
  }
}

#-------------------------------------------------------------------------------
#tm:0:DESTROY:
submethod DESTROY ( ) {

  # close connection if open
  $!socket.close if $!is-open;
}

#-------------------------------------------------------------------------------
#tm:0:!authenticate:new():
# Try to authenticate if credentials are defined and not empty (both
# username and password = '') in which case authentication will be successful.
method !authenticate (
  Str:D $host, Int:D $port, MongoDB::Uri:D $uri-obj --> Bool
) {

  # assume failure
  my Bool $authenticated-ok = False;

#  my MongoDB::Authenticate::Credential $credential = $uri-obj.credential;

  # this socket is for a server which is controlled by a client which has given
  # the uri object. the client has its key from this uri object.
#  my Str $client-key = $uri-obj.client-key;

  # username and password should be defined and non empty
#  if ? $credential.username and ? $credential.password {
#note "cred: $credential.username(), $credential.password()";

    # get authentication mechanism
    my Str $auth-mechanism = ?$uri-obj.credential.auth-mechanism
                             ?? $uri-obj.credential.auth-mechanism
                             !! 'SCRAM-SHA-1';
#note "mech: $auth-mechanism";

#    $credential.auth-mechanism(:$auth-mechanism);

    given $auth-mechanism {

      # default in version 3.*
      when 'SCRAM-SHA-1' {
        self!scram-authenticate( $host, $port, $uri-obj, 1);
      }

      # since version 4.*
      when 'SCRAM-SHA-256' {
        self!scram-authenticate( $host, $port, $uri-obj, 256);
#`{{
        warn-message(
          "Authentication mechanism 'SCRAM-SHA-256' is not yet supported"
        );
}}
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
#  } # if ?$credential.username and ?$credential.password

  $authenticated-ok
}

#-------------------------------------------------------------------------------
method !scram-authenticate (
  Str:D $host, Int:D $port, MongoDB::Uri:D $uri-obj, Int:D $sha-type
  --> Bool
) {
  my Bool $authenticated-ok = False;
  my MongoDB::Authenticate::Credential $credential = $uri-obj.credential;

  # next is done to break circular dependency
  require ::('MongoDB::Database');

  # prevent authentication on the socket used by the authentication process
  my $uo = $uri-obj.clone-without-credential;
  my $database = ::('MongoDB::Database').new(
    :name($credential.auth-source), :uri-obj($uo)
  );

note "$?LINE: $host, $port, $sha-type";

  my MongoDB::Authenticate::Scram $client-object .= new(
    :$database, :$sha-type
  );

  my Auth::SCRAM $sc .= new(
    :username($credential.username),
    :password($credential.password),
    :$client-object,
  );

  # Next call will startup a conversation with the server to authenticate
  # the user. In that process, it opens another socket which must be
  # used later for the database operations done by that user. However,
  # the current socket selected by the socketpool has the username which
  # get selected later. To remedy this, the start-scram() should take
  # the current one (this one) or after the process, copy the data into
  # this one.
  my $error = $sc.start-scram;
  if ?$error {
    error-message(
      "Authentication fail for $credential.username(): $error"
    );
  }

  else {
    trace-message("$credential.username() authenticated");
    $authenticated-ok = True;

    # get the socket created by the authentication process. we should
    # get the same socket when the same uri object is used.
    require ::('MongoDB::SocketPool');
    my MongoDB::SocketPool::Socket $s =
      ::('MongoDB::SocketPool').instance.get-socket(
        $host, $port, :uri-obj($uo)
      );

    # copy the socket from that process and then invalidate the other
    $!rw-sem.writer( 'socket', {
        $!socket.close;
        $!socket = $s.socket;
      }
    );
    $s.invalidate(:used-to-authenticate);
  }

  $authenticated-ok
}

#-------------------------------------------------------------------------------
method check-tls ( Hash $!options ) {
  $!do-tls = True if ?$!options<tls>;

  # initialize mutexes
  $!rw-sem .= new;
#    $!rw-sem.debug = True;

  # protect $!socket and $!time-last-used. $!is-open is protected using 'socket'
  $!rw-sem.add-mutex-names( <socket time>, :RWPatternType(C-RW-WRITERPRIO));

#`{{
    # Check if certificates are provided in URI
#    if $!options<tlsCAFile>:exists and
#       $!options<tlsCertificateKeyFile>:exists {

      $!certificate-file = $!options<tlsCAFile>;
      $!private-key-file = $!options<tlsCertificateKeyFile>;
      my Bool $insecure = (
        $!options<tlsAllowInvalidCertificates>.Bool or
        $!options<tlsAllowInvalidHostnames>.Bool or
        $!options<tlsInsecure>.Bool
      );
note "$?LINE insecure not available yet: $insecure";
#`{{
      $!socket = await IO::Socket::Async::SSL.connect(
        $host, $port,
        :certificate-file($!options<tlsCAFile>),
        :private-key-file($!options<tlsCertificateKeyFile>)
          :$!certificate-file, :$!private-key-file, :$insecure
          #:ca-file($!options<tlsCAFile>)
      );
}}
#    }
  }
}}
}

#-------------------------------------------------------------------------------
method connect ( Str $host, Int $port ) {
  try {
    $!socket .= new( :$host, :$port);
    CATCH {
      default {
        trace-message("open socket to $host, $port, PF-INET: " ~ .message);

        # Retry for ipv6, throws when fails
        $!socket .= new( :$host, :$port, :family(PF_INET6));
      }
    }
  }

  if $!do-tls {
    $!ssl .= new(:client);

    $!certificate-file = $!options<tlsCAFile>;
    $!privatekey-file = $!options<tlsCertificateKeyFile>;
    my Bool $insecure = (
      $!options<tlsAllowInvalidCertificates>.Bool or
      $!options<tlsAllowInvalidHostnames>.Bool or
      $!options<tlsInsecure>.Bool
    );

note "$?LINE insecure not available yet: $insecure";
    fatal-message('Fail to load private key file')
      unless SSL_use_PrivateKey_file( $!ssl.ssl, $!privatekey-file, 1);
    fatal-message('Fail to load certificate')
      unless SSL_use_certificate_file( $!ssl.ssl, $!certificate-file, 1);

    trace-message("key and certificate loaded");

    fatal-message('Failed to check private key')
      unless SSL_check_private_key($!ssl.ssl);

    trace-message("key checked");

    # Set the socket into the ssl
    $!ssl.set-socket($!socket);
    # Set client mode and set proper handshake routines
    $!ssl.set-connect-state;
    # Make a connection
    $!ssl.connect();
  }
}


#-------------------------------------------------------------------------------
#tm:1:check-open::
method check-open ( --> Bool ) {

#  return True if $!is-open;

  if (now - $!rw-sem.reader( 'time', {$!time-last-used})) >
      MAX-SOCKET-UNUSED-OPEN {

    debug-message(
      "close socket $!sock-id, timeout after {now - $!time-last-used} sec"
    );

    $!rw-sem.writer( 'socket', {
        if $!do-tls {
          $!ssl.close;
          $!do-tls = False;
        }
        $!socket.close;
        $!is-open = False;
      }
    );
  }

  $!is-open;
}

#-------------------------------------------------------------------------------
#tm:1:send::
#method send ( Buf:D $b --> Nil ) {
method send ( Buf:D $b ) {

  my $s;
  if $!do-tls {
    $s = $!rw-sem.reader( 'socket', {$!ssl});
  }

  else {
    $s = $!rw-sem.reader( 'socket', {$!socket});
  }

  fatal-message("socket $!sock-id is closed") unless $s.defined;
  trace-message("socket $!sock-id send, size: $b.elems()");
  $s.write($b);
  $!rw-sem.writer( 'time', {$!time-last-used = now;});
}

#-------------------------------------------------------------------------------
#tm:0:receive::
method receive ( int $nbr-bytes --> Buf ) {

  my $s;
  if $!do-tls {
    $s = $!rw-sem.reader( 'socket', {$!ssl});
  }

  else {
    $s = $!rw-sem.reader( 'socket', {$!socket});
  }

  fatal-message("socket $!sock-id not opened") unless $s.defined;

  # :bin is for the ssl read() and is ignored in the socket reader
  my Buf $bytes = $s.read( $nbr-bytes, :bin);
  $!rw-sem.writer( 'time', {$!time-last-used = now;});
  trace-message(
    "socket $!sock-id receive, requested $nbr-bytes bytes, received $bytes.elems()"
  );

  $bytes;
}

#-----------------------------------------------------------------------------
#tm:1:receive-check::
# Read number of bytes from server. When not enough bytes are received
# an error is thrown.
method receive-check ( int $nbr-bytes --> Buf ) {

  my $s;
  if $!do-tls {
    $s = $!rw-sem.reader( 'socket', {$!ssl});
  }

  else {
    $s = $!rw-sem.reader( 'socket', {$!socket});
  }

  fatal-message("socket $!sock-id is closed") unless $s.defined;

  my Buf $bytes = $s.read( $nbr-bytes, :bin);
  if $bytes.elems == 0 {
    # No data, try again
    $bytes = $s.read( $nbr-bytes, :bin);
    fatal-message("socket $!sock-id: No response from server")
      if $bytes.elems == 0;
  }

  if 0 < $bytes.elems < $nbr-bytes {
    # Not 0 but too little, try to get the rest of it
    $bytes.push($s.read( $nbr-bytes - $bytes.elems, :bin));
    fatal-message("socket $!sock-id: Response corrupted") if $bytes.elems < $nbr-bytes;
  }

  trace-message("socket $!sock-id receive, received size $bytes.elems()");

  $!rw-sem.writer( 'time', {$!time-last-used = now;});
  $bytes
}

#-------------------------------------------------------------------------------
#tm:1:close::
method close ( ) {

  $!rw-sem.writer( 'socket', {
      if $!socket.defined and $!is-open {
        if $!do-tls {
          $!ssl.close;
          $!do-tls = False;
        }
        $!socket.close;
        $!socket = Nil;
        $!is-open = False;
      }
    }
  );

  trace-message("Close socket $!sock-id");
}

#-------------------------------------------------------------------------------
#tm:1:invalidate::
method invalidate ( Bool :$used-to-authenticate = False ) {

  if $used-to-authenticate {
    # sock must not be closed, it is copied by the authentication process
    $!rw-sem.writer( 'socket', {
        $!socket = Nil;
        $!is-open = False;
      }
    );
    trace-message("Socket $!sock-id invalidated");
  }

}


=finish
#-------------------------------------------------------------------------------
#tm:2:cleanup:SocketPool:
method cleanup ( ) {

  # closing a socket can throw exceptions
  $!rw-sem.writer( 'socket', {
      if $!socket.defined {
        $!socket.close;
        $!socket = Nil;
      }

      $!is-open = False;
    }
  );
}
