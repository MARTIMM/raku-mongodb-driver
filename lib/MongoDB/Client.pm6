use v6.c;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

use MongoDB;
use MongoDB::Uri;
use MongoDB::Server;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Wire;
use MongoDB::Authenticate::Credential;

use BSON::Document;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
class Client {

  has TopologyType $!topology-type;

  # Store all found servers here. key is the name of the server which is
  # the server address/ip and its port number. This should be unique.
  #
  has Hash $!servers;

  has Array $!todo-servers;

  has Str $!master-servername;

  has Semaphore::ReadersWriters $!rw-sem;

  has Str $!uri;
  has Hash $.uri-data;

  has BSON::Document $.read-concern;
  has Str $!Replicaset;

  has Promise $!Background-discovery;
  has Bool $!repeat-discovery-loop;

  has Tap $!client-tap;

  # https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst#client-implementation
  has MongoDB::Authenticate::Credential $.credential;


#`{{
  #-----------------------------------------------------------------------------
  # Explicitly create an object using the undefined class name to prevent
  # changes in the existing class when used as an invocant.
  #
  method new ( Str:D :$uri, BSON::Document :$read-concern ) {

say 'new client 0';
    my $x = MongoDB::Client.bless( :$uri, :$read-concern);
say 'new client 1';
    $x;
  }
}}
  #-----------------------------------------------------------------------------
  submethod BUILD (
    Str:D :$uri, BSON::Document :$read-concern, Int :$loop-time = 10,
    TopologyType :$topology-type = UNKNOWN-TPLGY
  ) {

#TODO write letter about usefulness of setting topology type
    $!topology-type = $topology-type;

    $!servers = {};

    # Start as if we must process servers so the Boolean is set to True
    $!todo-servers = [];

    $!master-servername = Nil;

    $!rw-sem .= new;
#    $!rw-sem.debug = True;
#TODO check before create
    # Insert only when server is not defined yet. W've been here before.
    $!rw-sem.add-mutex-names(
      <servers todo master>,
      :RWPatternType(C-RW-WRITERPRIO)
    ) unless $!rw-sem.check-mutex-names(<servers todo master>);

    # Store read concern
    $!read-concern =
      $read-concern.defined ?? $read-concern !! BSON::Document.new;

    # Parse the uri and get info in $uri-obj. Fields are protocol, username,
    # password, servers, database and options.
    #
    $!uri = $uri;

    # Copy some fields into $!uri-data hash which is handed over
    # to the server object..
    #
    my @item-list = <username password database options>;
    my MongoDB::Uri $uri-obj .= new(:$!uri);
    $!uri-data = %(@item-list Z=> $uri-obj.server-data{@item-list});

    my %cred-data = %();
    my $set = sub ( *@k ) {
      my $sk = shift @k;
      for @k -> $rk {
        return if %cred-data{$sk};
        %cred-data{$sk} = $uri-obj.server-data{$rk}
          if ? $rk and ? $uri-obj.server-data{$rk};
      }
    };

    $set( 'username', 'username');
    $set( 'password', 'password');
    $set( 'auth-source', 'database', 'authSource', 'admin');
    $set( 'auth-mechanism', 'authMechanism');
    $set( 'auth-mechanism-properties', 'authMechanismProperties');
    $!credential .= new(|%cred-data);

    debug-message("Found {$uri-obj.server-data<servers>.elems} servers in uri");

    # Setup todo list with servers to be processed, Safety net not needed yet
    # because threads are not started.
    for @($uri-obj.server-data<servers>) -> Hash $server-data {
      $!todo-servers.push("$server-data<host>:$server-data<port>");
    }

    # Background proces to handle server monitoring data
    $!Background-discovery = Promise.start( {

        $!repeat-discovery-loop = True;
        loop {

#          sleep 1;

          # Start processing when something is found in todo hash
          my Str $server-name = $!rw-sem.writer(
            'todo', {
              my Str $s;
              if $!todo-servers.elems {
                $s = $!todo-servers.shift;
              }

              $s;
            }
          );

          if $server-name.defined {

            trace-message("Processing server $server-name");

            my Bool $server-processed = $!rw-sem.reader(
              'servers',
              { $!servers{$server-name}:exists; }
            );

            # Check if server was managed before
            if $server-processed {
              trace-message("Server $server-name already managed");
              next;
            }

#say "$*THREAD.id() New server object: $server-name";
            my MongoDB::Server $server .= new(
              :client(self), :$server-name, :$loop-time
            );

            # Start server monitoring process its data
#say "$*THREAD.id() Init server object and start monitoring: $server-name";
            $server.server-init;
#say "$*THREAD.id() Tap from monitor: $server-name";
            self!process-monitor-data($server);
          }

          else {

            # When there is no work take a nap!
            # This sleeping period is the moment we do not process the todo list
            sleep 1;
          }

          CATCH {
            default {
               # Keep this .say in. It helps debugging when an error takes place
               # The error will not be seen before the result of Promise is read
               .say;
               .rethrow;
            }
          }

          last unless $!repeat-discovery-loop;
        }

        debug-message("Stop discovery loop");
      }
    );
  }

  #-----------------------------------------------------------------------------
  method !process-monitor-data ( MongoDB::Server $server ) {

    my Str $server-name = $server.name;

    # Tap into the stream of monitor data
    $!client-tap = $server.tap-monitor( -> Hash $monitor-data {
#say "\n$*THREAD.id() In client, data from Monitor: ", ($monitor-data // {}).perl;

#        if $monitor-data.defined and $monitor-data<ok>:exists {
#          my Bool $found-new-servers = False;
#say "Monitor $server-name: ", $monitor-data.perl if $monitor-data.defined;

          # Make the processing of the monitor data atomic

#say "$*THREAD.id() get prev server data";
          my Hash $prev-server = $!rw-sem.reader(
            'servers', {
#say "$*THREAD.id() Reader code $server-name";
            $!servers{$server-name}:exists ?? $!servers{$server-name} !! {};
          });
#say "$*THREAD.id() prev server data retrieved";

          my $msname = $!rw-sem.reader( 'master', {$!master-servername;});
#say "$*THREAD.id() get master {$msname//'-'}";


          # Store partial result as soon as possible
          my $server-status = $server.get-status;
          $!rw-sem.writer(
            'servers', {
            debug-message("saved status of $server-name is $server-status");
            $!servers{$server-name} = {
              server => $server,
              status => $server-status,
              timestamp => now,
              server-data => $monitor-data
            };
          });
#say "$*THREAD.id() Saved monitor data for $server-name = ", $!servers{$server-name}.perl;

          # Only when data is ok
          if not $monitor-data.defined {

            error-message("No monitor data received");
          }

          # There are errors while monitoring
          elsif not $monitor-data<ok> {

            my ServerStatus $status =
               $!rw-sem.reader( 'servers', {$!servers{$server-name}<status>});

            # Not found by DNS so big chance that it doesn't exist
            if $status ~~ NON-EXISTENT-SERVER {

#              $!client-tap.done;
              $!servers{$server-name}<server>.cleanup;
              error-message("Stopping monitor: $monitor-data<reason>");
            }

            # Connection failure
            elsif $status ~~ DOWN-SERVER {

              # Check if the master server went down
              if $msname.defined and ($msname eq $server-name) {

#say "$*THREAD.id() reset master";
                $!rw-sem.writer( 'master', {$!master-servername = Nil;});
                $msname = Nil;
              }

              warn-message("Server is down: $monitor-data<reason>");
            }
          }


          # Monitoring data is ok
          else {

#say "$*THREAD.id() Master server name: ", $msname // '-';
#say "$*THREAD.id() Master prev stat: ", $prev-server<status>:exists 
#                  ?? $prev-server<status>
#                  !! '-';

#say "$*THREAD.id() PMD: $server-name, $!servers{$server-name}<status>, ", $msname // '-';
            # Don't ever modify a rejected server
            if $prev-server<status>:exists
               and $prev-server<status> ~~ REJECTED-SERVER {

              $!rw-sem.writer(
                'servers', {
                debug-message("set server $server-name status to " ~ REJECTED-SERVER);
                $!servers{$server-name}<status> = REJECTED-SERVER;
              });
            }

            # Check for double master servers
            elsif $!rw-sem.reader( 'servers', {$!servers{$server-name}<status>})
              ~~ any(
              MASTER-SERVER |
              REPLICASET-PRIMARY
            ) {
              # Is defined, be the second and rejected master server
              if $msname.defined {
                if $msname ne $server-name {
                  $!rw-sem.writer(
                    'servers', {
                    $!servers{$server-name}<status> = REJECTED-SERVER;
                  });
                  error-message("Server $server-name rejected, second master");
                }
              }

              # Not defined, be the first master server. No need to save status
              # because its done already
              else {

                $msname = $!rw-sem.writer(
                  'master', {
                    debug-message("save master servername $server-name");
                    $!master-servername = $server-name;
                  }
                );
              }
            }

            else {

#say "$*THREAD.id() H4: $!servers{$server-name}<status>, ", $msname // '-', ', ', $server-name;
            }

            # When primary, find all servers and add to todo list
            if $!rw-sem.reader( 'servers', {$!servers{$server-name}<status>})
               ~~ REPLICASET-PRIMARY {

              my Array $hosts = $!rw-sem.reader(
                'servers', {
                $!servers{$server-name}<server-data><monitor><hosts>;
              });

              for @$hosts -> $hostspec {
                # If not push onto todo list
                next unless $hostspec ne $server-name;

                debug-message("Push $hostspec from primary list on todo list");
                $!rw-sem.writer( 'todo', {$!todo-servers.push($hostspec);});
#say "$*THREAD.id() Add $hostspec, $!todo-servers.elems()";
              }
            }

            # When secondary get its primary and add to todo list
            elsif $!rw-sem.reader( 'servers', {$!servers{$server-name}<status>})
                  ~~ REPLICASET-SECONDARY {

              # Error when current master is not same as primary
              my $primary = $!rw-sem.reader(
                'servers', {
                $!servers{$server-name}<server-data><monitor><primary>;
              });

              if $msname.defined and $msname ne $primary {
                error-message(
                  "Server $primary found but != current master $msname"
                );
              }

              # When defined w've already processed it, if not, go for it
              elsif not $msname.defined {

                trace-message("Push primary $primary on todo list");
                $!rw-sem.writer( 'todo', {$!todo-servers.push($primary);});
#say "$*THREAD.id() Add primary $primary, $!todo-servers.elems()";
              }
            }

#TODO $!master-servername must be able to change when server roles are changed
#TODO Define client topology
          }

          CATCH {
            default {
               # Keep this .say in. It helps debugging when an error takes place
               # The error will not be seen before the result of Promise is read
               .say;
              .rethrow;
            }
          }
      }
    );
  }

  #-----------------------------------------------------------------------------
  # Return number of servers
  method nbr-servers ( --> Int ) {

    self!check-discovery-process;
    $!rw-sem.reader( 'servers', {$!servers.elems;});
  }

  #-----------------------------------------------------------------------------
  # Called from thread above where Server object is created.
  method server-status ( Str:D $server-name --> ServerStatus ) {

#say "$*THREAD.id() before check";
    self!check-discovery-process;
#say "$*THREAD.id() after check";
#    self!check-todo-process;

    my Hash $h = $!rw-sem.reader(
      'servers', {
      my $x = $!servers{$server-name}:exists ?? $!servers{$server-name} !! {};
      $x;
    });
    debug-message("server-status: $server-name, " ~ ($h<status> // '-'));

    my ServerStatus $sts = $h<status> // UNKNOWN-SERVER;
  }

  #-----------------------------------------------------------------------------
  method client-topology ( --> TopologyType ) {

    $!topology-type;
  }

  #-----------------------------------------------------------------------------
  # Selecting servers based on;
  # - read/write concern, depends on server version
  # - state of a server, e.g. to initialize a replica server or to get a slave
  #   or arbiter
  # - default is to get a master server
  #-----------------------------------------------------------------------------

#TODO use read/write concern for selection
#TODO must break loop when nothing is found

  # Read/write concern selection
  multi method select-server (
    BSON::Document:D :$read-concern!
    --> MongoDB::Server
  ) {

    self.select-server;
  }

  #-----------------------------------------------------------------------------
  # State of server selection
  multi method select-server (
    ServerStatus:D :$needed-state!,
    Int :$check-cycles is copy = -1
    --> MongoDB::Server
  ) {

#say "$*THREAD.id() select-server";
    self!check-discovery-process;
#say "$*THREAD.id() select-server check done";

    my Hash $h;

    WHILELOOP:
    while $check-cycles != 0 {

      # Take this into the loop because array can still change, might even
      # be empty when hastely called right after new()
      my Array $server-names = $!rw-sem.reader(
        'servers', {
           [$!servers.keys];
         }
       );
#say "$*THREAD.id() select-server {@$server-names}";
      for @$server-names -> $msname {
        my Hash $shash = $!rw-sem.reader(
          'servers', {
#say "$*THREAD.id() select-server :needed-state, {$msname//'-'}";
            my Hash $h;
            if $!servers{$msname}.defined {
#say "$*THREAD.id() select-server :needed-state, $!servers{$msname}<status>";
              $h = $!servers{$msname};
            }

            else {
              $h = {};
            }

            $h;
          }
        );

        if $shash<status> == $needed-state {
          $h = $shash;
          last WHILELOOP;
        }
      }

      $check-cycles--;
      sleep 1;
    }

    if $h.defined and $h<server> {
      info-message("Server $h<server>.name() selected");
    }

    else {
      error-message('No typed server selected');
    }

    $h<server> // MongoDB::Server;
  }

  #-----------------------------------------------------------------------------
  # Default master server selection
  multi method select-server (
    Int :$check-cycles is copy = -1
    --> MongoDB::Server
  ) {

    self!check-discovery-process;

    my Hash $h;
    my Str $msname;

    # When $check-cycles in not set it will be -1, therefore $check-cycles
    # will not reach 0 and loop becomes infinite.
    while $check-cycles != 0 {
      $msname = $!rw-sem.reader( 'master', {$!master-servername;});

#say "$*THREAD.id() select-server, {$msname//'-'}";
      if $msname.defined {
        $h = $!rw-sem.reader( 'servers', {$!servers{$msname};});
        last;
      }

      $check-cycles--;
#prompt("type return to continue ...");
      sleep(1.5);
    }

    $h<server> // MongoDB::Server;
  }

  #-----------------------------------------------------------------------------
  # Check if background process is still running
  method !check-discovery-process ( ) {

    if $!Background-discovery.status ~~ any(Broken|Kept) {
      fatal-message(
        'Discovery stopped ' ~
        ($!Background-discovery.status ~~ Broken
                         ?? $!Background-discovery.cause
                         !! ''
        )
      );
    }
  }

  #-----------------------------------------------------------------------------
  method database (
    Str:D $name, BSON::Document :$read-concern
    --> MongoDB::Database
  ) {

    my BSON::Document $rc =
       $read-concern.defined ?? $read-concern !! $!read-concern;

    MongoDB::Database.new( :client(self), :name($name), :read-concern($rc));
  }

  #-----------------------------------------------------------------------------
  method collection (
    Str:D $full-collection-name, BSON::Document :$read-concern
    --> MongoDB::Collection
  ) {
#TODO check for dot in the name

    my BSON::Document $rc =
       $read-concern.defined ?? $read-concern !! $!read-concern;

    ( my $db-name, my $cll-name) = $full-collection-name.split( '.', 2);

    my MongoDB::Database $db .= new(
      :client(self),
      :name($db-name),
      :read-concern($rc)
    );

    return $db.collection( $cll-name, :read-concern($rc));
  }

  #-----------------------------------------------------------------------------
  # Forced cleanup
  method cleanup ( ) {

    # stop loop and wait for exit
    $!repeat-discovery-loop = False;
    $!Background-discovery.result;

    # Remove all servers concurrently. Shouldn't be many per client.
    $!rw-sem.writer(
      'servers', {

        for $!servers.values -> Hash $srv-struct {
          if $srv-struct<server>.defined {
            # Stop monitoring on server
            debug-message("cleanup server $srv-struct<server>.name()");
            $srv-struct<server>.cleanup;
            $srv-struct<server> = Nil;
          }
        }
      }
    );

    $!servers = Nil;
    $!todo-servers = Nil;
    $!client-tap = Nil;

    debug-message("Client destroyed");
  }
}

