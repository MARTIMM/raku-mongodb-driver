#TL:1:MongoDB::Server::Monitor:

use v6;

#use MongoDB::ServerPool::Server;
#use MongoDB::Server::Socket;
use MongoDB;
use MongoDB::Wire;
use MongoDB::ObserverEmitter;
use MongoDB::Timer;

use BSON;
use BSON::Document;

use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
unit class MongoDB::Server::Monitor:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
my MongoDB::Server::Monitor $singleton-instance;

# server data of registered servers, an array each entry. its key must be a
# combination of the client and server keys because servers can be duplicated
# in the serverpool.
enum SERVERDATA < ServerObj WMRttMs >;
my %registered-servers;

# Variables to control infinite monitoring actions
my Promise $promise-monitor;

#has Supplier $!monitor-data-supplier;

# heartbeat frequency is the normal wait period between ismaster requests.
# settle frequency is a much shorter period to settle the topology until
# everything gets stable. $servers-settled is False when any server has
# a SS-UNKNOWN state. NO-SERVERS-FREQUENCY-MS is set to a long wait to
# use when there are no servers registered.
my Duration $heartbeat-frequency-ms;
constant SETTLE-FREQUENCY-MS = Duration.new(5e2);
constant NO-SERVERS-FREQUENCY-MS = Duration.new(1e6);

my Bool $servers-settled;
has Bool $no-servers-available;

my BSON::Document $monitor-command;
my MongoDB::Timer $monitor-timer;

my Semaphore::ReadersWriters $rw-sem;

#-------------------------------------------------------------------------------
#tm:1:bless():instance()
# Call before monitor-server to set the $!server object!
# Inheriting from Supplier prevents use of proper BUILD
submethod BUILD ( ) {

  $heartbeat-frequency-ms .= new(MongoDB::C-HEARTBEATFREQUENCYMS);
  $servers-settled = False;
  $no-servers-available = True;

#  debug-message("HeartbeatFrequencyMs set to $heartbeat-frequency-ms ms");

  $rw-sem .= new;
  #$rw-sem.debug = True;
  $rw-sem.add-mutex-names(
    <m-servers mon-wait-timer>, :RWPatternType(C-RW-WRITERPRIO)
  );

  %registered-servers = %();

  $monitor-command .= new: (isMaster => 1);

  # observe heartbeat changes
  my MongoDB::ObserverEmitter $event-manager .= new;
  $event-manager.subscribe-observer(
    'set heartbeatfrequency ms',
    -> Int $heartbeat { self!set-heartbeat($heartbeat) },
    :event-key<heartbeat>
  );

  # observe server registration
  $event-manager.subscribe-observer(
    'register server',
#    -> MongoDB::ServerClassType:D $server { self!register-server($server) },
    -> $server { self!register-server($server) },
    :event-key<register-server>
  );

  # observe server deregistration
  $event-manager.subscribe-observer(
    'unregister server',
#    -> MongoDB::ServerClassType:D $server { self!unregister-server($server) },
    -> $server { self!unregister-server($server) },
    :event-key<unregister-server>
  );

  # start the monitor
  debug-message("Start monitoring");
  self!start-monitor;
#  sleep(0.2);
}

#-------------------------------------------------------------------------------
#tm:1:new():
# Prevent calling new(). Must use instance()
method new ( ) { !!! }

#-------------------------------------------------------------------------------
#tm:1:instance():
method instance ( --> MongoDB::Server::Monitor ) {

  # initialize only once
  $singleton-instance //= self.bless;
  $singleton-instance
}

#`{{
#-------------------------------------------------------------------------------
method get-supply ( --> Supply ) {

  $!monitor-data-supplier.Supply
}
}}

#-------------------------------------------------------------------------------
method !set-heartbeat ( Int:D $new-heartbeat-frequency-ms ) {

  $rw-sem.writer( 'mon-wait-timer', {
      # Don't let looptime become lower than 100 ms
      if $new-heartbeat-frequency-ms > 100 {
        $heartbeat-frequency-ms .= new($new-heartbeat-frequency-ms);

        debug-message(
          "heartbeatFrequencyMs modified to $heartbeat-frequency-ms ms"
        );
      }
    }
  );
}

#-------------------------------------------------------------------------------
#method !register-server ( MongoDB::ServerClassType:D $server ) {
method !register-server (
  $server where { .defined and .^name eq 'MongoDB::ServerPool::Server' }
) {

  my Str $server-name = $server.name();
  my Bool $exists = $rw-sem.reader(
    'm-servers', { %registered-servers{$server-name}:exists; }
  );

  if $exists {
    # check if its object is still there. removing a server seems to go wrong
    # sometimes when cleanup of registered servers which might get registered
    # again in parallel, all from different threads.
    info-message("$server-name exists");
    $rw-sem.writer( 'm-servers', {
        %registered-servers{$server-name}[ServerObj] = $server
          unless %registered-servers{$server-name}[ServerObj].defined;
      }
    );
  }

  else {
    $rw-sem.writer( 'm-servers', {

        # induce a shorter waiting period until all servers are settled again
        $servers-settled = False;
        $no-servers-available = False;

        %registered-servers{$server-name} = [
          $server,    # provided server
          0,          # init weighted mean rtt in ms
        ];
      } # writer block
    ); # writer

    debug-message("Server $server-name registered");

    # then cancel the monitor wait
    $monitor-timer.cancel if $monitor-timer.defined;
  }
}

#-------------------------------------------------------------------------------
#method !unregister-server ( MongoDB::ServerClassType:D $server ) {
method !unregister-server ( $server ) {

  my Str $server-name = $server.name;
#  my Bool $exists = $rw-sem.reader(
#    'm-servers', { %registered-servers{$server-name}:exists; }
#  );

#  if $exists {
    $rw-sem.writer( 'm-servers', { %registered-servers{$server-name}:delete; });
    debug-message("Server $server-name un-registered");
#  }
}

#-------------------------------------------------------------------------------
method !start-monitor ( ) {

try {
  # set the code aside the main thread
  Promise.start( {
      # set a short starting time
      $monitor-timer = MongoDB::Timer.in(0.1);
      loop {

#ENTER trace-message("promise loop begin");

        # start first run. should start after 0.1 sec from previous statement.
        #$promise-monitor .= start( { self.monitor-work } );
        $promise-monitor = $monitor-timer.promise.then( {
            self.monitor-work;
          }
        );

        await $promise-monitor;

        # wait for end of thread or when waittime is canceled
        if $promise-monitor.status ~~ PromiseStatus::Kept {
          trace-message(
            "wait period finished, result: {$promise-monitor.result() // '-'}"
          );
        }

        elsif $promise-monitor.status ~~ PromiseStatus::Broken {
          trace-message(
            "wait period interrupted: $promise-monitor.cause(), " ~
            "monitor heartbeat shortened for new data"
          );
        }

        # heartbeat can be adjusted with set-heartbeat() or $servers-settled
        # demands shorter cycle using SETTLE-FREQUENCY-MS
        my $heartbeat-frequency =
          ( ? $no-servers-available
              ?? NO-SERVERS-FREQUENCY-MS
              !! ( $servers-settled
                    ?? $heartbeat-frequency-ms
                    !! SETTLE-FREQUENCY-MS
                 )
          );

        trace-message(
          ($no-servers-available ?? "no servers available, " !! '') ~
          ($servers-settled ?? "servers are settled, " !! '') ~
          "current monitoring waittime: $heartbeat-frequency ms"
        );

        # create the cancelable thread. wait is in seconds
        $monitor-timer = MongoDB::Timer.in( $heartbeat-frequency / 1000.0 );

#NEXT trace-message("promise loop end");
      } # loop
    }   # Promise code
  );    # Promise.start
CATCH {.note;}
}


#`{{
  # infinite
  Promise.start( {
      $monitor-timer = MongoDB::Timer.in(0.1);

      # start first run. should start after 0.1 sec from previous statement.
      #$promise-monitor .= start( { self.monitor-work } );
      $promise-monitor = $monitor-timer.promise.then( {
          self.monitor-work;
        }
      );

      # then infinite loop
      loop {

        # wait for end of thread or when waittime is canceled
        if $promise-monitor.status ~~ PromiseStatus::Kept {
          trace-message('wait period finished');
          $promise-monitor.result;
        }

        elsif $promise-monitor.status ~~ PromiseStatus::Broken {
          trace-message(
            'wait period interrupted: ' ~ $promise-monitor.cause~
            "monitor heartbeat shortened for new data"
          );
        }

        # heartbeat can be adjusted with set-heartbeat() or $servers-settled
        # demands shorter cycle using SETTLE-FREQUENCY-MS
        my $heartbeat-frequency =
          ( ? $no-servers-available
              ?? NO-SERVERS-FREQUENCY-MS
              !! ( $servers-settled
                    ?? $heartbeat-frequency-ms
                    !! SETTLE-FREQUENCY-MS
                 )
          );

        trace-message(
          ($no-servers-available ?? "no servers available, " !! '') ~
          ($servers-settled ?? "servers are settled, " !! '') ~
          "current monitoring waittime: $heartbeat-frequency ms"
        );

        # create the cancelable thread. wait is in seconds
        $monitor-timer = MongoDB::Timer.in(
          $heartbeat-frequency / 1000.0
        );

        $promise-monitor = $monitor-timer.promise.then( {
#try {
            self.monitor-work;
#CATCH { .note }
#}
          }
        );

        await $promise-monitor;
#trace-message("Promise: $promise-monitor.status()");
      } # loop
    }   # Promise code
  );    # Promise.start
}}
}       # method

#-------------------------------------------------------------------------------
method monitor-work ( ) {

#note "do monitor work";

  my Duration $rtt;
  my BSON::Document $doc;
  my Int $weighted-mean-rtt-ms;
  my MongoDB::ObserverEmitter $monitor-data .= new;

  $servers-settled = True;

#  my Duration $loop-start-time-ms .= new(now * 1000);
  my %rservers = $rw-sem.reader(
   'm-servers',
    sub () { %registered-servers; }
  );
#note "Ass: %registered-servers.perl()";

  # check if there are any servers. if not, return
  $no-servers-available = ! %rservers.elems;
  return if $no-servers-available;

  # loop through all registerd servers
  trace-message("Servers to monitor: " ~ %rservers.keys.join(', '));
  for %rservers.keys -> $server-name {

trace-message("monitor-work server $server-name, %registered-servers.perl()");

    # last check if server is still registered in original structure
    next unless $rw-sem.reader(
        'm-servers',
        { %registered-servers{$server-name}:exists and
          %registered-servers{$server-name}[ServerObj].defined;
        }
      );

    # get server info
    my $server = %rservers{$server-name}[ServerObj];
    ( $doc, $rtt) = self.raw-query($server);


    my Str $doc-text = ($doc // '-').perl;
    trace-message("is-master request result for $server-name: $doc-text");

    # when doc is defined, the request ended properly. the ok field
    # in the doc will tell if the operation is succsessful or not
    if $doc.defined {

#note "Use: %registered-servers.perl()";
#note 'emit to ',%rservers{$server-name}[ServerObj].name ~ ' monitor data';

      # Calculation of mean Return Trip Time. See also
      # https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#calculation-of-average-round-trip-times
      %rservers{$server-name}[WMRttMs] = Duration.new(
        0.2 * $rtt * 1000 + 0.8 * %rservers{$server-name}[WMRttMs]
      );

      # set new value of wait mean rtt if the server is still registered
      $rw-sem.writer( 'm-servers', {
          %registered-servers{$server-name}[WMRttMs] =
            %rservers{$server-name}[WMRttMs]
            if %rservers{$server-name}:exists; # Could be removed!
        }
      );

      debug-message(
        [~] 'Weighted mean RTT: ', %rservers{$server-name}[WMRttMs].fmt('%.3f'),
            ' (ms) for server ', $server.name()
      );

      $monitor-data.emit(
        %registered-servers{$server-name}[ServerObj].name ~
          ' monitor data', %(

          :ok($doc<documents>[0]<ok>), :monitor($doc<documents>[0]),  # :$server-name,
          :weighted-mean-rtt-ms(%rservers{$server-name}[WMRttMs])
        ) # emit data
      ) if %registered-servers{$server-name}[ServerObj].defined;  # emit
      # ^^^ keep testing, other thread may have been in deleting process

#      $!monitor-data-supplier.emit( {
#          :ok, :monitor($doc<documents>[0]), :$server-name,
#          :weighted-mean-rtt-ms(%rservers{$server-name}[WMRttMs])
#        } # emit data
#      );  # emit
    }     # if $doc.defined

    # no doc returned, server is in trouble or the connection
    # between it is down.
    else {
      warn-message("no response from server $server.name()");
      $servers-settled = False;

      $monitor-data.emit(
        %registered-servers{$server-name}[ServerObj].name ~
          ' monitor data', {
            :!ok, :reason('Undefined document') #, :$server-name
          }
      ) if %registered-servers{$server-name}[ServerObj].defined;
      # ^^^ keep testing, other thread may have been in deleting process

#      $!monitor-data-supplier.emit( %(
#          :!ok, reason => 'Undefined document', :$server-name
#        ) # emit data
#      );  # emit
    }     # else
  }       # for %rservers.keys

  trace-message(
    "Servers are " ~ ($servers-settled ?? '' !! 'not yet ') ~ 'settled'
  );
}

#-------------------------------------------------------------------------------
multi method raw-query ( $server --> List ) {

  my BSON::Document $doc;
  my Duration $rtt;

  my MongoDB::Uri $uri-obj .= new(:uri("mongodb://$server.name()"));

  my MongoDB::Wire $w .= new;
  ( $doc, $rtt) = $w.query(
    'admin.$cmd', $monitor-command,
    :number-to-skip(0), :number-to-return(1),
    :$server, :time-query
  );

  trace-message("result raw query to server $server.name(): $doc.perl()");

  ( $doc, $rtt);
}
