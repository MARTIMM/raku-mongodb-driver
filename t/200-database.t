#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Connection $connection .= new();

# Create databases with a collection and data
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
# Use run_command to get database statistics
#
$database = $connection.database('admin');
my %docs = %($database.run_command(%(listDatabases => 1)));
my %db-names;
my @db-docs = @(%docs<databases>);
my $idx = 0;
for @db-docs -> %doc
{
  %db-names{%doc<name>} = $idx++;
}

#say %db-names.perl;

ok %db-names<admin>, 'virtual database admin found';
ok %db-names<db1>, 'db1 found';
ok %db-names<db2>, 'db2 found';

ok @(%docs<databases>)[%db-names<admin>]<empty>, 'Virtual database admin is empty';
ok !@(%docs<databases>)[%db-names<db1>]<empty>, 'Database db1 is not empty';
ok !@(%docs<databases>)[%db-names<db1>]<empty>, 'Database db2 is not empty';

done();
exit(0);
