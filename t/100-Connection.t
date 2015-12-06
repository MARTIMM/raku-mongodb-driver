#`{{
  Testing;
    MongoDB::Connection.new()           Create connection to server
    connection.database                 Return database
    connection.list-databases()         Get the statistics of the databases
    connection.database-names()         Get the database names
    connection.version()                Version name
    connection.buildinfo()              Server info
}}

use lib 't';
use Test-support;

use v6;
use Test;

use MongoDB;
use MongoDB::Connection;

my MongoDB::Connection $connection;
#set-logfile($*OUT);
#set-logfile($*ERR);
#say "Test of stdout";

#-------------------------------------------------------------------------------
subtest {
  $connection .= new( :host<localhost>, :port(763245));
  is $connection.^name,
     'MongoDB::Connection',
     "Connection isa {$connection.^name}";

  is $connection.status.^name,
     'MongoDB::X::MongoDB',
     "1 Status isa {$connection.status.^name}";

  ok $connection.status ~~ X::MongoDB,
     "2 Status isa {$connection.status.^name}";

  ok $connection.status ~~ Exception, "3 Status is also an Exception";
  ok ? $connection.status, "Status is defined";
  is $connection.status.severity,
     MongoDB::Severity::Error,
     "Status is {$connection.status.^name}"
     ;

  is $connection.status.error-text,
     "Failed to connect to localhost at port 763245",
     '1 ' ~ $connection.status.error-text;

  try {
    die $connection.status;
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
  $connection = get-connection();
  is $connection.status.^name, 'Exception', '1 Status isa Exception';
  ok $connection.status ~~ Exception, '2 Status isa Exception';
  ok $connection.status !~~ X::MongoDB,
     '3 Status is not a !X::MongoDBn';
  ok ! ? $connection.status, "Status is not defined";

  my Hash $version = $connection.version;
#say "V: ", $version.perl;
  ok $version<release1>:exists, "Version release $version<release1>";
  ok $version<release2>:exists, "Version major $version<release2>";
  ok $version<revision>:exists, "Version minor $version<revision>";
  is $version<release-type>,
     $version<release2> %% 2 ?? 'production' !! 'development',
     "Version type $version<release-type>";

  my Hash $buildinfo = $connection.build-info;
  ok $buildinfo<version>:exists, "Version $buildinfo<version>";
  ok $buildinfo<loaderFlags>:exists, "Loader flags '$buildinfo<loaderFlags>'";
  ok $buildinfo<sysInfo>:exists, "Sys info '$buildinfo<sysInfo>'";
  ok $buildinfo<versionArray>:exists, "Version array '$buildinfo<versionArray>'";
}, "Test buildinfo and version";

#-------------------------------------------------------------------------------
subtest {

  #-------------------------------------------------------------------------------
  # Create databases with a collection and data to make sure the databases are
  # there
  #
  my MongoDB::Database $database = $connection.database('test');
  isa-ok( $database, 'MongoDB::Database');

  my MongoDB::Collection $collection = $database.collection('perl6_driver1');
  $collection.insert( $%( 'name' => 'Jan Klaassen'));

  #-------------------------------------------------------------------------------
  # Get the statistics of the databases
  #
  my Array $db-docs = $connection.list-databases;

  # Get the database name from the statistics and save the index into the array
  # with that name. Use the zip operator to pair the array entries %doc with
  # their index number $idx.
  #
  my %db-names;
  my $idx = 0;
  for $db-docs[*] -> $doc {
    %db-names{$doc<name>} = $idx++;
  }

  ok %db-names<test>:exists, 'database test found';

  ok !$db-docs[%db-names<test>]<empty>, 'Database test is not empty';

  #-------------------------------------------------------------------------------
  # Get all database names
  #
  my @dbns = $connection.database-names();

  ok any(@dbns) ~~ 'test', 'test is found in database list';

  #-------------------------------------------------------------------------------
  # Drop database db2
  #
  $database.drop;

  @dbns = $connection.database-names();
  ok !(any(@dbns) ~~ 'test'), 'test not found in database list';
}, "Create database, collection. Collect database info, drop data";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
