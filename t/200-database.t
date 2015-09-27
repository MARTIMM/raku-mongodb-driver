#`{{
  Testing;
    database.get_last_error()           Get last error
    database.get_prev_error()           Get previous errors
    database.reset_error()              Reset errors
    database.run_command()              Run command
    database.drop()                     Drop database
    database.create_collection()        Create collection explicitly
}}

use v6;
use Test;
use MongoDB::Connection;

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

my MongoDB::Connection $connection = get-connection();

# Drop database first then create new databases
#
$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');
isa-ok $database, 'MongoDB::Database';
is $database.name, 'test', 'Check database name';

# Create a collection explicitly. Try for a second time
#
$database.create_collection('cl1');

if 1 {
  $database.create_collection('cl1');
  CATCH {
    when X::MongoDB::Database {
      ok .message ~~ ms/collection already exists/, 'Collection cl1 exists';
    }

    default {
      say .perl;
    }
  }
}

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
my Pair @req = listDatabases => 1;
my $docs = $database.run_command(@req);
ok !$docs<ok>.Bool, 'Run command ran not ok';
is $docs<errmsg>,
   'listDatabases may only be run against the admin database.',
   'listDatabases may only be run against the admin database';

#-------------------------------------------------------------------------------
# Use run_command to get database statistics
#
$database = $connection.database('admin');
$docs = $database.run_command(@req);
ok $docs<ok>.Bool, 'Run command ran ok';
ok $docs<totalSize> > 1, 'Total size at least bigger than one byte ;-)';

my %db-names;
my Array $db-docs = $docs<databases>;
my $idx = 0;
for $db-docs[*] -> $doc {
  %db-names{$doc<name>} = $idx++;
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
$docs = $database.run_command(@req);

%db-names = %();
$idx = 0;
$db-docs = $docs<databases>;
for $db-docs[*] -> $doc {
  %db-names{$doc<name>} = $idx++;
}

ok %db-names<test>:!exists, 'test not found';

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done-testing();
exit(0);
