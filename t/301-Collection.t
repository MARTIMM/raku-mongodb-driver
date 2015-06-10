#`{{
  Testing;
    collection.count()                  Count documents whithout using find.
    collection.distinct()               Find distinct values
    list_collections()                  Return collection info in database
    collection_names()                  Return collectionnames in database
}}

#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;
use MongoDB::Connection;

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
is $collection.count, 3, 'Two documents in collection';
is $collection.count(%(name => 'Piet Hein')), 1, 'One document found';

#-------------------------------------------------------------------------------
#
my $code-list = $collection.distinct('code');
is-deeply $code-list.sort, $( 14, 20), 'Codes found are 14, 20';

$code-list = $collection.distinct( 'code', %(name => 'Piet Hein'));
is-deeply $code-list, [20], 'Code found is 20';

#-------------------------------------------------------------------------------
#
$collection = $database.collection('cl2');
$collection.insert( $%(code => 15));

my $docs = $database.list_collections;
is $docs.elems, 5, 'Number of docs: 5 = system table and 2 for each collection';

$docs = $database.collection_names;
is-deeply $docs.sort, <cl1 cl2>, 'Test collection names';

#-------------------------------------------------------------------------------
# Cleanup
#
$database.drop;

done();
exit(0);
