use v6;
use Digest::MD5;
use MongoDB;
use MongoDB::Uri;
use MongoDB::ClientIF;
use MongoDB::Server;
use MongoDB::AdminDB;
use MongoDB::Wire;
use BSON::Document;

package MongoDB {

  our $db-admin;

  #-----------------------------------------------------------------------------
  #
  class Client is MongoDB::ClientIF {

    my Array $servers;
    my Array $server-discovery;

  our $db-admin;

    # Reserved servers. select-server finds a server using some directions
    # such as read concerns or even direct host:port string. Structure is
    # MD5 code => servers[$server entry]
    #
    has Hash $!server-reservations;

    #---------------------------------------------------------------------------
    # This class is a singleton class
    #
    my MongoDB::Client $client-object;
    my Bool $master-search-in-process = False;

    method new ( ) {

      die X::MongoDB.new(
        error-text => "This is a singleton, Please use instance()",
        oper-name => 'MongoDB::Client.new()',
        severity => MongoDB::Severity::Fatal
      );
    }

    #---------------------------------------------------------------------------
    submethod instance ( Str :$uri = 'mongodb://' --> MongoDB::Client )  {
      
      #my $db-admin = 
      initialize();

      # Parse the uri and get info in $uri-obj.server-data;
      # Fields are protocol, username, password, servers, database and options
      #
      my MongoDB::Uri $uri-obj .= new(:$uri);

      # Copy some fields into a local $server-data hash which is handed over
      # to the server object.
      #
      my @item-list = <username password database options>;
      my Hash $server-data = %(@item-list Z=> $uri-obj.server-data{@item-list});

      # Background process to discover hosts only if there are new servers
      # to be discovered or that new non default cases are presnted.
      #
      if $uri-obj.server-data<servers>.elems {

        for @($uri-obj.server-data<servers>) -> Hash $sdata {
          $server-discovery.push: Promise.start( {
              my MongoDB::Server $server;

              try {
                $server .= new(
                  :client($client-object),
                  :host($sdata<host>),
                  :port($sdata<port>),
                  :db-admin($MongoDB::db-admin),
                  :$server-data
                );

                $MongoDB::logger.mlog(
                  message => "Server $sdata<host>:$sdata<port> connected",
                  oper-name => 'Client.instance',
                );

                # Only show the error but do not handle
                #
                CATCH {
                  .say;
                  $MongoDB::logger.mlog(
                    message => "Server $sdata<host>:$sdata<port> not connected",
                    oper-name => 'Client.instance'
                  );
                }
              }

              # Return server object
              #
              $server;
            }
          );
        }
      }

      return $client-object;
    }

    #---------------------------------------------------------------------------
    sub initialize ( ) { #--> MongoDB::AdminDB ) {

      # If the Client object isn't created yet then make it and
      # define some variables
      #
      unless $client-object.defined {
        $client-object = MongoDB::Client.bless;
        
        # Wire is also a Singleton and needs this object to get a Server
        # using select-server()
        #
        MongoDB::Wire.instance.set-client($client-object);

        # The admin database is given to each server to get server data
        #
        $MongoDB::db-admin .= new;

        $servers = [];
        $server-discovery = [];

        $MongoDB::logger.mlog(
          message => "Client initialized",
          oper-name => 'Client.initialize'
        );
      }
      
#      return $!db-admin;
    }

    #---------------------------------------------------------------------------
    #
    method select-server (
      Bool :$need-master = False,
      BSON::Document :$read-concern = BSON::Document.new
      --> Str
    ) {

      my MongoDB::Server $server;
      my Int $server-entry;

      # Read all Kept promises and store Server objects in $servers array
      #
      while !$server.defined {
        my Bool $is-master = False;

        # First go through all Promises to see if there are still
        # Server objects in the making
        #
        loop ( my $pi = 0; $pi < $server-discovery.elems; $pi++ ) {
          my $promise = $server-discovery[$pi];

          # Skip all undefined entries in the array
          #
          #next unless $promise ~~ Promise and $promise.defined;

          # If promise is kept, the Server object has been created 
          #
          if $promise.status ~~ Kept {

            # Get the Server object from the promise result and check
            # its status. When True, the Server object could make a
            # proper connection to the mongo server.
            #
            $server = $promise.result;
            $servers.push: $server if $server.status;
            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);

            $MongoDB::logger.mlog(
              message => (
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " saved"
              ),
              oper-name => 'Client.select-server'
            );
          }

          # When broken throw away result
          #
          elsif $promise.status == Broken {
            my $s = $server-discovery[$pi].result;
            $server-discovery[$pi] = Nil;
            $server-discovery.splice( $pi, 1);

            $MongoDB::logger.mlog(
              message => (
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " not saved"
              ),
              oper-name => 'Client.select-server'
            );
          }

          # When planned look at it in next while cycle
          #
          elsif $promise.status == Planned {
            $MongoDB::logger.mlog(
              message => "Promise $pi still running",
              oper-name => 'Client.select-server'
            );
          }
        }

        # Walk through servers array and return server
        #
        $server = Nil;

        loop ( my $si = 0; $si < $servers.elems; $si++) {
          $server = $servers[$si];
          $server-entry = $si;

          # Guard the operation because the request ends up in Wire which
          # will ask for a server using this select-server() method.
          #
          if !$master-search-in-process {
            $master-search-in-process = True;
#            $is-master = $server.check-is-master;
            $master-search-in-process = False;
          }

          if !$need-master or ($need-master and $is-master) {
            $MongoDB::logger.mlog(
              message => (
                [~] "Server $pi ", $server.server-name,
                ':', $server.server-port, " selected"
              ),
              oper-name => 'Client.select-server'
            );

            last;
          }
        }

        unless $server.defined {
          if $server-discovery.elems {
            $MongoDB::logger.mlog(
              message => "No server found, wait for running discovery",
              oper-name => 'Client.select-server'
            );
            sleep 1;
          }

          else {
            $MongoDB::logger.mlog(
              message => "No server found, discovery data exhausted, stopping",
              oper-name => 'Client.select-server',
              severity => MongoDB::Severity::Info
            );

            last;
          }
        }
      }

      my Str $reservation-code;
      $reservation-code = self!set-reservation( $server, $server-entry)
        if $server.defined;

      return $reservation-code;
    }

    #---------------------------------------------------------------------------
    #
    method !set-reservation(
      MongoDB::Server:D $server,
      Int:D $server-entry
      --> Str
    ) {
      my $md5 = Digest::MD5.new;
      
      my Str $reservation-code = $md5.md5_hex(
        [~] $server.server-name, $server.server-port,
            $server-entry, now.DateTime.Str
      );

      $!server-reservations{$reservation-code} = $server;
      return $reservation-code;
    }

    #---------------------------------------------------------------------------
    #
    method get-server ( Str:D $reservation-code --> MongoDB::Server ) {
      return $!server-reservations{$reservation-code};
    }

    #---------------------------------------------------------------------------
    #
    method clear-reserved-server ( Str:D $reservation-code ) {
      $!server-reservations{$reservation-code}:delete;
    }

    #---------------------------------------------------------------------------
    #
    method remove-server ( MongoDB::Server $server ) {
      loop ( my $si = 0; $si < $servers.elems; $si++) {
        if $servers[$si] === $server {
          undefine $server;
          $servers.splice( $si, 1);
        }
      }
    }
  }
}

