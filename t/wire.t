BEGIN { @*INC.unshift( 'lib' ) }

use Test;
use MongoDB;

plan( 9 );

my $connection = MongoDB::Connection.new( );
my $database = $connection.database( 'test' );
my $collection = $database.collection( 'perl6_driver' );
my $cursor;
my %document;

# TODO replace this test with drop collection
lives_ok
    { $collection.delete( ) },
    'delete all old documents';

lives_ok
    { $collection.insert( { 'ala' => 'kot' } ) },
    'single insert';

lives_ok
    {
        $collection.update(
            { 'ala' => 'kot' },
            { '$set' => { 'zażółć' => 'gęślą jaźń' } }
        )
    },
    'single update';

lives_ok
    { $cursor = $collection.find( ) },
    'initialize cursor for all documents';

lives_ok
    { %document = $cursor.fetch( ) },
    'fetch the only document';

isa_ok
    %document.delete( '_id' ),
    BSON::ObjectId,
    'check document _id';

is_deeply
    %document,
    { "ala" => "kot", "zażółć" => "gęślą jaźń" },
    'check document content';

is_deeply
    ?$cursor.fetch( ),
    False,
    'no more documents to fetch';

lives_ok
    { $collection.delete( ) },
    'delete all documents';

