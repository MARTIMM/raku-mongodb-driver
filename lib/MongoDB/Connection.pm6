use v6;

# use lib '/home/marcel/Languages/Perl6/Projects/BSON/lib';

use MongoDB;
use MongoDB::Database;
use BSON::Document;

package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Connection {

    has IO::Socket::INET $!sock;
    has Exception $.status = Nil;
    
#TODO refine this method of using server name/port, connection pooling etc
    # All users of the object have the same server and port
    #
    my Str $server-name;
    my Int $server-port;

    #---------------------------------------------------------------------------
    #
    multi submethod BUILD ( Str :$host, Int :$port, Str :$url ) {

      # Test for the server name. When no cases match a previously stored
      # server name is taken
      #
      if !?$host and !?$server-name and !?$url {
        $server-name = 'localhost';
      }
      
      elsif ?$host {
        $server-name = $host;
      }
      
      elsif ?$url {
#TODO process url
        $server-name = 'localhost';
        $server-port = 27017;
      }

      # Test for the server port. When no cases match a previously stored
      # server port is taken
      #
      if !$port.defined and !$server-port.defined {
        $server-port = 27017;
      }
      
      elsif $port.defined and 0 <= $port <= 65535 {
        $server-port = $port;
      }

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
        if ? $!sock {
          $!sock.close;
          $!sock = IO::Socket::INET;
        }

        $!status = Nil;
        $!sock .= new( :host($server-name), :port($server-port));
        CATCH {
          default {
            $!status = X::MongoDB.new(
              :error-text("Failed to connect to $server-name at port $server-port"),
              :oper-name<new>,
              :severity(MongoDB::Severity::Error)
            );
          }
        }
      }

      unless ? $!status {
        # Get build information and store it
        #
        $MongoDB::build-info =
          self.database('admin').run-command: (buildinfo => 1);

        # Extract version from build-info
        #
        my BSON::Document $version .= new: (
          <release1 release2 revision> Z=> (
            for $MongoDB::build-info<version>.split('.') {.Int}
          )
        );

        $version<release-type> = $version<release2> %% 2
                                 ?? 'production'
                                 !! 'development'
                                 ;
        $MongoDB::version = $version;
      }
    }

#    multi submethod BUILD ( |c ) {
#say "Connection caption: {c}";
#    }

    #---------------------------------------------------------------------------
    #
    method send ( Buf:D $b --> Nil ) {
      $!sock.write($b);
    }

    #---------------------------------------------------------------------------
    #
    method receive ( Int $nbr-bytes --> Buf ) {
      return $!sock.read($nbr-bytes);
    }

    #---------------------------------------------------------------------------
    # Get a database object
    #
    method database ( Str:D $name --> MongoDB::Database ) {
      return MongoDB::Database.new(
        :connection(self),
        :name($name)
      );
    }
  }
}

