use v6;
use Test;
use MongoDB;

my $connection = MongoDB::Connection.new;
my $database = $connection.database( 'test' );
my $collection = $database.collection( 'perl6_driver' );

# TODO replace with drop when available
$collection.remove( );

lives_ok {
    $collection.insert( { 'foo' => 0 } );
}, 'insert single document';

lives_ok {
    $collection.insert( { 'bar' => 0 }, { 'bar' => 1 } );
}, 'insert multiple documents';

# TODO simulate failure, maybe violate constraint?
lives_ok {
    $collection.insert( { 'baz' => 0 }, :continue_on_error );
}, 'insert single document with continue_on_error flag';

dies_ok {
    $collection.insert( );
}, 'insert without documents is forbidden';

dies_ok {
    $collection.insert( 1, "a" );
}, 'insert fails on incorrect document types';

# TODO check output, expected result
# { "_id" : ObjectId("..."), "foo" : 0 }
# { "_id" : ObjectId("..."), "bar" : 0 }
# { "_id" : ObjectId("..."), "bar" : 1 }
# { "_id" : ObjectId("..."), "baz" : 0 }

#-----------------------------------------------------------------------------
# Cleanup
#
$database.drop;

done();
exit(0);
