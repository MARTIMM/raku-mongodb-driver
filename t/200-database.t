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
# Use run_command foolishly
#
$database = $connection.database('db1');
my %docs = %($database.run_command(%(listDatabases => 1)));
ok !%docs<ok>.Bool, 'Run command ran not ok';
is %docs<errmsg>, 'access denied; use admin db', 'access denied; use admin db';

#-------------------------------------------------------------------------------
# Use run_command to get database statistics
#
$database = $connection.database('admin');
%docs = %($database.run_command(%(listDatabases => 1)));
ok %docs<ok>.Bool, 'Run command ran ok';
ok %docs<totalSize> > 1e0, 'Total size at least bigger than one byte ;-)';

my %db-names;
my @db-docs = @(%docs<databases>);
my $idx = 0;
for @db-docs -> %doc {
    %db-names{%doc<name>} = $idx++;
}

#say %db-names.perl;

ok %db-names<admin>, 'virtual database admin found';
ok %db-names<db1>, 'db1 found';
ok %db-names<db2>, 'db2 found';

ok @(%docs<databases>)[%db-names<admin>]<empty>, 'Virtual database admin is empty';
ok !@(%docs<databases>)[%db-names<db1>]<empty>, 'Database db1 is not empty';
ok !@(%docs<databases>)[%db-names<db1>]<empty>, 'Database db2 is not empty';

#-------------------------------------------------------------------------------
# Drop a database
#
$database = $connection.database('db1');
my %r = %($database.drop());
ok %r<ok>.Bool, 'Drop command went well';
is %r<dropped>, 'db1', 'Dropped database name checks ok';

$database = $connection.database('admin');
%docs = %($database.run_command(%(listDatabases => 1)));

%db-names = %();
@db-docs = @(%docs<databases>);
$idx = 0;
for @db-docs -> %doc {
    %db-names{%doc<name>} = $idx++;
}

ok !%db-names<db1>, 'db1 not found';

#-------------------------------------------------------------------------------
# Cleanup
#
done();
exit(0);
