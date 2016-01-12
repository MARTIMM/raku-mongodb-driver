use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB::Client;
use MongoDB::Collection;

#`{{
  Testing;
    MongoDB::Client.new()               Define connection to server
    MongoDB::Database.new()             Return database
}}

my MongoDB::Client $client;
my BSON::Document $req;
my BSON::Document $doc;

#set-logfile($*OUT);
#set-logfile($*ERR);
#say "Test of stdout";

#-------------------------------------------------------------------------------
subtest {
  $client .= new( :host<localhost>, :port(65535));
  is $client.^name,
     'MongoDB::Client',
     "Client isa {$client.^name}";

  is $client.status.^name,
     'MongoDB::X::MongoDB',
     "1 Status isa {$client.status.^name}";

  ok $client.status ~~ X::MongoDB,
     "2 Status isa {$client.status.^name}";

  ok $client.status ~~ Exception, "3 Status is also an Exception";
  ok ? $client.status, "Status is defined";
  is $client.status.severity,
     MongoDB::Severity::Error,
     "Status is {$client.status.^name}"
     ;

  is $client.status.error-text,
     "Failed to connect to localhost at port 65535",
     '1 ' ~ $client.status.error-text;

  try {
    die $client.status;
    CATCH {
      default {
        ok .message ~~ m:s/'connect' 'to' 'localhost' 'at' 'port' \d+/,
           '2 ' ~ .error-text
      }
    }
  }

}, "Connect failure testing";

#-------------------------------------------------------------------------------
subtest {

  $client = get-connection();
  is $client.status.^name, 'Exception', '1 Status isa Exception';
  ok $client.status ~~ Exception, '2 Status isa Exception';
  ok $client.status !~~ X::MongoDB,
     '3 Status is not a !X::MongoDBn';
  ok ! ? $client.status, "Status is not defined";

  # Create databases with a collection and data to make sure the databases are
  # there
  #
  my MongoDB::Database $database .= new(:name<test>);
  isa-ok( $database, 'MongoDB::Database');

  # Drop database db2
  #
  $req .= new: (dropDatabase => 1);
  $doc = $database.run-command($req);
  is $doc<ok>, 1, 'Drop request ok';

}, "Create database, collection. Collect database info, drop data";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
