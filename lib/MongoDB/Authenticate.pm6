use v6;
use MongoDB::Database;
use Digest::MD5;

#-------------------------------------------------------------------------------
#
package MongoDB {

  class MongoDB::Authenticate {

    has MongoDB::Database $.database;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( MongoDB::Database :$database ) {

      # TODO validate name
      $!database = $database;
    }

    #---------------------------------------------------------------------------
    #
    method authenticate ( Str:D :$user, Str :$password --> Hash ) {
      my Pair @req = (getnonce => 1);
      my Hash $doc = $!database.run-command(@req);
say "N0: ", $doc.perl;
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'login',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      @req = (
        authenticate => 1,
        user => $user,
#        mechanism => 'MONGODB-CR',
        mechanism => 'SCRAM-SHA-1',
        nonce => $doc<nonce>,
        key => Digest::MD5.md5_hex(
                 [~] $doc<nonce>, $user,
                     Digest::MD5.md5_hex( [~] $user, ':mongo:', $password)
               )
      );

      $doc = $!database.run-command(@req);
say "N2: ", $doc.perl;
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'login',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method logout ( Str:D :$user --> Hash ) {
      my Pair @req = (logout => 1);
      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'logout',
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      return $doc;
    }
  }
}
