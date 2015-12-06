use v6;

# use lib '/home/marcel/Languages/Perl6/Projects/BSON/lib';

use MongoDB;
use MongoDB::Database;
use BSON::EDCTools;

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
    method _send ( Buf:D $b, Bool $has_response --> Any ) {
      $!sock.write($b);

      # some calls do not expect response
      #
      return unless $has_response;

      # check response size
      #
      my $index = 0;
      my Buf $l = $!sock.read(4);
      my Int $w = decode-int32( $l.list, $index) - 4;

      # receive remaining response bytes from socket
      #
      return $l ~ $!sock.read($w);
    }

    #---------------------------------------------------------------------------
    #
    method database ( Str:D $name --> MongoDB::Database ) {
      return MongoDB::Database.new(
        :connection(self),
        :name($name)
      );
    }

    #---------------------------------------------------------------------------
    # List databases using MongoDB db.runCommand({listDatabases: 1});
    #
    method list_databases ( --> Array ) is DEPRECATED('list-databases') {
      return self.list-databases();
    }

    method list-databases ( --> Array ) {

      $!status = Nil;

      my $database = self.database('admin');
      my Pair @req = listDatabases => 1;
      my Hash $doc = $database.run-command(@req);
      if $doc<ok>.Bool == False {
        $!status = X::MongoDB.new(
          error-text => $doc<errmsg>,
          error-code => $doc<code>,
          oper-name => 'listDatabases',
          oper-data => @req.perl,
          collection-ns => 'admin.$cmd',
          severity => MongoDB::Severity::Error
        );
      }

      return @($doc<databases>);
    }

    #---------------------------------------------------------------------------
    # Get database names.
    #
    method database_names ( --> Array ) is DEPRECATED('database-names') {
      return self.database-names();
    }

    method database-names ( --> Array ) {
      my @db_docs = self.list-databases();
      my @names = map {$_<name>}, @db_docs; # Need to do it like this otherwise
                                            # returns List instead of Array.
      return @names;
    }

    #---------------------------------------------------------------------------
    # Get mongodb version. When making a new connection the version is store
    # at $MongoDB::version for later lookups by other code whithout the need
    # of quering the server all the time. See BUILD above.
    #
    method version ( --> Hash ) {
      my Hash $doc = self.build-info;
      my Hash $version = hash( <release1 release2 revision>
                               Z=> (for $doc<version>.split('.') {Int($_)})
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
    method build_info ( --> Hash ) is DEPRECATED('build-info') {
      return self.build-info();
    }

    method build-info ( --> Hash ) {

      $!status = Nil;

      my $database = self.database('admin');
      my Pair @req = buildinfo => 1;
      my Hash $doc = $database.run-command(@req);
      if $doc<ok>.Bool == False {
        $!status = X::MongoDB.new(
          error-text => $doc<errmsg>,
          error-code => $doc<code>,
          oper-name => 'build-info',
          oper-data => @req.perl,
          collection-ns => 'admin.$cmd',
          severity => MongoDB::Severity::Error
        );
      }

      return $doc;
    }
  }
}

