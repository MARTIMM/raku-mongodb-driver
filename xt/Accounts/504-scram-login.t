use v6.c;
use lib 't';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::HL::Users;
use MongoDB::Database;
use MongoDB::Collection;

use BSON::Document;
use Auth::SCRAM;
use OpenSSL::Digest;
use Base64;

#-------------------------------------------------------------------------------
#my MongoDB::Test-support $ts .= new;
#my BSON::Document $user-credentials;

#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
# Example from https://github.com/mongodb/specifications/blob/master/source/auth/auth.rst
# C: n,,n=user,r=fyko+d2lbbFgONRv9qkxdawL
# S: r=fyko+d2lbbFgONRv9qkxdawLHo+Vgk7qvUOKUwuWLIWg4l/9SraGMHEE,s=rQ9ZY3MntBeuP3E1TDVC4w==,i=10000
# C: c=biws,r=fyko+d2lbbFgONRv9qkxdawLHo+Vgk7qvUOKUwuWLIWg4l/9SraGMHEE,p=MC2T8BvbmWRckDw8oWl5IVghwCY=
# S: v=UMWeI25JD1yNYZRMpZ4VHvhZ9e0=
#
class MyClientDryRun {

  # send client first message to server and return server response
  method message1 ( Str:D $string --> Str ) {

    is $string, 'n,,n=user,r=fyko+d2lbbFgONRv9qkxdawL', 'First client message';

    'r=fyko+d2lbbFgONRv9qkxdawLHo+Vgk7qvUOKUwuWLIWg4l/9SraGMHEE,s=rQ9ZY3MntBeuP3E1TDVC4w==,i=10000';
  }

  method message2 ( Str:D $string --> Str ) {

    is $string, 'c=biws,r=fyko+d2lbbFgONRv9qkxdawLHo+Vgk7qvUOKUwuWLIWg4l/9SraGMHEE,p=MC2T8BvbmWRckDw8oWl5IVghwCY=', 'Final client message';

    'v=UMWeI25JD1yNYZRMpZ4VHvhZ9e0=';
  }

  method mangle-password ( Str:D :$username, Str:D :$password --> Buf ) {

    my utf8 $mdb-hashed-pw = ($username ~ ':mongo:' ~ $password).encode;
    my Str $md5-mdb-hashed-pw = md5($mdb-hashed-pw).>>.fmt('%02x').join;
    Buf.new($md5-mdb-hashed-pw.encode);
  }

  method error ( Str:D $message --> Str ) {

    error-message($message);
  }
}

subtest {

  my Auth::SCRAM $sc .= new(
    :username<user>,
    :password<pencil>,
    :client-side(MyClientDryRun.new),
  );

  $sc.c-nonce-size = 24;
  $sc.c-nonce = 'fyko+d2lbbFgONRv9qkxdawL';

  $sc.start-scram;

}, 'dry run';


#---------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my BSON::Document $user-credentials;

sub restart-to-authenticate( ) {

  my MongoDB::Client $client = $ts.get-connection(:server(1));
  my MongoDB::Database $db-admin = $client.database('admin');
  my MongoDB::Collection $u = $db-admin.collection('system.users');
  my MongoDB::Cursor $uc = $u.find( :criteria( user => 'Dondersteen',));
  $user-credentials = $uc.fetch;

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod( 's1', 'authenticate'),
     "Server 1 in auth mode";

  # Try it again and see that we have no rights
  $client = $ts.get-connection(:server(1));
  $db-admin = $client.database('admin');
  $u = $db-admin.collection('system.users');
  $uc = $u.find( :criteria( user => 'Dondersteen',));

  my BSON::Document $doc = $uc.fetch;
  is $doc<code>, 13, 'error code 13';
  is $doc<$err>, "not authorized for query on admin.system.users", $doc<$err>;
};

#---------------------------------------------------------------------------------
sub restart-to-normal( ) {

#  set-exception-process-level(MongoDB::Severity::Warn);

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod('s1'), "Server 1 in normal mode";
}

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

restart-to-normal;
restart-to-authenticate;

#set-exception-process-level(MongoDB::Severity::Trace);

class MyClientMDB {

  has MongoDB::Client $!client;
  has MongoDB::Database $!database;
  has Int $!conversation-id;
  
  #-----------------------------------------------------------------------------
  submethod BUILD ( ) {

    $!client = $ts.get-connection(:server(1));
    $!database = $!client.database('test');
  }

  #-----------------------------------------------------------------------------
  # send client first message to server and return server response
  method message1 ( Str:D $client-first-message --> Str ) {

    my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
        saslStart => 1,
        mechanism => 'SCRAM-SHA-1',
        payload => encode-base64( $client-first-message, :str)
      )
    );

    if !$doc<ok> {
      skip 1;
      flunk "$doc<code>, $doc<errmsg>";
      done-testing;

      restart-to-normal;
      exit(1);
    }

    ok not $doc<done>, 'Not yet finished';

    $!conversation-id = $doc<conversationId>;
    my Str $server-first-message = Buf.new(decode-base64($doc<payload>)).decode;
    ok $server-first-message ~~ m/^ 'r=' /, 'Server nonce';
    ok $server-first-message ~~ m/ ',s=' /, 'Server salt';
    ok $server-first-message ~~ m/ ',i=' /, 'Server iterations';
    $server-first-message
  }

  #-----------------------------------------------------------------------------
  method message2 ( Str:D $client-final --> Str ) {

   my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
        saslContinue => 1,
        conversationId => $!conversation-id,
        payload => encode-base64( $client-final, :str)
      )
    );

    if !$doc<ok> {
      skip 1, ;
      flunk "$doc<code>, $doc<errmsg>";
      done-testing;

      restart-to-normal;
      exit(1);
    }

    ok not $doc<done>, 'Not yet finished';

    my Str $server-final-message = Buf.new(decode-base64($doc<payload>)).decode;

    $server-final-message;
  }

  #-----------------------------------------------------------------------------
  method mangle-password ( Str:D :$username, Str:D :$password --> Buf ) {

    my utf8 $mdb-hashed-pw = ($username ~ ':mongo:' ~ $password).encode;
    my Str $md5-mdb-hashed-pw = md5($mdb-hashed-pw).>>.fmt('%02x').join;
    Buf.new($md5-mdb-hashed-pw.encode);
  }

  #-----------------------------------------------------------------------------
  method clean-up ( ) {
    
    # Some extra chit-chat
    my BSON::Document $doc = $!database.run-command( BSON::Document.new: (
        saslContinue => 1,
        conversationId => $!conversation-id,
        payload => encode-base64( '', :str)
      )
    );

    if !$doc<ok> {
      skip 1;
      flunk "$doc<code>, $doc<errmsg>";
      done-testing;

      restart-to-normal;
      exit(1);
    }

    ok $doc<done>, 'Login finished';
    is Buf.new(decode-base64($doc<payload>)).decode, '', 'Empty string returned';
  }

  #-----------------------------------------------------------------------------
  method error ( Str:D $message --> Str ) {

    error-message($message);
  }
}

subtest {

  my Auth::SCRAM $sc .= new(
    :username<Dondersteen>,
    :password<w@tD8jeDan>,
    :client-side(MyClientMDB.new),
  );

  $sc.start-scram;

}, 'Mongodb login';

#-------------------------------------------------------------------------------
# Cleanup
#
restart-to-normal;
info-message("Test $?FILE stop");
done-testing();
