#!/usr/bin/env rakudo

use NativeCall;

use OpenSSL;
use OpenSSL::SSL;

use MongoDB::Header;
use BSON::Document;

#`{{
#-------------------------------------------------------------------------------
sub BIO_new( OpenSSL::Bio::BIO_METHOD --> OpaquePointer )
    is native(&gen-lib)
    {*}
sub BIO_s_mem() returns OpenSSL::Bio::BIO_METHOD is native(&gen-lib) {*}
sub SSL_do_handshake(OpenSSL::SSL::SSL) returns int32 is native(&ssl-lib) {*}
sub SSL_CTX_set_default_verify_paths(OpenSSL::Ctx::SSL_CTX) is native(&ssl-lib) {*}
sub SSL_CTX_load_verify_locations(OpenSSL::Ctx::SSL_CTX, Str, Str) returns int32
    is native(&ssl-lib) {*}
sub SSL_get_verify_result(OpenSSL::SSL::SSL) returns int32 is native(&ssl-lib) {*}
sub SSL_CTX_set_cipher_list(OpenSSL::Ctx::SSL_CTX, Str) returns int32
    is native(&ssl-lib) {*}
}}

#-------------------------------------------------------------------------------
sub MAIN ( Int $test = 0 ) {

  with $test {
    when 0 {
      note "Unencripted IO";
      do-unencrypt();
    }

    when 1 {
      note "Encripted IO, default certs";
      do-encrypt1();
    }

    when 2 {
      note "Encripted IO, use mongodb and certs";
      do-encrypt2();
    }
  }
}


#-------------------------------------------------------------------------------
sub do-unencrypt ( ) {
  my Str $host = 'localhost';
  my Int $port = 65010;

  my BSON::Document $monitor-command .= new: (isMaster => 1);
  my MongoDB::Header $header .= new;
  ( my Buf $encoded-query, my Int $request-id) = $header.encode-query(
    'admin.$cmd', $monitor-command, :number-to-return(1)
  );

  my IO::Socket::INET $s = IO::Socket::INET.new( :$host, :$port);

  $s.write($encoded-query);
  my Buf $size-bytes = $s.read(4);
  my Int $response-size = $size-bytes.read-int32( 0, LittleEndian) - 4;
  my Buf $server-reply = $size-bytes ~ $s.read($response-size);

  $s.close;

  my BSON::Document $result = $header.decode-reply($server-reply);
  note "$?LINE $result<number-returned>";
  note "$?LINE $result<documents>[0].gist()";
}


#-------------------------------------------------------------------------------
# Next part works !!!
sub do-encrypt1 ( ) {

  my Str $host = 'google.com';
  my Str $url = '/';
  my Int $port = 443;

  my $s = IO::Socket::INET.new( :$host, :$port);
  my OpenSSL $ssl .= new(:client);
  $ssl.set-socket($s);
  $ssl.set-connect-state;
  $ssl.connect();

  $ssl.write(
    "GET $url HTTP/1.1\r\nHost:www.$host\r\nConnection:close\r\n\r\n"
  );

  my $result = '';
  loop {
    my $tmp = $ssl.read(1024);
    if $tmp.chars {
        $result ~= $tmp;
    } else {
        last;
    }
  }

  $ssl.close;
  $s.close;

  note "$?LINE $result.substr(0,100) …";
}


#-------------------------------------------------------------------------------
use NativeCall;
use OpenSSL::NativeLib;
use OpenSSL::Ctx;
use OpenSSL::Stack;
#use OpenSSL::Bio;

sub SSL_do_handshake ( OpenSSL::SSL::SSL --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_use_PrivateKey_file( OpenSSL::SSL::SSL, Str, int32 --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_load_client_CA_file ( Str --> OpenSSL::Stack )
  is native(&ssl-lib)
  {*}

sub SSL_set_client_CA_list ( OpenSSL::SSL::SSL, OpenSSL::Stack )
  is native(&ssl-lib)
  {*}

sub SSL_check_private_key( OpenSSL::SSL::SSL --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_set1_host( OpenSSL::SSL::SSL, Str )
  is native(&ssl-lib)
  {*}


sub SSL_CTX_enable_ct( OpenSSL::Ctx::SSL_CTX, int32 )
  is native(&ssl-lib)
  {*}

sub SSL_CTX_load_verify_locations ( OpenSSL::Ctx::SSL_CTX, Str, Str --> int32 ) 
  is native(&ssl-lib)
  {*}

sub SSL_CTX_set_default_verify_paths ( OpenSSL::Ctx::SSL_CTX )
  is native(&ssl-lib)
  {*}

sub SSL_CTX_load_verify_dir( OpenSSL::Ctx::SSL_CTX, Str --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_CTX_use_certificate_file ( OpenSSL::Ctx::SSL_CTX, Str, int32 --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_CTX_check_private_key( OpenSSL::Ctx::SSL_CTX --> int32 )
  is native(&ssl-lib)
  {*}

sub SSL_CTX_use_PrivateKey_file ( OpenSSL::Ctx::SSL_CTX, Str, int32 --> int32 )
  is native(&ssl-lib)
  {*}

enum Validation <
  SSL_CT_VALIDATION_PERMISSIVE SSL_CT_VALIDATION_STRICT
>;


sub do-encrypt2 ( ) {
  my Str $host = 'localhost';
  my Int $port = 65014;

  my BSON::Document $monitor-command .= new: (isMaster => 1);
  my MongoDB::Header $header .= new;
  ( my Buf $encoded-query, my Int $request-id) = $header.encode-query(
    'admin.$cmd', $monitor-command, :number-to-return(1)
  );

  my Str $cdir = '/home/marcel/Languages/Raku/Projects/raku-mongodb-driver/xt/TestServers/certificates/certs';
  my Str $ca-file = "$cdir/test-client.pem";
  my Str $privatekey-file = "$cdir/test-ca.pem";
#  my Str $privatekey-file = "$cdir/mongodb-test-client.key";
#note "$?LINE\n$*CWD\n$ca-file\n$privatekey-file";



  my $s = IO::Socket::INET.new( :$host, :$port);
  my OpenSSL $ssl .= new(:client);

#SSL_CTX_load_verify_dir( $ssl.ctx, "$cdir/cert");
SSL_set1_host( $ssl.ssl, $host);
SSL_CTX_enable_ct( $ssl.ctx, SSL_CT_VALIDATION_PERMISSIVE);

#  $ssl.use-client-ca-file( $ca-file, :debug);
#SSL_set_client_CA_list( $ssl.ssl, SSL_load_client_CA_file($ca-file));
SSL_CTX_use_certificate_file( $ssl.ctx, $ca-file, 1);
shell "openssl x509 -noout -modulus -in '$ca-file' | openssl md5";

#  $ssl.use-privatekey-file($privatekey-file);
#SSL_CTX_use_PrivateKey_file( $ssl.ctx, $privatekey-file, 1);
#shell "openssl rsa -noout -modulus -in '$privatekey-file' | openssl md5";

#  $ssl.check-private-key;
note "$?LINE: ", SSL_check_private_key($ssl.ssl);
note "$?LINE: ", SSL_CTX_check_private_key($ssl.ctx);

#note 'key/cert: ', ?SSL_CTX_check_private_key($ssl.ctx) ?? 'ok' !! 'not ok';

#  SSL_CTX_set_default_verify_paths($ssl.ctx);
#  SSL_CTX_load_verify_locations( $ssl.ctx, $ca-file, Str);
#  SSL_do_handshake($ssl.ssl);
#exit;

#  $ssl.set-server-name('localhost');
# From https://stackoverflow.com/questions/63320974/difference-between-ssl-set-connect-state-and-ssl-connect
# SSL_connect invokes SSL_do_handshake, which performs the actual SSL handshake after invoking SSL_set_connect_state.
  $ssl.set-socket($s);
  $ssl.set-connect-state;   # Set client mode and set proper handshake routines
  $ssl.connect();           # Make a connection
#exit;

  $ssl.write($encoded-query);
  my Buf $size-bytes = $ssl.read( 4, :bin);
  my Int $response-size = $size-bytes.read-int32( 0, LittleEndian) - 4;
  my Buf $server-reply = $size-bytes ~ $ssl.read( $response-size, :bin);


  $ssl.close;
  $s.close;


  my BSON::Document $result = $header.decode-reply($server-reply);
  note "$?LINE $result<number-returned>";
  note "$?LINE $result<documents>[0].gist()";
}















=finish
my OpenSSL::Bio $bio .= new('google.com:80');


## SSLv2 | SSLv3 | TLSv1 | TLSv1.1 | TLSv1.2 | default
##subset ProtocolVersion of Numeric where * == 2| 3| 1| 1.1| 1.2| -1;












sub build-client-ctx($version) {
  my $method = do given $version {
    when 2 { OpenSSL::Method::SSLv2_client_method() }
    when 3 { OpenSSL::Method::SSLv3_client_method() }
    when 1 { OpenSSL::Method::TLSv1_client_method() }
    when 1.1 { OpenSSL::Method::TLSv1_1_client_method() }
    when 1.2 { OpenSSL::Method::TLSv1_2_client_method() }
    default {
      try { OpenSSL::Method::TLSv1_2_client_method() } ||
        try { OpenSSL::Method::TLSv1_client_method() }
    }
  }
  OpenSSL::Ctx::SSL_CTX_new($method)
}
