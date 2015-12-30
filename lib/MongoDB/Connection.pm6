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

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str :$host = 'localhost', Int :$port = 27017 ) {

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
        if ? $!sock {
          $!sock.close;
          $!sock = IO::Socket::INET;
        }

        $!status = Nil;
        $!sock .= new( :$host, :$port);
        CATCH {
          default {
            $!status = X::MongoDB.new(
              :error-text("Failed to connect to $host at port $port"),
              :oper-name<new>
              :severity(MongoDB::Severity::Error)
            );
          }
        }
      }

      $MongoDB::version = self.version unless ? $!status;
    }

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

    #---------------------------------------------------------------------------
    # Get mongodb version. When making a new connection the version is store
    # at $MongoDB::version for later lookups by other code whithout the need
    # of quering the server all the time. See BUILD above.
    #
    method version ( --> Hash ) {
      my BSON::Document $doc = self.build-info;
      my Hash $version = hash( <release1 release2 revision>
                               Z=> (for $doc<version>.split('.') {.Int})
                             );
      $version<release-type> = $version<release2> %% 2
                               ?? 'production'
                               !! 'development'
                               ;
      return $version;
    }

    #---------------------------------------------------------------------------
    # Get mongodb server info.
    #
    method build-info ( --> BSON::Document ) {

      $!status = Nil;

      my $database = self.database('admin');
      my BSON::Document $req .= new: (buildinfo => 1);
      return $database.run-command($req);
    }
  }
}
