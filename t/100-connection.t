#`{{
  Testing;
    MongoDB::Connection.new()           Create connection to server
    connection.database                 Return database
    connection.list_databases()         Get the statistics of the databases
    connection.database_names()         Get the database names
}}

#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;

use MongoDB;

my $connection = MongoDB::Connection.new();
isa_ok( $connection, 'MongoDB::Connection');

#$connection = MongoDB::Connection.new( host => '192.168.0.10', port => 27017);

$connection = MongoDB::Connection.new( host => 'localhost', port => 27017);
isa_ok( $connection, 'MongoDB::Connection');

# TODO timeout and error checking
#$connection = MongoDB::Connection.new( host => 'example.com', port => 27017);
#isa_ok( $connection, 'MongoDB::Connection');

# Create databases with a collection and data to make sure the databases are there
#
my MongoDB::Database $database = $connection.database('test');
isa_ok( $database, 'MongoDB::Database');

my MongoDB::Collection $collection = $database.collection( 'perl6_driver1' );
$collection.insert( $%( 'name' => 'Jan Klaassen'));

#-------------------------------------------------------------------------------
# Get the statistics of the databases
#
my @db-docs = $connection.list_databases;

# Get the database name from the statistics and save the index into the array
# with that name. Use the zip operator to pair the array entries %doc with
# their index number $idx.
#
my %db-names;
for (@db-docs) Z ^+@db-docs -> %doc, $idx {
  %db-names{%doc<name>} = $idx;
}

ok %db-names<test>:exists, 'database test found';

ok !@db-docs[%db-names<test>]<empty>, 'Database test is not empty';

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
done();
exit(0);
