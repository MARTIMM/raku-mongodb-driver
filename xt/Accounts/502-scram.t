#!/usr/bin/env perl6

# RFC           https://tools.ietf.org/html/rfc5802
# MongoDB       https://www.mongodb.com/blog/post/improved-password-based-authentication-mongodb-30-scram-explained-part-1?jmp=docs&_ga=1.111833220.1411139568.1420476116
#               https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst
# Wiki          https://en.wikipedia.org/wiki/Salted_Challenge_Response_Authentication_Mechanism
#               https://en.wikipedia.org/wiki/PBKDF2
# perl5         Unicode::*
#               Authen::*
use v6.c;
use lib 't';
use Test;

use Digest::HMAC;
use OpenSSL::Digest;
use Base64;

use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Users;
use MongoDB::Database;
use MongoDB::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
info-message("Test $?FILE start");
#---------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;

subtest {

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod( 's1', 'authenticate'),
     "Server 1 in auth mode";

}, "Server changed to authentication mode";

#-------------------------------------------------------------------------------
set-exception-process-level(MongoDB::Severity::Debug);

my MongoDB::Client $client = $ts.get-connection(:server(1));

# Setup in 509...t
# 'site-admin', 'B3n@Hurry', role => 'userAdminAnyDatabase', db => 'admin'
# 'Dondersteen', 'w@tD8jeDan', role => 'readWrite', db => 'test'

my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');

my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;

my Str $username = 'Dondersteen';
my Str $password = 'watd0ej3daN';

$doc = $db-admin.run-command(BSON::Document.new: (getnonce => 1));
my Str $nonce = $doc<nonce>;
say "N0: ", " -->> $nonce";

$doc = $db-admin.run-command(BSON::Document.new: (
    saslStart => 1,
    mechanism => 'SCRAM-SHA-1',
    payload => encode-base64( "n,,n=$username,r=$nonce", :str)
  )
);
say "N1: ", $doc.perl;


#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);

=finish

#-------------------------------------------------------------------------------
# PBKDF2 See rfc5802. Where
# PRF is HMAC (Pseudo random function)
# dklen == output length of hmac == output length of H()
#
sub Hi ( Str $s-str, Str $s-salt, Int $i, Callable $H --> Str ) is export {

  my Buf $str = Buf.new($s-str.encode);
  my Buf $salt = Buf.new($s-salt.encode);

  my Buf $Hi = hmac( $str, $salt ~ Buf.new(1), &$H);
#say "H\[1]: ", $Hi;
  my Buf $Ui = $Hi;
#say "U\[1]: ", $Ui;
  for 2 ..^ $i -> $c {
    $Ui = hmac( $str, $Ui, &$H);
#say "U\[$c]: ", $Ui;
    for ^($Hi.elems) -> $Hi-i {
      $Hi[$Hi-i] = $Hi[$Hi-i] +^ $Ui[$Hi-i];
    }
#say "H\[$c]: ", $Hi;
  }

  $Hi.join;
}

#-------------------------------------------------------------------------------
# Function Hi() or PBKDF2 (Password Based Key Derivation Function) because of
# the use of HMAC. See rfc 5802, 2898.
#
# PRF is HMAC (Pseudo random function)
# dklen == output length of hmac == output length of H() which is sha1
#
sub pbkdf2 ( Str $s-str, Str $s-salt, Int $i, Callable $H --> Buf ) is export {

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
sub XOR ( Str $s1, Str $s2 --> Str ) is export {

say $s1, ', ', $s2;
say $s1.chars, ', ', $s2.chars;
  my utf8 $s1-b = $s1.encode;
  my utf8 $s2-b = $s2.encode;
  my Buf $xor-b = Buf.new;
  for ^($s1-b.elems) -> $csi {
#say $csi;
    $xor-b ~= Buf.new($s1-b[$csi] +^ $s2-b[$csi]);
  }

  $xor-b.decode;
}

#-------------------------------------------------------------------------------
# Create account, cannot hav ',' or '=' in string
my Str $username = "user";
my Str $password = "pencil";
#my Str $client-key-s = 'client key';
my Str $client-key-s = $username;

say "Username: ", $username;
say "Password: ", $password;
say "Client key string: ", $client-key-s;

# Server calculates
my Int $iteration-count = 4;
my Str $server-key-s = 'server key';
say "Server key string: ", $server-key-s;

my Str $salt = encode-base64((rand * 1e80).base(36), :str);

my Buf $salted-password = pbkdf2( $password, $salt, $iteration-count, &sha1);
my Buf $client-key = hmac( $salted-password, 'Client Key', &sha1);
my Buf $stored-key = sha1($client-key);

my Str $server-key = hmac-hex( $salted-password, $server-key-s, &sha1);

say "Store iteration count: ", $iteration-count;
say "Store Salt: ", $salt;
say "Salted password: ", $salted-password;
say "Client key: ", $client-key;
say "Stored client key: ", $stored-key;
say "Stored server key: ", $server-key;





# Authentication ( client to server == '==>>' and '<<==' otherwise)
# ==>> initial client message
my Str $client-nonce = (rand * 1e80).base(36);
my Str $initial-client-message = "$username,$client-nonce";
say "==> $initial-client-message";

# <<== initial server message == salt, iteration-count, combined-nonce
my Str $server-nonce = (rand * 1e80).base(36);
my Str $combined-nonce = $client-nonce ~ $server-nonce;
my Str $initial-server-message = "$salt,$iteration-count,$combined-nonce";
say "<== $initial-server-message";

# ==> client proof, combined nonce
(my $c-salt, my $c-iteration-count, my $c-combined-nonce)
    = $initial-server-message.split(',');
my Buf $c-salted-password = pbkdf2( $password, $c-salt, $c-iteration-count.Int, &sha1);
my Buf $c-client-key = hmac( $c-salted-password, $client-key-s, &sha1);
my Buf $c-stored-key = sha1($c-client-key);
is $c-salted-password, $salted-password, 'client: salted passwd ok';
is $c-client-key, $client-key, 'client: client key ok';
is $c-stored-key, $stored-key, 'client: stored key ok';

my Str $auth-message = "$initial-client-message,$initial-server-message,$c-combined-nonce";
my Str $client-signature = hmac-hex( $c-stored-key, $auth-message, &sha1);

my Str $client-proof = XOR( $client-signature, $c-client-key);
my Str $client-challange-response = "$client-proof,$c-combined-nonce";
say "==>> $client-challange-response";


# Server checks response
( my $s-client-proof, my $s-combined-nonce) = $client-challange-response.split(',');
is $s-combined-nonce, $combined-nonce, 'combined nonce ok at server';

my Str $s-auth-message = "$initial-client-message,$initial-server-message,$c-combined-nonce";
my Str $s-client-signature = hmac-hex( $stored-key, $s-auth-message, &sha1);

my Str $s-client-key = XOR( $s-client-proof, $s-client-signature);
is sha1($s-client-key.encode).join, $stored-key, 'client key ok';

my Str $server-signature = hmac-hex( $server-key, $s-auth-message, &sha1);
say "<<== $server-signature";



#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);




