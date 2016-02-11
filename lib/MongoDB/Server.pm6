use v6;
use MongoDB;
use MongoDB::Object-store;
use MongoDB::Socket;
use MongoDB::ClientIF;
use MongoDB::DatabaseIF;
use BSON::Document;

package MongoDB {

  class Server {

    has Str $.server-name;
    has Int $.server-port;

    # As in MongoDB::Uri without servers key. So there are
    # database, username, password and options
    #
    has Hash $!uri-data;

    has MongoDB::Socket @!sockets;
    has Int $.max-sockets is rw where $_ >= 3;

    has Bool $.is-master = False;
    has BSON::Document $!monitor-doc;
    has Duration $!weighted-mean-rtt .= new(0);

    has MongoDB::DatabaseIF $!db-admin;
    has MongoDB::ClientIF $!client;

    # Variables to control infinit monitoring actions
    #
    has Channel $!channel;
    has Promise $!promise-monitor;
    has Semaphore $!server-monitor-control;

    submethod BUILD (
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
      Int :$max-sockets where $_ >= 3 = 3,
      Hash :$uri-data,
      MongoDB::DatabaseIF:D :$db-admin,
      MongoDB::ClientIF:D :$client
    ) {
      $!db-admin = $db-admin;
      $!client = $client;
      $!server-name = $host;
      $!server-port = $port;
      $!max-sockets = $max-sockets;
      $!uri-data = $uri-data;
      $!channel = Channel.new;

      $!server-monitor-control .= new(1);

      # IO::Socket::INET throws an exception when things go wrong. Need to
      # catch this higher up.
      #
      my IO::Socket::INET $sock .= new(
        :host($!server-name),
        :port($!server-port)
      );

      # Must close this because of thread errors when reading the socket
      # Besides the sockets are encapsulated in Socket and kept in an array.
      #
      $sock.close;
    }

    #---------------------------------------------------------------------------
    # Search in the array for a closed Socket.
    #
    method get-socket ( --> MongoDB::Socket ) {

      my MongoDB::Socket $s;

      for @!sockets -> $sock {
        if ! $sock.is-open {
          $s = $sock;
          last;
        }
      }

      # If none is found insert a new Socket in the array
      #
      if ! $s.defined {

        # Protect against too many open sockets.
        #
        if @!sockets.elems >= $!max-sockets {
          return fatal-message("Too many sockets opened, max is $!max-sockets");
        }

        $s .= new( :$!server-port, :$!server-name);
        @!sockets.push($s);
      }

      # Return a usable socket which is opened. The user has the responsibility
      # to close the socket. Otherwise there will be new sockets created every
      # time get-socket() is called.
      #
      $s.open();

      return $s;
    }

    #---------------------------------------------------------------------------
    # Is called from Client in a separate thread. This is no user facility!
    #
    method initial-poll ( --> Bool ) {

      my Str $server-ticket = $!client.store.store-object(self);

      # Calculation of mean Return Trip Time
      #
#say "\nPoll isMaster, $server-ticket";
      my BSON::Document $doc = $!db-admin._internal-run-command(
        BSON::Document.new((isMaster => 1)),
        :$server-ticket
      );
#say "Done polling isMaster";
#say $doc.perl;

      # Set master type and store whole doc
      #
      $!monitor-doc = $doc;
      $!is-master = $doc<ismaster> if ?$doc<ismaster>;

      # Test if this server fits the bill
      #
      my Bool $accept-server = False;
      if $!uri-data<options><replicaSet>:exists
         and $doc<setName>:exists
         and $doc<setName> eq $!uri-data<options><replicaSet> {

        $accept-server = True;
      }

      elsif $!uri-data<options><replicaSet>:!exists
            and $doc<setName>:!exists {

        $accept-server = True;
      }

      return $accept-server;
    }

    #---------------------------------------------------------------------------
    # Run this on a separate thread because it lasts until this program
    # atops or the server shuts down.
    #
    method monitor-server ( ) {

      # Set the lock so the code will only be started once. When server or
      # program stops(controlled), the code is terminated via a channel.
      #
      return unless $!server-monitor-control.try_acquire;

      $!promise-monitor .= start( {
          my Instant $t0;
          my BSON::Document $doc;
          my Duration $rtt;

          # As long as the server lives test it. Changes are possible when 
          # master changes servers.
          #
          while 1 {

            # Temporary try block to catch typos
            try {

              # First things first Zzzz...
              #
              sleep 10;

              my Str $server-ticket = $!client.store.store-object(self);

              # Calculation of mean Return Trip Time
              #
              $t0 = now;
#say "\nRun isMaster, $server-ticket";
              $doc = $!db-admin._internal-run-command(
                BSON::Document.new((isMaster => 1)),
                :$server-ticket
              );
#say "Done isMaster";
              $rtt = now - $t0;
              $!weighted-mean-rtt .= new(0.2 * $rtt + 0.8 * $!weighted-mean-rtt);
              debug-message(
                "Weighted mean RTT: $!weighted-mean-rtt for server {self.name}"
              );

              # Set master type and store whole doc
              #
              $!monitor-doc = $doc;
              $!is-master = $doc<ismaster> if ?$doc<ismaster>;
#say $doc.perl;

              # Then check the channel to see if there is a stop command. If so
              # exit the while loop. Take a nap otherwise.
              #
              my $cmd = $!channel.poll;
              last if ?$cmd and $cmd eq 'stop';

              CATCH {

                default {
                  .say;
                }
              }
            }
          }
        }
      );
    }

    #---------------------------------------------------------------------------
    #
    method shutdown ( Bool :$force = False ) {
      my BSON::Document $doc = $!db-admin.run-command: (
        shutdown => 1,
        :$force
      );
#TODO there is no answer if it succeeds?

      # Suppose that there is only an answer when the server didn't shutdown
      # so what are we doing here ...
      #
      if $doc<ok> {
        $!client.remove-server(self);
      }
    }

    #---------------------------------------------------------------------------
    #
    method perl ( --> Str ) {
      return [~] 'MongoDB::Server.new(', ':host(', $.server-name, '), :port(',
                 $.server-port, '))';
    }

    #---------------------------------------------------------------------------
    #
    method name ( --> Str ) {
      return [~] $.server-name, ':', $.server-port;
    }

    #---------------------------------------------------------------------------
    #
    submethod DESTROY {

      # Send a stop code to the monitor code thread and wait for it to finish
      #
      $!channel.send('stop');
      $!promise-monitor.await;
      undefine $!promise-monitor;

      # Release the lock
      #
      $!server-monitor-control.release;

      # Clear all sockets
      #
      for @!sockets -> $s {
        undefine $s;
      }

      # and channel
      #
      undefine $!channel;
    }
  }
}
