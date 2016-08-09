use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Database;
use MongoDB::Users;
use MongoDB::Authenticate;
use BSON::Document;

#plan 1;
#skip-rest "Some modules needed for authentication are not yet supported in perl 6";
#exit(0);

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#---------------------------------------------------------------------------------
subtest {

  ok $ts.server-control.stop-mongod('s1'), "Server 1 stopped";
  ok $ts.server-control.start-mongod( 's1', 'authenticate'),
     "Server 1 in auth mode";

}, "Server changed to authentication mode";

#-------------------------------------------------------------------------------
my Int $exit_code;
my Int $server-number = 1;

my MongoDB::Client $client = $ts.get-connection(:server($server-number));
my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;
my MongoDB::Users $users .= new(:$database);
my MongoDB::Authenticate $auth;

#---------------------------------------------------------------------------------
subtest {
  # Must get a new database, users and authentication objects because server
  # is restarted.
  #
  $client = $ts.get-connection(:server($server-number));
  $database = $client.database('test');
  $users .= new(:$database);
  $auth .= new(:$database);

  try {
    $database.run-command: (dropAllUsersFromDatabase => 1,);
    ok $doc<ok>, 'All users dropped';

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/not authorized on test to execute/, .error-text;
      }
    }
  }

  try {
    $doc = $auth.authenticate( :user('mt'), :password('mt++'));

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/\w/, .error-text;
      }
    }
  }

  $doc = $auth.authenticate( :user('Dondersteen'), :password('w@tD8jeDan'));
  ok $doc<ok>, 'User Dondersteen logged in';

  $doc = $database.run-command: (logout => 1,);
  ok $doc<ok>, 'User Dondersteen logged out';

}, "Authenticate tests";

#---------------------------------------------------------------------------------
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
