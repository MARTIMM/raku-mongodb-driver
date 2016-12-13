use v6.c;

use MongoDB;

use BSON::Document;
use Auth::SCRAM;
use Base64;
use OpenSSL::Digest;
#use Unicode::PRECIS;
#use Unicode::PRECIS::Identifier::UsernameCasePreserved;
#use Unicode::PRECIS::FreeForm::OpaqueString;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

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
#`{{
    my Unicode::PRECIS::Identifier::UsernameCasePreserved $upi-ucp .= new;
    my TestValue $tv-un = $upi-ucp.enforce($username);
    fatal-message("Username $username not accepted") if $tv-un ~~ Bool;
    info-message("Username '$username' accepted as '$tv-un'");

    my Unicode::PRECIS::FreeForm::OpaqueString $upf-os .= new;
    my TestValue $tv-pw = $upf-os.enforce($password);
    fatal-message("Password not accepted") if $tv-un ~~ Bool;
    info-message("Password accepted");

    my utf8 $mdb-hashed-pw = ($tv-un ~ ':mongo:' ~ $tv-pw).encode;
    my Str $md5-mdb-hashed-pw = md5($mdb-hashed-pw).>>.fmt('%02x').join;
    Buf.new($md5-mdb-hashed-pw.encode);
}}
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

#      Buf.new(decode-base64($doc<payload>)).decode;
  }

  #-----------------------------------------------------------------------------
  method error ( Str:D $message --> Str ) {

    error-message($message);
  }
}
