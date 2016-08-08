#!/usr/bin/env perl6

# RDC           https://tools.ietf.org/html/rfc5802
# MongoDB       https://www.mongodb.com/blog/post/improved-password-based-authentication-mongodb-30-scram-explained-part-1?jmp=docs&_ga=1.111833220.1411139568.1420476116
# Wiki          https://en.wikipedia.org/wiki/Salted_Challenge_Response_Authentication_Mechanism
#               https://en.wikipedia.org/wiki/PBKDF2

use v6.c;
use Test;

use Digest::HMAC;
use OpenSSL::Digest;

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
# PBKDF2 (Password Based Key Derivation Function). See rfc 5802, 2898. Where
# PRF is HMAC (Pseudo random function)
# dklen == output length of hmac == output length of H()
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
my Str $username = "user\x0154";
my Str $password = "pencil\x0152";
#my Str $client-key-s = 'client key';
my Str $client-key-s = $username;

say "Username: ", $username;
say "Password: ", $password;
say "Client key string: ", $client-key-s;

# Server calculates
my Int $iteration-count = 4;
my Str $server-key-s = 'server key';
say "Server key string: ", $server-key-s;

my Str $salt = (rand * 1e80).base(36);

my Buf $salted-password = pbkdf2( $password, $salt, $iteration-count, &sha1);
my Buf $client-key = hmac( $salted-password, $client-key-s, &sha1);
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



done-testing;








