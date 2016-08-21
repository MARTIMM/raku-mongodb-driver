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
use lib 't';
use Test;

use Digest::MD5;
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

#---------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my BSON::Document $user-credentials;

sub restart-to-authenticate( ) {

  set-exception-process-level(MongoDB::Severity::Debug);

  my MongoDB::Client $client = $ts.get-connection(:server(1));
  my MongoDB::Database $db-admin = $client.database('admin');
  my MongoDB::Collection $u = $db-admin.collection('system.users');
  my MongoDB::Cursor $uc = $u.find( :criteria( user => 'Dondersteen',));
  $user-credentials = $uc.fetch;
say $user-credentials.perl;

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod( 's1', 'authenticate'),
     "Server 1 in auth mode";
};

#---------------------------------------------------------------------------------
sub restart-to-normal( ) {

  set-exception-process-level(MongoDB::Severity::Warn);

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod('s1'), "Server 1 in normal mode";
}

#-------------------------------------------------------------------------------
sub PBKDF2 (
  Buf $pw, Buf $salt, Int $i,
  Int :$l = 1, Callable :$H = &sha1

  --> Buf
) {

  my Buf $T .= new;
  for 1 .. $l -> $lc {
    my Buf $Ti = F( $pw, $salt, $i, $lc, $H);
    $T ~= $Ti;
  }

  $T;
}

sub F ( Buf $pw, Buf $salt, Int $i, Int $lc, Callable $H = &sha1 --> Buf ) {

  my Buf @U = [];

  @U[0] = hmac( $pw, $salt ~ encode-int32-BE($lc), &$H);
  my $F = @U[0];
  for 1 ..^ $i -> $ci {
    @U[$ci] = hmac( $pw, @U[$ci - 1], &$H);
    for ^($F.elems) -> $ei {
      $F[$ei] = $F[$ei] +^ @U[$ci][$ei];
    }
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

#-------------------------------------------------------------------------------
sub get-server-data ( Str:D $server-first-message --> List ) {

  ( my $pl-nonce, my $pl-salt, my $pl-iter) = $server-first-message.split(',');
  $pl-nonce ~~ s/^ 'r=' //;
  $pl-salt ~~ s/^ 's=' //;
  $pl-iter ~~ s/^ 'i=' //;

  return ( $pl-nonce, $pl-salt, $pl-iter.Int);
}

#-------------------------------------------------------------------------------
set-logfile($*OUT);
info-message("Test $?FILE start");
#---------------------------------------------------------------------------------
#`{{
subtest {

  diag 'Tests to trust base64, md5 etc, checked against values from other tools';

  diag 'Check md5';
  my Digest::MD5 $md5 .= new;
  is $md5.md5_hex("Hello World"),
     'b10a8db164e0754105b7a99be72e3fe5',
     'Hello World';
  is $md5.md5_hex("Hello World\n"),
     'e59ff97941044f85df5297e1c302d260',
     'Hello World\n';

  diag 'Check sha1';
  is sha1("Hello World".encode).>>.fmt('%02x').join,
     '0a4d55a8d778e5022fab701977c5d840bbc486d0',
     'Hello World';
  is sha1("Hello World\n".encode).>>.fmt('%02x').join,
     '648a6a6ffffdaa0badb23b8baf90b6168dd16b3a',
     'Hello World\n';

  diag 'Check base64';
  my Str $salt = decode-base64( 'rQ9ZY3MntBeuP3E1TDVC4w==', :bin).>>.fmt('%02x').join;
  is $salt, 'ad0f59637327b417ae3f71354c3542e3', 'Decoded base64 salt';

  diag 'Check Hi (pbkdf2)';
  my Buf $spw = PBKDF2(
    Buf.new('pencil'.encode),
    decode-base64( 'QSXCR+Q6sek8bf92', :bin),
    1,
  );
  is $spw.>>.fmt('%02x').join, 'f305212412b600a373561fc27b941c350ba9d399', '1 iteration';

  $spw = PBKDF2(
    Buf.new('pencil'.encode),
    decode-base64( 'QSXCR+Q6sek8bf92', :bin),
    4096,
  );
  is $spw.>>.fmt('%02x').join, '1d96ee3a529b5a5f9e47c01f229a2cb8a6e15f7d', '4096 iterations';

  # Example from rfc
  # C: n,,n=user,r=fyko+d2lbbFgONRv9qkxdawL
  # S: r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096
  # C: c=biws,r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,
  #    p=v0X8v3Bz2T0CJGbJQyF0X+HI4Ts=
  # S: v=rmF9pqV8S7suAoZWja4dJRkFsKQ=
  #
  my Str $username = 'user';
  my Str $password = 'pencil';
  diag "Run with $username and $password";
  my Str $gs2-header = 'n,';
  my Str $client-nonce = 'r=fyko+d2lbbFgONRv9qkxdawL';
  my Str $client-first-message-bare = "n=$username,$client-nonce";
  my Str $client-first-message = "$gs2-header,$client-first-message-bare";

  my Str $server-first-message = 'r=fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j,s=QSXCR+Q6sek8bf92,i=4096';
  ( my Str $pl-nonce, my Str $pl-salt, my Int $pl-iter) =
    get-server-data($server-first-message);
  is $pl-iter, 4096, 'Number of iterations';
  is $pl-nonce, 'fyko+d2lbbFgONRv9qkxdawL3rfcNHYJY1ZVvWVs7j', 'server nonce';
  is $pl-salt, 'QSXCR+Q6sek8bf92', 'server salt';

  my Buf $salted-password = PBKDF2(
    Buf.new($password.encode),
    decode-base64( $pl-salt, :bin),
    $pl-iter,
  );

  is $salted-password.>>.fmt('%02x').join,
#     '427989587db259e12c21dd042f16542049a38cfb',
     '1d96ee3a529b5a5f9e47c01f229a2cb8a6e15f7d',
     "Salted $password with $pl-salt and $pl-iter iterations";

#say "Salted password: ", $salted-password.>>.fmt('%02x');

  my Buf $client-key = hmac( $salted-password, 'Client Key', &sha1);
  my Buf $stored-key = sha1($client-key);

  my Str $channel-binding = "c=biws";
  my Str $client-final-without-proof = "$channel-binding,r=$pl-nonce";

  my $auth-message = 
    "$client-first-message-bare,$server-first-message,$client-final-without-proof";

  my Buf $client-signature = hmac( $stored-key, $auth-message, &sha1);
  is $client-signature.elems, $client-key.elems, 'signature and client-key have same length';

  my Buf $client-proof .= new;
  for ^($client-key.elems) -> $i {
    $client-proof[$i] = $client-key[$i] +^ $client-signature[$i];
  }

#  say "Client proof: ", $client-proof.>>.fmt('%02x').join;
#  say "Client proof b64: ", encode-base64( $client-proof, :str);
  is encode-base64( $client-proof, :str),
    'v0X8v3Bz2T0CJGbJQyF0X+HI4Ts=',
    'Checking client proof';

#  say "Salted password: ", $salted-password>>.fmt('%0x').join;

  my $server-key = hmac( $salted-password, 'Server Key', &sha1);
  my $server-signature = hmac( $server-key, $auth-message, &sha1);
  is encode-base64( $server-signature, :str),
     'rmF9pqV8S7suAoZWja4dJRkFsKQ=',
     'Check server signature';

}, "low level tests from rfc";
}}
#---------------------------------------------------------------------------------
#`{{
subtest {

  # Example from mongo
  # C: n,,n=user,r=fyko+d2lbbFgONRv9qkxdawL
  # S: r=fyko+d2lbbFgONRv9qkxdawLHo+Vgk7qvUOKUwuWLIWg4l/9SraGMHEE,s=rQ9ZY3MntBeuP3E1TDVC4w==,i=10000
  # C: c=biws,r=fyko+d2lbbFgONRv9qkxdawLHo+Vgk7qvUOKUwuWLIWg4l/9SraGMHEE,p=MC2T8BvbmWRckDw8oWl5IVghwCY=
  # S: v=UMWeI25JD1yNYZRMpZ4VHvhZ9e0=
  #
  my Str $username = 'user';
  my Str $password = 'pencil';

  my Str $gs2-header = 'n,';
  my Str $client-nonce = 'r=fyko+d2lbbFgONRv9qkxdawL';
  my Str $client-first-message-bare = "n=$username,$client-nonce";
  my Str $client-first-message = "$gs2-header,$client-first-message-bare";


  my Str $server-first-message = 'r=fyko+d2lbbFgONRv9qkxdawLHo+Vgk7qvUOKUwuWLIWg4l/9SraGMHEE,s=rQ9ZY3MntBeuP3E1TDVC4w==,i=10000';
  ( my $pl-nonce, my $pl-salt, my $pl-iter) =
    get-server-data($server-first-message);

  is $pl-salt, 'rQ9ZY3MntBeuP3E1TDVC4w==', 'Check salt';
  is $pl-iter, 10000, '10000 iterations';

  my Buf $salted-password = PBKDF2(
    Digest::MD5.new.md5_buf($username ~ ':mongo:' ~ $password),
    decode-base64( $pl-salt, :bin),
#    Buf.new($pl-salt.encode),
    $pl-iter
  );

  is $salted-password.>>.fmt('%02x').join,
     '4b5a9e5e957fbdbe2e447cf0ecc75dde06f755c7',
     "Check salted password with $pl-salt and $pl-iter iterations";

  my Buf $client-key = hmac( $salted-password, 'Client Key', &sha1);
  my Buf $stored-key = sha1($client-key);

  my Str $channel-binding = "c=biws";
  my Str $client-final-without-proof = "$channel-binding,r=$pl-nonce";

  my $auth-message = 
    "$client-first-message-bare,$server-first-message,$client-final-without-proof";
  my Buf $client-signature = hmac( $stored-key, $auth-message, &sha1);

  my Buf $client-proof .= new;
  for ^($client-key.elems) -> $i {
    $client-proof[$i] = $client-key[$i] +^ $client-signature[$i];
  }

say "Client proof: ", $client-proof.>>.fmt('%02x').join;
say "Decoded b64 proof: ", decode-base64( 'MC2T8BvbmWRckDw8oWl5IVghwCY=', :bin).>>.fmt('%02x').join;

  is encode-base64( $client-proof, :str),
     'MC2T8BvbmWRckDw8oWl5IVghwCY=',
     'Check client proof';

  my $server-key = hmac( $salted-password, 'Server Key', &sha1);
  my $server-signature = hmac( $server-key, $auth-message, &sha1);

  is encode-base64( $server-signature, :str),
     'UMWeI25JD1yNYZRMpZ4VHvhZ9e0=',
     'Server signature check';

say "Skey: ", encode-base64( $server-key, :str);
say "Ssig: ", encode-base64( $server-signature, :str);

}, "low level tests from mongodb";
}}

#-------------------------------------------------------------------------------
#`{{}}
restart-to-normal;
restart-to-authenticate;

subtest {

  my MongoDB::Client $client = $ts.get-connection(:server(1));

  # Setup in 509...t
  # 'site-admin', 'B3n@Hurry', role => 'userAdminAnyDatabase', db => 'admin'
  # 'Dondersteen', 'w@tD8jeDan', role => 'readWrite', db => 'test'

  my MongoDB::Database $database = $client.database('test');
  my BSON::Document $doc;

  my Str $username = 'Dondersteen';
  my Str $password = 'w@tD8jeDan';

  # gs2-header = gs2-cbind-flag "," [ authzid ] ","
  # gs2-cbind-flag = 'n'
  # authzid = ''
  # ==>> header = 'n,'
  my Str $gs2-header = 'n,';

#  $doc = $db-admin.run-command(BSON::Document.new: (getnonce => 1));
#  my Str $c-nonce = $doc<nonce>;
  my Str $c-nonce = encode-base64( Buf.new( (for ^24 { (rand * 256).Int })), :str);
  my Str $client-first-message-bare = "n=$username,r=$c-nonce";
  my Str $client-first-message = "$gs2-header,$client-first-message-bare";
#say "CFM: $client-first-message";

  $doc = $database.run-command( BSON::Document.new: (
      saslStart => 1,
      mechanism => 'SCRAM-SHA-1',
      payload => encode-base64( $client-first-message, :str)
    )
  );
#say "N1: ", $doc.perl;

  # Error doc keys: 
  #  ok => 0e0,
  #  code => 18,
  #  errmsg => "Authentication failed.",
  if !$doc<ok> {
    skip 1;
    flunk "$doc<code>, $doc<errmsg>";
    done-testing;

    restart-to-normal;
    exit(1);
  }

  # Ok keys:
  #  conversationId => 1,
  #  done => Bool::False,
  #  payload => "...",
  #  ok => 1e0,
  my Int $conversation-id = $doc<conversationId>;
  my Str $server-first-message = Buf.new(decode-base64($doc<payload>)).decode;
#say "Payload: $server-first-message";

  ( my Str $pl-nonce, my Str $pl-salt, my Int $pl-iter) =
    get-server-data($server-first-message);
say "Creds: ", $user-credentials<credentials><SCRAM-SHA-1>;
  is $pl-salt,
     $user-credentials<credentials><SCRAM-SHA-1><salt>,
     'Check salt from credentials';
  is $pl-iter,
     $user-credentials<credentials><SCRAM-SHA-1><iterationCount>,
     'Check iterations from credentials';

  my Buf $salted-password = PBKDF2(
#    Buf.new(Digest::MD5.new.md5_hex($password.encode).encode),
#    Buf.new(Digest::MD5.new.md5_hex(($username ~ ':mongo:' ~ $password).encode).encode),
#    Buf.new(Digest::MD5.new.md5_buf(($username ~ ':mongo:' ~ $password).NFC)),
#    Buf.new("$username\:mongo\:$password".encode),
#    Digest::MD5.new.md5_buf($username ~ ':mongo:' ~ $password),
    Digest::MD5.new.md5_buf(Buf.new(($username ~ ':mongo:' ~ $password).encode)),
#    Digest::MD5.new.md5_buf($password),
    decode-base64( $pl-salt, :bin),
    $pl-iter
  );

#  is $salted-password.>>.fmt('%02x').join,
#     'f2d5ddb1dfcdec02fd5e2cba731a926eabde5083',
#     "Salted password of $username\:mongo\:$password";

  my Buf $client-key = hmac( $salted-password, 'Client Key', &sha1);
  say 'Ck0: ', $client-key;
#  $client-key = hmac( $salted-password, 'ClientKey', &sha1);
#  say 'Ck1: ', $client-key;

#  is encode-base64( $client-key, :str),
#     '1sj/A5t1fFnxW+EfLP5SwF2IymA=',
#     'Client key b64';

  my Buf $stored-key = sha1($client-key);
  is encode-base64( $stored-key, :str),
     $user-credentials<credentials><SCRAM-SHA-1><storedKey>,
     'Check stored key from credentials';

say "CK: ", $client-key;
say "SK: ", $stored-key;

  my Str $channel-binding = "c=biws";
  my Str $client-final-without-proof = "$channel-binding,r=$pl-nonce";

  my $auth-message = 
    "$client-first-message-bare,$server-first-message,$client-final-without-proof";
say "AM: $auth-message";

  my Buf $client-signature = hmac( $stored-key, $auth-message, &sha1);
  #my Str $client-proof = "p=" ~ XOR( $client-key, $client-signature);
  my Buf $client-proof .= new;
  for ^($client-key.elems) -> $Hi-i {
    $client-proof[$Hi-i] = $client-key[$Hi-i] +^ $client-signature[$Hi-i];
  }

  my Str $client-proof-b64 = encode-base64( $client-proof, :str);
  my Str $client-final = "$client-final-without-proof,p=$client-proof-b64";
say "CF: $client-final";

  my $server-key = hmac( $salted-password, 'Server Key', &sha1);
  my $server-signature = hmac( $server-key, $auth-message, &sha1);
  is encode-base64( $server-key, :str),
     $user-credentials<credentials><SCRAM-SHA-1><serverKey>,
     'Check server key from credentials';

  $doc = $database.run-command( BSON::Document.new: (
      saslContinue => 1,
      conversationId => $conversation-id,
      payload => encode-base64($client-final, :str)
    )
  );

  # Sample error
  #  ok => 0e0,
  #  code => 17,
  #  errmsg => "No SASL session state found",
  if !$doc<ok> {
    skip 1;
    flunk "$doc<code>, $doc<errmsg>";
    done-testing;

    restart-to-normal;
    exit(1);
  }

}, "Server authentication";

#---------------------------------------------------------------------------------
set-exception-process-level(MongoDB::Severity::Warn);
subtest {

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod('s1'), "Server 1 in normal mode";

}, "Server changed to normal mode";

#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing();
exit(0);

=finish

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

#---------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;

subtest {

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod('s1'),
     "Server 1 in auth mode";

}, "Server changed to authentication mode";



#-------------------------------------------------------------------------------
# Cleanup and close
#
info-message("Test $?FILE stop");
done-testing;
exit(0);




