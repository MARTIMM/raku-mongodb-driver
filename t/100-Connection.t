use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB::Connection;
use MongoDB::Collection;

#`{{
  Testing;
    MongoDB::Connection.new()           Create connection to server
    MongoDB::Database.new()             Return database
}}

my MongoDB::Connection $connection;
my BSON::Document $req;
my BSON::Document $doc;

#set-logfile($*OUT);
#set-logfile($*ERR);
#say "Test of stdout";

#-------------------------------------------------------------------------------
subtest {
  $connection .= new( :host<localhost>, :port(65535));
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
     "Failed to connect to localhost at port 65535",
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

#`{{
  my BSON::Document $version = $MongoDB::version;
  ok $version<release1>:exists, "Version release $version<release1>";
  ok $version<release2>:exists, "Version major $version<release2>";
  ok $version<revision>:exists, "Version minor $version<revision>";
  is $version<release-type>,
     $version<release2> %% 2 ?? 'production' !! 'development',
     "Version type $version<release-type>";

  my BSON::Document $buildinfo = $MongoDB::build-info;
  ok $buildinfo<version>:exists, "Version $buildinfo<version> exists";
  ok $buildinfo<loaderFlags>:exists, "Loader flags '$buildinfo<loaderFlags>'";
  ok $buildinfo<sysInfo>:exists, "Sys info '$buildinfo<sysInfo>'";
  ok $buildinfo<versionArray>:exists, "Version array '$buildinfo<versionArray>'";
}}

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
