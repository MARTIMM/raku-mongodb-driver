use v6.c;

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
unit package MongoDB:auth<https://github.com/MARTIMM>;

#-------------------------------------------------------------------------------
class Server {

  # Used by Socket
  has Str $.server-name;
  has PortType $.server-port;

  has ClientType $!client;

  # As in MongoDB::Uri without servers name and port. So there are
  # database, username, password and options
  has Hash $!uri-data;
  has MongoDB::Authenticate::Credential $!credential;

  # Variables to control infinite server monitoring actions
  has MongoDB::Server::Monitor $!server-monitor;
  has Promise $!monitor-promise;

  has MongoDB::Server::Socket @!sockets;

  # Server status. Must be protected by a semaphore because of a thread
  # handling monitoring data.
  # Set status to its default starting status
  has ServerStatus $!status;
  has Str $!error;
  has Bool $!is-master;

  has Semaphore::ReadersWriters $!rw-sem;

  has Tap $!server-tap;

  # May be read from Client
  has Int $.max-wire-version;
  has Int $.min-wire-version;

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
      <s-select s-status sock-max wire-version>,
      :RWPatternType(C-RW-WRITERPRIO)
    ) unless $!rw-sem.check-mutex-names(<s-select s-status sock-max wire-version>);

    $!client = $client;
    $!uri-data = $client.uri-data;
    $!credential := $client.credential;

    @!sockets = ();

    # Save name andd port of the server
    ( my $host, my $port) = split( ':', $server-name);
    $!server-name = $host;
    $!server-port = $port.Int;

    $!server-monitor .= new( :server(self), :$loop-time);

    $!status = SS-Unknown;
    $!error = '';
    $!is-master = False;
  }

  #-----------------------------------------------------------------------------
  # Server initialization 
  method server-init ( ) {

    # Start monitoring
    $!monitor-promise = $!server-monitor.start-monitor;
    return unless $!monitor-promise.defined;

    # Tap into monitor data
    $!server-tap = self.tap-monitor( -> Hash $monitor-data {

        # See also https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/server-discovery-and-monitoring.rst#parsing-an-ismaster-response
        try {

note "\n$*THREAD.id() In server, data from Monitor: ", ($monitor-data // {}).perl;

          my ServerStatus $server-status = SS-Unknown;
          my Str $server-error = '';
          my Bool $is-master = False;

          if $monitor-data<ok> {

            my $mdata = $monitor-data<monitor>;
            $!rw-sem.writer(
              'wire-version', {
                $!max-wire-version = $mdata<maxWireVersion>.Int;
                $!min-wire-version = $mdata<minWireVersion>.Int;
              }
            );

            # Shard server
            if $mdata<msg>:exists and $mdata<msg> eq 'isdbgrid' {
              $server-status = SS-Mongos;
            }

            # Replica server in preinitialization state
            elsif ? $mdata<isreplicaset> {
              $server-status = SS-RSGhost;
            }

            # 
            elsif ? $mdata<setName> {
              $is-master = ? $mdata<ismaster>;
              if $is-master {
                $server-status = SS-RSPrimary;
              }

              elsif ? $mdata<secondary> {
                $server-status = SS-RSSecondary;
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
          }

          # Server did not respond
          else {

            if $monitor-data<reason>:exists
               and $monitor-data<reason> ~~ m:s/Failed to resolve host name/ {
              $server-error = $monitor-data<reason>;
            }

            else {
              $server-error = 'Server did not respond';
            }
          }

          # Set the status with the new value
          $!rw-sem.writer( 's-status', {
              debug-message("set status of {self.name()} $server-status");
              $!status = $server-status;
              $!error = $server-error;
              $!is-master = $is-master;
            }
          );

          CATCH {
            default {
              .note;

              # Set the status with the  value
              $!rw-sem.writer( 's-status', {
                  error-message("{.message}, {self.name()} {SS-Unknown}");
                  $!status = SS-Unknown;
                  $!error = .message;
                  $!is-master = False;
                }
              );
            }
          }
        }
      }
    );
  }

  #-----------------------------------------------------------------------------
  method get-status ( --> Hash ) {

    my int $count = 0;
    my ServerStatus $server-status = SS-Unknown;
    my Hash $server-sts-data = {};

    # Wait until changed, After 4 sec it should be known
    repeat {

      # Don't sleep on the first round
      sleep 1 if $count;
      $count++;

      $server-sts-data = $!rw-sem.reader(
        's-status', { %( :$!status, :$!is-master, :$!error ); }
      );

      $server-status = $server-sts-data<status>;

    } while $server-status ~~ SS-Unknown and $count < 4;

    $server-sts-data;
  }

  #-----------------------------------------------------------------------------
  # Make a tap on the Supply. Use act() for this so we are sure that only this
  # code runs whithout any other parrallel threads.
  #
  method tap-monitor ( |c --> Tap ) {

    $!server-monitor.get-supply.tap(|c);
#    my Supply $supply = $!server-monitor.get-supply;
#    $supply.act(|c);
#    $supply.tap(|c);
  }

  #-----------------------------------------------------------------------------
  # Search in the array for a closed Socket.
  # By default authentiction is needed when user/password info is found in the
  # uri data. Monitor, however does not need this so therefore it is made
  # optional.
  method get-socket ( Bool :$authenticate = True --> MongoDB::Server::Socket ) {

#note "$*THREAD.id() Get sock, authenticate = $authenticate";

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

#TODO check must be made on autenticate flag only and determined from server
    # We can only authenticate when all 3 data are True and when the socket is
    # opened anew.
    if not $opened-before and $authenticate
       and (? $!uri-data<username> or ? $!uri-data<password>) {

      # get authentication mechanism
      my Str $auth-mechanism = $!credential.auth-mechanism;
      if not $auth-mechanism {
        my Int $max-version = $!rw-sem.reader(
          'wire-version', {
            $!max-wire-version
          }
        );
        $auth-mechanism = $max-version < 3 ?? 'MONGODB-CR' !! 'SCRAM-SHA-1';
        debug-message("Use mechanism '$auth-mechanism' decided by wire version($max-version)");
      }

      $!credential.auth-mechanism(:$auth-mechanism);


      given $auth-mechanism {

        # Default in version 3.*
        when 'SCRAM-SHA-1' {

          my MongoDB::Authenticate::Scram $client-object .= new(
            :$!client, :db-name($!uri-data<database>)
          );

          my Auth::SCRAM $sc .= new(
            :username($!uri-data<username>),
            :password($!uri-data<password>),
            :$client-object,
          );

          my $error = $sc.start-scram;
          fatal-message("Authentication fail: $error") if ? $error;
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
    $sock;
  }

  #-----------------------------------------------------------------------------
  method raw-query (
    Str:D $full-collection-name, BSON::Document:D $query,
    Int :$number-to-skip = 0, Int :$number-to-return = 1,
    Bool :$authenticate = True
    --> BSON::Document
  ) {
    debug-message("server directed query on collection $full-collection-name on server {self.name}");
    return MongoDB::Wire.new.query(
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

    # Its possible that server moditor is not defined when a server is
    # non existent or some other reason.
    $!server-tap.close if $!server-tap.defined;
    $!server-monitor.stop-monitor if $!server-monitor.defined;

    # Clear all sockets
    $!rw-sem.writer( 's-select', {
        for ^(@!sockets.elems) -> $si {
          next unless @!sockets[$si].defined;
          @!sockets[$si].cleanup;
          @!sockets[$si] = Nil;
          trace-message("socket cleared");
        }
      }
    );

    $!server-monitor = Nil;
    $!client = Nil;
    $!uri-data = Nil;
    @!sockets = Nil;
    $!server-tap = Nil;
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
