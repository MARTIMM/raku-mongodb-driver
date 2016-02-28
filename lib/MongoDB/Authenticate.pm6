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

      my BSON::Document $doc = $!database.run-command: (getnonce => 1);
say "N0: ", $doc.perl;
      if $doc<ok>.Bool == False {
        error-message(
          $doc<errmsg>, :code($doc<code>),
          oper-data => "getnonce => 1",
          collection-ns => $!database.name
        );
      }

      my $part1a = ([~] $user, ':mongo:', $password).encode;
      my Buf $b = Digest::MD5::md5($part1a);
      my Str $part1b = @($b)>>.fmt('%02x').join;
say "P1: $part1b";

      my $part2a = ([~] $doc<nonce>, $user, $part1b).encode;
      $b = Digest::MD5::md5($part2a);
      my Str $part2b = @($b)>>.fmt('%02x').join;

#      my Str $pw-md5 = Digest::MD5.md5_hex( [~] $user, ':mongo:', $password);
#      my Buf $b = Digest::MD5::md5( [~] $doc<nonce>, $user, $pw-md5);

      $doc = $!database.run-command: (
        authenticate => 1,
        user => $user,
#        mechanism => 'MONGODB-CR',
#        mechanism => 'SCRAM-SHA-1',
#        mechanism => 'SCRAM',
        nonce => $doc<nonce>,
#        key => $b>>.fmt('%02x').join;
        key => $part2b;
      );

say "N2: ", $doc.perl;
      if $doc<ok>.Bool == False {
        error-message(
          $doc<errmsg>, :code($doc<code>),
          oper-data => "user => $user, mechanism => 'SCRAM-SHA-1', nonce => $doc<nonce>",
          collection-ns => $!database.name
        );
      }

      $doc;
    }
  }
}
