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
my MongoDB::Database $database = $database = $connection.database('db1');
my MongoDB::Collection $collection = $database.collection( 'perl6_driver1' );
$collection.insert( $%( 'name' => 'Jan Klaassen'));
isa_ok( $database, 'MongoDB::Database');

$database = $database = $connection.database('db2');
$collection = $database.collection( 'perl6_driver2' );
isa_ok( $database, 'MongoDB::Database');
isa_ok( $collection, 'MongoDB::Collection');
$collection.insert( $%( 'name' => 'Jan Klaassen'));

#-------------------------------------------------------------------------------
# Get the statistics of the databases
#
my @db-docs = $connection.list_databases();
my %db-names;
my $idx = 0;
for @db-docs -> %doc {
  %db-names{%doc<name>} = $idx++;
}

#ok %db-names<admin>, 'virtual database admin found';
ok %db-names<db1>, 'db1 found';
ok %db-names<db2>, 'db2 found';

#ok @db-docs[%db-names<admin>]<empty>, 'Virtual database admin is empty';
ok !@db-docs[%db-names<db1>]<empty>, 'Database db1 is not empty';
ok !@db-docs[%db-names<db1>]<empty>, 'Database db2 is not empty';

#-------------------------------------------------------------------------------
# Get all database names
#
my @dbns = $connection.database_names();

#ok any(@dbns) ~~ 'admin', 'admin is found in list';
ok any(@dbns) ~~ 'db1', 'db1 is found in list';
ok any(@dbns) ~~ 'db2', 'db2 is found in list';


done();
exit(0);
