use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB::Connection;

#`{{
  Testing;
    MongoDB::Connection.new()           Create connection to server
    connection.database                 Return database
    connection.list-databases()         Get the statistics of the databases
    connection.database-names()         Get the database names
    connection.version()                Version name
    connection.buildinfo()              Server info
}}

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

  my BSON::Document $buildinfo = $connection.build-info;
say "V: $buildinfo<version>";
say "B: ";
show-document($buildinfo);
  ok $buildinfo<version>:exists, "Version $buildinfo<version> exists";
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

  # Drop database db2
  #
  $database.drop;
}, "Create database, collection. Collect database info, drop data";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
