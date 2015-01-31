#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Connection $connection .= new();
my MongoDB::Database $database = $connection.database('db1');
my MongoDB::Collection $collection = $database.collection('cl1');
isa_ok( $database, 'MongoDB::Database');
isa_ok( $collection, 'MongoDB::Collection');

done();
exit(0);
