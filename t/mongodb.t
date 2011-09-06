BEGIN { @*INC.unshift( 'lib' ); @*INC.unshift( '../bson/lib' ); }

use Test;
use BSON;

plan( 1 );


#struct MsgHeader {
#    int32   messageLength; // total message size, including this
#    int32   requestID;     // identifier for this message
#    int32   responseTo;    // requestID from the original request
#                           //   (used in reponses from db)
#    int32   opCode;        // request type - see table below
#}

my $b = BSON.new( );

my $document = $b.encode( { "Hello" => "world!", "tab" => [ 1,2,3 ], "obj" => { "4" => 5 }, "zażółć" => "jaźń" } );

my $requestID = $b._int32( 666 );

my $responseTo = $b._int32( 0 );

my $opCode = $b._int32( 2002 );

# struct {
#    MsgHeader header;             // standard message header
#    int32     flags;              // bit vector - see below
#    cstring   fullCollectionName; // "dbname.collectionname"
#    document* documents;          // one or more documents to insert into the collection
#}

my $flags = $b._int32( 0 );
my $fullCollectionName = $b._cstring( "test.perl" );

my $length = $b._int32( 4 + +$requestID.contents + +$responseTo.contents + +$opCode.contents + +$document.contents + +$flags.contents + +$fullCollectionName.contents );

my @full = $length.contents, $requestID.contents, $responseTo.contents, $opCode.contents, $flags.contents, $fullCollectionName.contents, $document.contents;

@full.perl.say;

my $full = Buf.new( @full );

#say $full.unpack( 'A*');

my $sock = IO::Socket::INET.new( host => '127.0.0.1', port => 27017 );
$sock.send( $full.unpack( 'A*' ) );
