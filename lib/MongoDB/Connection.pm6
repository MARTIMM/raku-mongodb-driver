use v6;

# use lib '/home/marcel/Languages/Perl6/Projects/BSON/lib';

use MongoDB;
use BSON::Document;

package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Connection {

#    has IO::Socket::INET $!sock;
    has Exception $.status = Nil;

#TODO refine this method of using server name/port, connection pooling etc
    # All users of the object have the same server and port
    #
    my Str $server-name;
    my Int $server-port;
    my IO::Socket::INET $sock;

    #---------------------------------------------------------------------------
    #
    multi submethod BUILD (
      Str :$host,
      Int :$port where (!$_.defined or 0 <= $_ <= 65535),
      Str :$url
    ) {
#say "H & P: {$host//'nh'}, {$port//'np'}";
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

      elsif $port.defined {
        $server-port = $port;
      }

#say "H & P: $server-name, $server-port" ;
      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
#        if ? $sock {
#          $sock.close;
#          $sock = IO::Socket::INET;
#        }

        $!status = Nil;
#TODO when other host, and/or port and/or url is set then take other socket
#       and close used sock before opening another
        $sock .= new( :host($server-name), :port($server-port))
          unless $sock.defined;

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
#`{{        # Get build information and store it
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
}}

#TODO refactor code into the proper module, perhaps Database

        my BSON::Document $version .= new: (
          <release1 release2 revision> Z=> ( 3, 0, 5)
        );

        $version<release-type> = 'production';
        $MongoDB::version = $version;
      }
    }

    #---------------------------------------------------------------------------
    #
    method send ( Buf:D $b --> Nil ) {
      $sock.write($b);
    }

    #---------------------------------------------------------------------------
    #
    method receive ( Int $nbr-bytes --> Buf ) {
      return $sock.read($nbr-bytes);
    }

    #---------------------------------------------------------------------------
    #
    method close ( ) {
      if $sock.defined {
        $sock.close;
        $sock = Nil;
      }
    }
  }
}

