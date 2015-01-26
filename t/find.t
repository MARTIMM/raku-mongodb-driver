use Test;
use MongoDB;

my $connection = MongoDB::Connection.new;
my $database = $connection.database( 'test' );
my $collection = $database.collection( 'perl6_driver' );

# TODO replace with drop when available
$collection.remove( );

my (@documents, $cursor);

# feed test data
@documents.push( $(%( 'foo' => $_ )) ) for ^128;
$collection.insert( @documents );

lives_ok {
    $cursor = $collection.find( )
}, 'initialize cursor for all documents';

lives_ok
{
    @documents = ( );
    while $cursor.fetch( ) -> %document {
        @documents.push( { %document } );
    }
}, 'fetch all documents';

# TODO compare documents

lives_ok {
    $cursor = $collection.find( number_to_return => 8 )
}, 'initialize cursor for given amount of documents';

lives_ok {
    $cursor.kill();
}, 'kill cursor';

#done();
#exit(1);

is ( [+]( $cursor.id.list ) ), 0, 'cursor is killed';

lives_ok
{
    @documents = ( );
    while $cursor.fetch( ) -> %document {
        @documents.push( { %document } );
    }
}, 'fetch given amount of documents';

# TODO compare documents

lives_ok {
    $cursor = $collection.find( number_to_return => 1 )
}, 'initialize cursor for one document';

is ( [+]( $cursor.id.list ) ), 0, 'cursor for one document is closed automatically';

lives_ok
{
    @documents = ( );
    while $cursor.fetch( ) -> %document {
        @documents.push( { %document } );
    }
}, 'fetch one document';

# TODO compare documents

#-------------------------------------------------------------------------------
# Cleanup
#
done();
