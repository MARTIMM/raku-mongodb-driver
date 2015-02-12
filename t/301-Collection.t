#`{{
  Testing;
    collection.count()                  Count documents whithout using find.
    collection.distinct()               Find distinct values
}}

#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;
use MongoDB;

#-------------------------------------------------------------------------------
my MongoDB::Connection $connection .= new();
my MongoDB::Database $database = $connection.database('test');

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');
$collection.insert( $%( 'name' => 'Jan Klaassen', code => 14));
$collection.insert( $%( 'name' => 'Piet Hein', code => 20));
$collection.insert( $%( 'name' => 'Jan Hein', code => 20));

#-------------------------------------------------------------------------------
#
is $collection.count, 3, 'Two douments in collection';
is $collection.count(%(name => 'Piet Hein')), 1, 'One document found';

#-------------------------------------------------------------------------------
#
my @code-list = $collection.distinct('code');
is_deeply @code-list.sort, $( 14, 20), 'Codes found are 14, 20';

@code-list = $collection.distinct( 'code', %(name => 'Piet Hein'));
is_deeply @code-list.sort, [20], 'Code found is 20';

#-------------------------------------------------------------------------------
# Cleanup
#
$database.drop;

done();
exit(0);
