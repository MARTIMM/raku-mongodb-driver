use v6.c;

use MongoDB;
use MongoDB::Database;

use BSON::Document;
use Digest::MD5;
use Digest::HMAC;
use OpenSSL::Digest;
use Base64;

#-------------------------------------------------------------------------------
# See https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst#authentication
#
unit package MongoDB;

class MongoDB::Authenticate {

  has MongoDB::Database $.database;
  has MongoDB::Database $!db-admin;

  #---------------------------------------------------------------------------
  #
  submethod BUILD ( MongoDB::Database :$database ) {

# TODO validate name
    $!database = $database;
    $!db-admin = $database.client.database('admin');
  }

  #---------------------------------------------------------------------------
  method authenticate ( Str:D :$username, Str :$password --> BSON::Document ) {

#TODO get version to see if MONGODB-CR or SCRAM-SHA1 is needed

    my MongoDB::Collection $u = $!db-admin.collection('system.users');
    my MongoDB::Cursor $uc = $u.find( :criteria( user => $username,));
    my BSON::Document $doc = $uc.fetch;
#`{{
    #Sample return exampleBSON::Document.new((
      _id => "test.site-admin",
      user => "site-admin",
      db => "test",
      credentials => BSON::Document.new((
        SCRAM-SHA-1 => BSON::Document.new((
          iterationCount => 10000,
          salt => "Mpisumty8wQK7oi9KtDfeA==",
          storedKey => "bG4ozEGjYMXqcF/NfHGEbdPoRZc=",
          serverKey => "hyrU91E3C+ufBlogxNYn37MpDJY=",
        )),
      )),
      customData => BSON::Document.new((
        user-type => "site-admin",
      )),
      roles => [
            BSON::Document.new((
          role => "userAdminAnyDatabase",
          db => "admin",
        )),
      ],
    ))
}}
    if $doc<credentials><SCRAM-SHA-1>:exists {
      my BSON::Document $creds = $doc<credentials><SCRAM-SHA-1>;
      my Int $i = $creds<iterationCount>;
      my Str $salt = $creds<salt>;
      my $client-key = self!compute-client-key(
        :$username, :$password, :$i, :$salt, :H(&sha1)
      );
say "Auth 0: $i, $salt, ", $client-key;

    }
    
    else {
      fatal-message('Method to login not yet implemented');
    }


    $doc = $!db-admin.run-command(BSON::Document.new: (getnonce => 1));
say "N0: ", $doc.perl;
    if $doc<ok>.Bool == False {
      error-message(
        $doc<errmsg>, :code($doc<code>),
        oper-data => "getnonce => 1",
        collection-ns => $!database.name
      );
    }

    my $part1a = ([~] $username, ':mongo:', $password).encode;
    my Buf $b = Digest::MD5::md5($part1a);
    my Str $part1b = @($b)>>.fmt('%02x').join;
say "P1: $part1b";

    my $part2a = ([~] $doc<nonce>, $username, $part1b).encode;
    $b = Digest::MD5::md5($part2a);
    my Str $part2b = @($b)>>.fmt('%02x').join;

#      my Str $pw-md5 = Digest::MD5.md5_hex( [~] $username, ':mongo:', $password);
#      my Buf $b = Digest::MD5::md5( [~] $doc<nonce>, $username, $pw-md5);

    $doc = $!database.run-command: (
      authenticate => 1,
      user => $username,
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
        oper-data => "user => $username, mechanism => 'SCRAM-SHA-1', nonce => $doc<nonce>",
        collection-ns => $!database.name
      );
    }

    $doc;
  }

  #---------------------------------------------------------------------------
  method !compute-client-key (
    Str:D :$username,
    Str:D :$password,
    Int:D :$i,
    Str:D :$salt,
    Callable:D :$H
 #   --> BSON::Document
  ) {

    my $client-key;

    my Str $hashed-password = Digest::MD5.md5_hex(
      [~] $username, ':mongo:', $password
    );
say "SS1 1: $hashed-password";

    my $salted-password = self!pbkdf2(
      self!normalize($hashed-password), $salt, $i, &$H
    );
say "SS1 2: $salted-password";

    $client-key = hmac( $salted-password, "Client Key", &$H);
say "SS1 3: $client-key";
    
    $client-key;
  }

  #-------------------------------------------------------------------------------
  # Function Hi() or PBKDF2 (Password Based Key Derivation Function) because of
  # the use of HMAC. See rfc 5802, 2898.
  #
  # PRF is HMAC (Pseudo random function)
  # dklen == output length of hmac == output length of H() which is sha1
  #
  method !pbkdf2 ( Str $s-str, Str $s-salt, Int $i, Callable $H --> Buf ) is export {

    my Buf $str = Buf.new($s-str.encode);
    my Buf $salt = Buf.new($s-salt.encode);

    my Buf $Hi = hmac( $str, $salt ~ Buf.new(1), &$H);
say $Hi.elems;

    my Buf $Ui = $Hi;
    for 2 ..^ $i -> $c {
      $Ui = hmac( $str, $Ui, &$H);
      for ^($Hi.elems) -> $Hi-i {
        $Hi[$Hi-i] = $Hi[$Hi-i] +^ $Ui[$Hi-i];
      }
    }

  say $Hi.elems, ', ', $Hi;
    $Hi;
  }
  
  #-------------------------------------------------------------------------------
  method !normalize ( Str:D $s --> Str ) {
  
    $s;
  }
}
