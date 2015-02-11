#`{{
  Testing;
    database.get_last_error()           Get last error
    database.get_prev_error()           Get previous errors
    database.reset_error()              Reset errors
    database.run_command()              Run command
    database.drop()                     Drop database
}}

use v6;
use Test;
use MongoDB;

my MongoDB::Connection $connection .= new();

# Create databases with a collection and data
#
my MongoDB::Database $database = $connection.database('test');
isa_ok( $database, 'MongoDB::Database');

my MongoDB::Collection $collection = $database.collection( 'cl1' );
$collection.insert( $%( 'name' => 'Jan Klaassen'));

#-------------------------------------------------------------------------------
# Error checking
#
my $error-doc = $database.get_last_error;
ok $error-doc<ok>.Bool, 'No errors';
$error-doc = $database.get_prev_error;
ok $error-doc<ok>.Bool, 'No previous errors';

$database.reset_error;

#-------------------------------------------------------------------------------
# Use run_command foolishly
#
$database = $connection.database('test');
my $docs = $database.run_command(%(listDatabases => 1));
ok !$docs<ok>.Bool, 'Run command ran not ok';
is $docs<errmsg>, 'access denied; use admin db', 'access denied; use admin db';

#-------------------------------------------------------------------------------
# Use run_command to get database statistics
#
$database = $connection.database('admin');
$docs = $database.run_command(%(listDatabases => 1));
ok $docs<ok>.Bool, 'Run command ran ok';
ok $docs<totalSize> > 1, 'Total size at least bigger than one byte ;-)';

my %db-names;
my @db-docs = @($docs<databases>);
for (@db-docs) Z ^+@db-docs -> %doc, $idx {
    %db-names{%doc<name>} = $idx;
}

ok %db-names<test>:exists, 'test found';

ok !@($docs<databases>)[%db-names<test>]<empty>, 'Database test is not empty';

#-------------------------------------------------------------------------------
# Drop a database
#
$database = $connection.database('test');
my %r = %($database.drop());
ok %r<ok>.Bool, 'Drop command went well';
is %r<dropped>, 'test', 'Dropped database name checks ok';

$database = $connection.database('admin');
$docs = $database.run_command(%(listDatabases => 1));

%db-names = %();
@db-docs = @($docs<databases>);
for (@db-docs) Z ^+@db-docs -> %doc, $idx {
    %db-names{%doc<name>} = $idx;
}

ok %db-names<test>:!exists, 'test not found';

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done();
exit(0);
