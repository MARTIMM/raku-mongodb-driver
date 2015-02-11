use v6;
use Test;
use MongoDB;

my $connection = MongoDB::Connection.new;
my $database = $connection.database( 'test' );
my $collection = $database.collection( 'perl6_driver' );

# TODO replace with drop when available
$collection.remove( );

# feed test data
$collection.insert( { 'foo' => 0 }, { 'foo' => 0 } );

lives_ok {
    $collection.update( { 'foo' => 0 }, { '$inc' => { 'foo' => 1 } } );
}, 'update single document';

lives_ok {
    $collection.update( { 'foo' => { '$exists' => True } }, { '$inc' => { 'foo' => 1 } }, :multi_update );
}, 'update many documents with multi_update flag';

lives_ok {
    $collection.update( { 'bar' => 0 }, { '$inc' => { 'bar' => 1 } } );
}, 'update nonexisting document';


lives_ok {
    $collection.update( { 'bar' => 0 }, { '$inc' => { 'bar' => 1 } }, :upsert );
}, 'update nonexisting document with upsert flag';

dies_ok {
    $collection.update( );
}, 'update without selector and document is forbidden';

dies_ok {
    $collection.update( 1, "a" );
}, 'update fails on incorrect document types';

# TODO check output, expected result
# { "_id" : ObjectId("..."), "foo" : 2 }
# { "_id" : ObjectId("..."), "foo" : 1 }
# { "_id" : ObjectId("..."), "bar" : 1 }

#-----------------------------------------------------------------------------
# Cleanup
#
$database.drop;

done();
exit(0);
