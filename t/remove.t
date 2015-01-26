use Test;
use MongoDB;

plan( 4 );

my $connection = MongoDB::Connection.new;
my $database = $connection.database( 'test' );
my $collection = $database.collection( 'perl6_driver' );

# TODO replace with drop when available
$collection.remove( );

# feed test data
$collection.insert( { 'foo' => 0 }, { 'foo' => 0 }, { 'bar' => 0 }, { 'bar' => 0 } );

lives_ok {
    $collection.remove( { 'foo' => 0 } );
}, 'remove many documents';

lives_ok {
    $collection.remove( { 'bar' => 0 }, :single_remove );
}, 'remove single document with single_remove flag';

lives_ok {
    $collection.remove( { 'baz' => 0 } );
}, 'remove no documents';

# TODO check output, expected result
# { "_id" : ObjectId("..."), "bar" : 0 }

lives_ok {
    $collection.remove( );
}, 'remove all documents';

# TODO check output, expected result
# empty collection
