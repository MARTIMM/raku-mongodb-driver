use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB::Client;
use MongoDB::Database;
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

  $client .= get-instance( :host<localhost>, :port(65535));
  is $client.^name, 'MongoDB::Client', "Client isa {$client.^name}";
  my $connection = $client.select-server;
  nok $connection.defined, 'No servers found';

}, "Connect failure testing";

#-------------------------------------------------------------------------------
subtest {

  $client = get-connection();
  my $connection = $client.select-server;
  ok $connection.defined, 'Connection available';
  ok $connection.status, 'Server found';

  # Create databases with a collection and data to make sure the databases are
  # there
  #
  my MongoDB::Database $database .= new(:name<test>);
  isa-ok( $database, 'MongoDB::Database');

  # Drop database db2
  #
  $doc = $database.run-command: (dropDatabase => 1);
  is $doc<ok>, 1, 'Drop request ok';

}, "Create database, collection. Collect database info, drop data";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
