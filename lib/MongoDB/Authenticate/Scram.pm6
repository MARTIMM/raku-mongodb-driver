use v6;

use MongoDB;

use BSON::Document;
use Base64;
use OpenSSL::Digest;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

#-----------------------------------------------------------------------------
# Class definition to do authentication with
class Authenticate::Scram {

  has ClientType $!client;
  has DatabaseType $!database;
  has Int $!conversation-id;

  #-----------------------------------------------------------------------------
  submethod BUILD ( ClientType:D :$client, Str :$db-name ) {

    $!client = $client;
    $!database = $!client.database(?$db-name ?? $db-name !! 'admin' );
  }

  #-----------------------------------------------------------------------------
  # send client first message to server and return server response
  method client-first ( Str:D $client-first-message --> Str ) {

    my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
        saslStart => 1,
        mechanism => 'SCRAM-SHA-1',
        payload => encode-base64( $client-first-message, :str)
      )
    );

    if $doc<ok> {
      debug-message("SCRAM-SHA1 client first message");
    }

    else {
      error-message("$doc<code>, $doc<errmsg>");
      return '';
    }

    $!conversation-id = $doc<conversationId>;
    Buf.new(decode-base64($doc<payload>)).decode;
  }

  #-----------------------------------------------------------------------------
  method client-final ( Str:D $client-final-message --> Str ) {

   my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
        saslContinue => 1,
        conversationId => $!conversation-id,
        payload => encode-base64( $client-final-message, :str)
      )
    );

    if $doc<ok> {
      debug-message("SCRAM-SHA1 client final message");
    }

    else {
      error-message("$doc<code>, $doc<errmsg>");
      return '';
    }

    Buf.new(decode-base64($doc<payload>)).decode;
  }

  #-----------------------------------------------------------------------------
  method mangle-password ( Str:D :$username, Str:D :$password --> Buf ) {

    my utf8 $mdb-hashed-pw = ($username ~ ':mongo:' ~ $password).encode;
    my Str $md5-mdb-hashed-pw = md5($mdb-hashed-pw).>>.fmt('%02x').join;
    Buf.new($md5-mdb-hashed-pw.encode);
  }

  #-----------------------------------------------------------------------------
  method cleanup ( ) {

    # Some extra chit-chat
    my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
        saslContinue => 1,
        conversationId => $!conversation-id,
        payload => encode-base64( '', :str)
      )
    );

    if $doc<ok> {
      info-message("SCRAM-SHA1 autentication successfull");
    }

    else {
      error-message("$doc<code>, $doc<errmsg>");
    }
  }

  #-----------------------------------------------------------------------------
  method error ( Str:D $message --> Str ) {

    error-message($message);
  }
}
