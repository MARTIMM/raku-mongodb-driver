#!/usr/bin/env perl6

# RFC
#                   https://tools.ietf.org/html/rfc5802
#   PKCS #5         https://tools.ietf.org/html/rfc2898
# MongoDB       https://www.mongodb.com/blog/post/improved-password-based-authentication-mongodb-30-scram-explained-part-1?jmp=docs&_ga=1.111833220.1411139568.1420476116
#               https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst
# Wiki          https://en.wikipedia.org/wiki/Salted_Challenge_Response_Authentication_Mechanism
#               https://en.wikipedia.org/wiki/PBKDF2
# perl5         Unicode::*
#               Authen::*
use v6.c;
use Test;

use Digest::MD5;
use Digest::HMAC;
use OpenSSL::Digest;
use Base64;

#---------------------------------------------------------------------------------
sub PBKDF2 ( Buf $pw, Buf $salt, Int $i, Int $l --> Buf ) {

  my Buf $T .= new;
  for 1 .. $l -> $lc {
say "lc: $lc";
    my Buf $Ti = F( $pw, $salt, $i, $lc);
    $T ~= $Ti;
  }

  $T;
}

sub F ( Buf $pw, Buf $salt, Int $i, Int $lc --> Buf ) {

  my Buf @U = [];

  @U[0] = hmac( $pw, $salt ~ encode-int32-BE($lc), &sha1);
  my $F = @U[0];
#say "U[0]: ", @U[0];
  for 1 ..^ $i -> $ci {
    @U[$ci] = hmac( $pw, @U[$ci - 1], &sha1);
#say "U[$ci]: ", @U[$ci];
    for ^($F.elems) -> $ei {
      $F[$ei] = $F[$ei] +^ @U[$ci][$ei];
    }
#say "F[$ci]: ", $F>>.fmt('%0x');
  }

  Buf.new($F);
}

sub encode-int32-BE ( Int:D $i --> Buf ) {
  my int $ni = $i;
  Buf.new((
    $ni +& 0xFF, ($ni +> 0x08) +& 0xFF,
    ($ni +> 0x10) +& 0xFF, ($ni +> 0x18) +& 0xFF
  ).reverse);
}

#---------------------------------------------------------------------------------
my Str $username = 'user';
my Str $password = 'pencil';
my Buf $salt = decode-base64( 'QSXCR+Q6sek8bf92', :bin);
my Int $iteration-count = 4096;
#say "Salt: ", $salt.>>.fmt('%0x').join;

#---------------------------------------------------------------------------------
subtest {

  diag 'Test pbkdf2';

  # Sha1 dklen = 20, hlen = hash length of which dklen is max (2^32 - 1) * hLen
  my Int $dklen = 20;
  my Int $hlen = 20;    # Hash length

  my Int $l = ceiling($dklen/$hlen);
  my Int $r = $dklen - ($l - 1) * $hlen;

  is $l, 1, "l = $l";
  is $r, 20, "r = $r";

  my Buf $sp = PBKDF2( Buf.new($password.encode), $salt, $iteration-count, $l);
#  my Buf $sp = PBKDF2( Buf.new($password.encode), $salt, 2, $l);
say "Salted: ", $sp.>>.fmt('%0x').join;

}, "Hi tests";

done-testing;
exit(0);
