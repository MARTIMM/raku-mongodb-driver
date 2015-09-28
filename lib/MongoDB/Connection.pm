use v6;

#BEGIN {
#  @*INC.unshift('/home/marcel/Languages/Perl6/Projects/BSON/lib');
#}

use MongoDB::Database;
use BSON::EDCTools;

package MongoDB {
  #-----------------------------------------------------------------------------
  #
  class X::MongoDB::Connection is Exception {
    has $.error-text;                     # Error text
    has $.error-code;                     # Error code if from server
    has $.oper-name;                      # Operation name
    has $.oper-data;                      # Operation data
    has $.database-name;                  # Database name

    method message () {
      return [~] "\n$!oper-name\() error:\n",
                 "  $!error-text",
                 $.error-code.defined ?? "\($!error-code)" !! '',
                 $!oper-data.defined ?? "\n  Data $!oper-data" !! '',
                 "\n  Database '$!database-name'\n"
                 ;
    }
  }

  #-----------------------------------------------------------------------------
  #
  class MongoDB::Connection {

    has IO::Socket::INET $!sock;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str :$host = 'localhost', Int :$port = 27017 ) {
      $!sock = IO::Socket::INET.new( host => $host, port => $port );
    #  $!sock = IO::Socket::INET.new( host => "$host/?connectTimeoutMS=3000",
    # port => $port );
    }

    #---------------------------------------------------------------------------
    #
    method _send ( Buf $b, Bool $has_response --> Any ) {
      $!sock.write($b);

      # some calls do not expect response
      #
      return unless $has_response;

      # check response size
      #
      my $index = 0;
      my Buf $l = $!sock.read(4);
      my Int $w = decode_int32( $l.list, $index) - 4;

      # receive remaining response bytes from socket
      #
      return $l ~ $!sock.read($w);
    }

    #---------------------------------------------------------------------------
    #
    method database ( Str $name --> MongoDB::Database ) {
      return MongoDB::Database.new(
        :connection(self),
        :name($name)
      );
    }

    #---------------------------------------------------------------------------
    # List databases using MongoDB db.runCommand({listDatabases: 1});
    #
    method list_databases ( --> Array ) {
      my $database = self.database('admin');
      my Pair @req = listDatabases => 1;
      my Hash $doc = $database.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB::Connection.new(
          error-text => $doc<errmsg>,
          oper-name => 'list_databases',
          oper-data => @req.perl,
          database-name => 'admin.$cmd'
        );
      }

      return @($doc<databases>);
    }

    #---------------------------------------------------------------------------
    # Get database names.
    #
    method database_names ( --> Array ) {
      my @db_docs = self.list_databases();
      my @names = map {$_<name>}, @db_docs; # Need to do it like this otherwise
                                            # returns List instead of Array.
      return @names;
    }

    #---------------------------------------------------------------------------
    # Get mongodb version.
    #
    method version ( --> Hash ) {
      my Hash $doc = self.build_info;
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
    method build_info ( --> Hash ) {
      my $database = self.database('admin');
      my Pair @req = buildinfo => 1;
      my Hash $doc = $database.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB::Connection.new(
          error-text => $doc<errmsg>,
          oper-name => 'build_info',
          oper-data => @req.perl,
          collection-name => 'admin.$cmd'
        );
      }

      return $doc;
    }
  }
}

