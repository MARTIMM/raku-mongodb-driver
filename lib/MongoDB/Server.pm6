use v6.c;

use MongoDB;
use MongoDB::Server::Monitor;
use MongoDB::Server::Socket;
use BSON::Document;
use Semaphore::ReadersWriters;
use Auth::SCRAM;
use Base64;
use OpenSSL::Digest;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
class Server {

  # Used by Socket
  has Str $.server-name;
  has MongoDB::PortType $.server-port;

  has $!client;

  # As in MongoDB::Uri without servers name and port. So there are
  # database, username, password and options
  has Hash $!uri-data;

  # Variables to control infinite server monitoring actions
  has MongoDB::Server::Monitor $!server-monitor;
  has Supply $!monitor-supply;
  has Promise $!monitor-promise;

  has MongoDB::Server::Socket @!sockets;

  # Server status. Must be protected by a semaphore because of a thread
  # handling monitoring data.
  # Set status to its default starting status
  has MongoDB::ServerStatus $!server-status;

  has Semaphore::ReadersWriters $!rw-sem;

  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  # Class definition to do authentication with
  my class AuthenticateMDB {

    has ClientType $!client;
    has DatabaseType $!database;
    has Int $!conversation-id;

    #-----------------------------------------------------------------------------
    submethod BUILD ( ClientType:D :$client, Str :$db-name ) {
      $!client = $client;
      $!database = $!client.database(?$db-name ?? $db-name !! 'admin' );
    }

    #-----------------------------------------------------------------------------
    # send client first message to server and return server response
    method message1 ( Str:D $client-first-message --> Str ) {

      my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
          saslStart => 1,
          mechanism => 'SCRAM-SHA-1',
          payload => encode-base64( $client-first-message, :str)
        )
      );

      if !$doc<ok> {
        error-message("$doc<code>, $doc<errmsg>");
        return '';
      }

      $!conversation-id = $doc<conversationId>;
      Buf.new(decode-base64($doc<payload>)).decode;
    }

    #-----------------------------------------------------------------------------
    method message2 ( Str:D $client-final-message --> Str ) {

     my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
          saslContinue => 1,
          conversationId => $!conversation-id,
          payload => encode-base64( $client-final-message, :str)
        )
      );

      if !$doc<ok> {
        error-message("$doc<code>, $doc<errmsg>");
        return '';
      }

      Buf.new(decode-base64($doc<payload>)).decode;
    }

    #-----------------------------------------------------------------------------
    method mangle-password ( Str:D :$username, Str:D :$password --> Buf ) {

      my utf8 $mdb-hashed-pw = ($username ~ ':mongo:' ~ $password).encode;
      my Str $md5-mdb-hashed-pw = md5($mdb-hashed-pw).>>.fmt('%02x').join;
      Buf.new($md5-mdb-hashed-pw.encode);
    }

    #-----------------------------------------------------------------------------
    method clean-up ( ) {

      # Some extra chit-chat
      my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
          saslContinue => 1,
          conversationId => $!conversation-id,
          payload => encode-base64( '', :str)
        )
      );

      if !$doc<ok> {
        error-message("$doc<code>, $doc<errmsg>");
        return '';
      }

      Buf.new(decode-base64($doc<payload>)).decode;
    }

    #-----------------------------------------------------------------------------
    method error ( Str:D $message --> Str ) {

      error-message($message);
    }
  }

  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  # Server must make contact first to see if server exists and reacts. This
  # must be done in the background so Client starts this process in a thread.
  #
  submethod BUILD (
    ClientType:D :$client,
    Str:D :$server-name,
    Hash :$uri-data = %(),
    Int :$loop-time = 10
  ) {

    $!rw-sem .= new;
#    $!rw-sem.debug = True;
    $!rw-sem.add-mutex-names(
      <s-select s-status sock-max>,
      :RWPatternType(C-RW-WRITERPRIO)
    );

    $!client = $client;
    @!sockets = ();

    # Save name andd port of the server
    ( my $host, my $port) = split( ':', $server-name);
    $!server-name = $host;
    $!server-port = $port.Int;

    $!uri-data = $uri-data;

    $!server-monitor .= new( :server(self), :$loop-time);
    $!server-status = MongoDB::C-UNKNOWN-SERVER;
  }

  #-----------------------------------------------------------------------------
  # Server initialization 
  method server-init ( ) {

    # Start monitoring
    $!monitor-promise = $!server-monitor.start-monitor;
    return unless $!monitor-promise.defined;

    # Tap into monitor data
    self.tap-monitor( -> Hash $monitor-data {
        try {

#say "\n$*THREAD.id() In server, data from Monitor: ", ($monitor-data // {}).perl;

          my MongoDB::ServerStatus $server-status = MongoDB::C-UNKNOWN-SERVER;
          if $monitor-data<ok> {

            my $mdata = $monitor-data<monitor>;

            # Does the caller want to have a replicaset
            if $!uri-data<options><replicaSet> {

              # Server is in a replicaset and initialized
              if $mdata<isreplicaset>:!exists and $mdata<setName> {

                # Is the server in the replicaset matching the callers request
                if $mdata<setName> eq $!uri-data<options><replicaSet> {

                  if $mdata<ismaster> {
                    $server-status = MongoDB::C-REPLICASET-PRIMARY;
                  }

                  elsif $mdata<secondary> {
                    $server-status = MongoDB::C-REPLICASET-SECONDARY;
                  }

                  # ... Arbiter etc
                }

                # Replicaset name does not match
                else {
                  $server-status = MongoDB::C-REJECTED-SERVER;
                }
              }

              # Server is in a replicaset but not initialized.
              elsif $mdata<isreplicaset> and $mdata<setName>:!exists {
                $server-status = MongoDB::C-REPLICA-PRE-INIT
              }

              # Shouldn't happen
              else {
                $server-status = MongoDB::C-REJECTED-SERVER;
              }
            }

            # Need one standalone server
            else {

              # Must not be any type of replicaset server
              if $mdata<isreplicaset>:exists
                 or $mdata<setName>:exists
                 or $mdata<primary>:exists {
                $server-status = MongoDB::C-REJECTED-SERVER;
              }

              else {
                # Must be master
                if $mdata<ismaster> {
                  $server-status = MongoDB::C-MASTER-SERVER;
                }

                # Shouldn't happen
                else {
                  $server-status = MongoDB::C-REJECTED-SERVER;
                }
              }
            }
          }

          # Server did not respond
          else {

            if $monitor-data<reason>:exists
               and $monitor-data<reason> ~~ m:s/Failed to resolve host name/ {
              $server-status = MongoDB::C-NON-EXISTENT-SERVER;
            }

            else {
              $server-status = MongoDB::C-DOWN-SERVER;
            }
          }

          # Set the status with the new value
          $!rw-sem.writer( 's-status', {
              debug-message("set status of {self.name()} $server-status");
              $!server-status = $server-status;
            }
          );

          CATCH {
            default {
              .say;
              .rethrow;
            }
          }
        }
      }
    );
  }

  #-----------------------------------------------------------------------------
  method get-status ( --> MongoDB::ServerStatus ) {

    my int $count = 0;
    my MongoDB::ServerStatus $server-status = MongoDB::C-UNKNOWN-SERVER;

    # Wait until changed, After 4 sec it must be known or stays unknown forever
    while $count < 4 and $server-status ~~ MongoDB::C-UNKNOWN-SERVER {
      $server-status = $!rw-sem.reader( 's-status', {$!server-status;});

      sleep 1;
      $count++;
    }

    $server-status;
  }

  #-----------------------------------------------------------------------------
  # Make a tap on the Supply. Use act() for this so we are sure that only this
  # code runs whithout any other parrallel threads.
  #
  method tap-monitor ( |c --> Tap ) {

    $!monitor-supply = $!server-monitor.get-supply
       unless $!monitor-supply.defined;
#    $!monitor-supply.act(|c);
    $!monitor-supply.tap(|c);
  }

  #-----------------------------------------------------------------------------
  method stop-monitor ( ) {

    $!server-monitor.done;
  }

  #-----------------------------------------------------------------------------
  # Search in the array for a closed Socket.
  # By default authentiction is needed when user/password info is found in the
  # uri data. Monitor, however does not need this so therefore it is made
  # optional.
  method get-socket ( Bool :$authenticate = True --> MongoDB::Server::Socket ) {

#say "$*THREAD.id() Get sock, authenticate = $authenticate";

    # Get a free socket entry
    my MongoDB::Server::Socket $sock = $!rw-sem.writer( 's-select', {

#say "in s-select ...";
# count total opened
#my Int $c = 0;
#for ^(@!sockets.elems) -> $si { $c++ if @!sockets[$si].is-open; }
#trace-message("total sockets open: $c of @!sockets.elems()");
#        trace-message(
#          "total sockets open: ",
#          "{do {my $c = 0; for ^(@!sockets.elems) -> $si { $c++ if @!sockets[$si].is-open; }; $c}}"
#        );

        my MongoDB::Server::Socket $s;

        # Check all sockets first
        for ^(@!sockets.elems) -> $si {

          next unless @!sockets[$si].defined;

          if @!sockets[$si].check {
            @!sockets[$si] = Nil;
            trace-message("socket cleared");
          }
        }

        # Search for socket
        for ^(@!sockets.elems) -> $si {

          next unless @!sockets[$si].defined;

          if @!sockets[$si].thread-id == $*THREAD.id() {
            $s = @!sockets[$si];
            trace-message("socket found");
            last;
          }
        }

        # If none is found insert a new Socket in the array
        if not $s.defined {
          # search for an empty slot
          my Bool $slot-found = False;
          for ^(@!sockets.elems) -> $si {
            if not @!sockets[$si].defined {
              $s .= new(:server(self));
              @!sockets[$si] = $s;
              $slot-found = True;
            }
          }

          if not $slot-found {
            $s .= new(:server(self));
            @!sockets.push($s);
          }
        }

        $s;
      }
    );


    # Use return value to see if authentication is needed.
    my Bool $opened-before = $sock.open;

    # We can only authenticate when all 3 data are True and when the socket is
    # opened anew.
    if !$opened-before
       and $authenticate
       and ? $!uri-data<username>
       and ? $!uri-data<password> {

      my Auth::SCRAM $sc .= new(
        :username($!uri-data<username>),
        :password($!uri-data<password>),
        :client-side(
          AuthenticateMDB.new( :$!client, :db-name($!uri-data<database>))
        ),
      );

      $sc.start-scram;
    }

    # Return a usable socket which is opened and authenticated upon if needed.
    $sock;
  }

  #-----------------------------------------------------------------------------
  method name ( --> Str ) {

    return [~] $!server-name // '-', ':', $!server-port // '-';
  }
}




=finish
#-------------------------------------------------------------------------------
sub dump-callframe ( $fn-max = 10 --> Str ) {

  my Str $dftxt = "\nDump call frame: \n";

  my $fn = 1;
  while my CallFrame $cf = callframe($fn) {
#say $cf.perl;
#say "TOP: ", $cf<TOP>:exists;

    # End loop with the program that starts on line 1 and code object is
    # a hollow shell.
    #
    if ?$cf and $cf.line == 1  and $cf.code ~~ Mu {
      $cf = Nil;
      last;
    }

    # Cannot pass sub THREAD-ENTRY either
    #
    if ?$cf and $cf.code.^can('name') and $cf.code.name eq 'THREAD-ENTRY' {
      $cf = Nil;
      last;
    }

    $dftxt ~= [~] "cf [$fn.fmt('%2d')]: ", $cf.line, ', ', $cf.code.^name,
        ', ', ($cf.code.^can('name') ?? $cf.code.name !! '-'),
         "\n         $cf.file()\n";

    $fn++;
    last if $fn > $fn-max;
  }

  $dftxt ~= "\n";
}
