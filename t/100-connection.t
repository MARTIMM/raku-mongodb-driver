#`{{
  Testing;
    MongoDB::Connection.new()           Create connection to server
    connection.database                 Return database
    connection.list_databases()         Get the statistics of the databases
    connection.database_names()         Get the database names
    connection.version()                Version name
    connection.buildinfo()              Server info
}}

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

use v6;
use Test;

use MongoDB::Connection;

my $connection = get-connection();
isa-ok( $connection, 'MongoDB::Connection');


my Hash $version = $connection.version;
#say "V: ", $version.perl;
ok $version<release1>:exists, "Version release $version<release1>";
ok $version<release2>:exists, "Version major $version<release2>";
ok $version<revision>:exists, "Version minor $version<revision>";
is $version<release-type>,
   $version<release2> %% 2 ?? 'production' !! 'development',
   "Version type $version<release-type>";

my Hash $buildinfo = $connection.build_info;
ok $buildinfo<version>:exists, "Version $buildinfo<version>";
ok $buildinfo<loaderFlags>:exists, "Loader flags $buildinfo<loaderFlags>";

# Create databases with a collection and data to make sure the databases are there
#
my MongoDB::Database $database = $connection.database('test');
isa-ok( $database, 'MongoDB::Database');

my MongoDB::Collection $collection = $database.collection('perl6_driver1');
$collection.insert( $%( 'name' => 'Jan Klaassen'));

#-------------------------------------------------------------------------------
# Get the statistics of the databases
#
my Array $db-docs = $connection.list_databases;

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
my @dbns = $connection.database_names();

ok any(@dbns) ~~ 'test', 'test is found in list';

#-------------------------------------------------------------------------------
# Drop database db2
#
$database.drop;

@dbns = $connection.database_names();
ok !(any(@dbns) ~~ 'test'), 'test not found in list';

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
