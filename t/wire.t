BEGIN { @*INC.unshift( 'lib' ); @*INC.unshift( '../bson/lib' ); }

use Test;
use MongoDB;

plan( 1 );

my $connection = MongoDB::Connection.new( );
my $database = $connection.database( 'test' );
my $collection = $database.collection( 'perl' );

$collection.insert( {"ala" => "kot" } );
say "inserted";
$collection.insert( {"zażółć" => ["gęślą", "jaźń"] } );
say "inserted";
my $cursor = $collection.find( { } );
#$collection.insert( {"ktory" => $_ } ) for ^100;

say "queried";
while $cursor.fetch( ) -> $document {
    say "DOCUMENT!";
    say $document.perl;
}