use v6.c;
use Digest::MD5;
use BSON::Document;
use MongoDB;
use MongoDB::Database;

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
    method authenticate ( Str:D :$user, Str :$password --> BSON::Document ) {
      my Pair @req = (getnonce => 1);
      my Hash $doc = $!database.run-command(@req);
say "N0: ", $doc.perl;
      if $doc<ok>.Bool == False {
        error-message(
          $doc<errmsg>, :code($doc<code>),
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      my Buf $b = Digest::MD5::md5(
        [~] $doc<nonce>, $user,
        Digest::MD5.md5_hex( [~] $user, ':mongo:', $password)
      );

      @req = (
        authenticate => 1,
        user => $user,
#        mechanism => 'MONGODB-CR',
        mechanism => 'SCRAM-SHA-1',
        nonce => $doc<nonce>,
        key => $b>>.fmt('%02x').join;
      );

      $doc = $!database.run-command(@req);
say "N2: ", $doc.perl;
      if $doc<ok>.Bool == False {
        error-message(
          $doc<errmsg>, :code($doc<code>),
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      return $doc;
    }
  }
}


=finish
#`{{

    #---------------------------------------------------------------------------
    #
    method logout ( Str:D :$user --> Hash ) {
      my Pair @req = (logout => 1);
      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        return error-message(
          $doc<errmsg>, :code($doc<code>),
          oper-data => @req.perl,
          collection-ns => $!database.name
        );
      }

      return $doc;
    }

}}

