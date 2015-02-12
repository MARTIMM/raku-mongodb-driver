#`{{
  Testing;
    collection.count()                  Count documents whithout using find.
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
$collection.insert( $%( 'name' => 'Jan Klaassen'));
$collection.insert( $%( 'name' => 'Piet Hein'));

#-------------------------------------------------------------------------------
#
is $collection.count, 2, 'Two douments in collection';
is $collection.count(%(name => 'Piet Hein')), 1, 'One document found';

#-------------------------------------------------------------------------------
# Cleanup
#
$database.drop;

done();
exit(0);
