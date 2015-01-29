# Done by option -l of prove
# BEGIN { @*INC.unshift( 'lib' ) }

#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;
BEGIN { @*INC.unshift( '/home/marcel/Languages/Perl6/Projects/BSON/lib' ) }

use v6;
use Test;
use MongoDB;

my MongoDB::Connection $connection .= new();
my MongoDB::Database $d1 = $d1 = $connection.database('db2');
isa_ok( $d1, 'MongoDB::Database');

$d1 = $connection.database('admin');
my %docs = %($d1.run_command(%(listDatabases => 1)));
my %db-names;
for @(%docs<databases>) -> %doc
{
  %db-names{%doc<name>} = 1;
}

#say %db-names.perl;

ok %db-names<test>, 'test found';
ok %db-names<db2>, 'db2 found';

#`((
for @(%docs<databases>) -> %doc
{
  say "\nName: %doc<name>";
  say "Empty: %doc<empty>";
  say "Size: %doc<sizeOnDisk>";
}
))

done();
exit(0);
