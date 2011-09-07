use BSON;

class MongoDB::Wire is BSON;

# Implements Mongo Wire Protocol
# http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol

# http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
has %.op_codes = (
    'OP_REPLY'          => 1,       # Reply to a client request. responseTo is set
    'OP_MSG'            => 1000,    # generic msg command followed by a string
    'OP_UPDATE'         => 2001,    # update document
    'OP_INSERT'         => 2002,    # insert new document
    'RESERVED'          => 2003,    # formerly used for OP_GET_BY_OID
    'OP_QUERY'          => 2004,    # query a collection
    'OP_GET_MORE'       => 2005,    # Get more data from a query. See Cursors
    'OP_DELETE'         => 2006,    # Delete documents
    'OP_KILL_CURSORS'   => 2007,    # Tell database client is done with a cursor
);

multi method _msg_header ( Int $length, Str $op_code ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
    
    # struct MsgHeader
    my $msg_header =
        
        # int32 messageLength
        # total message size, including this
        self._int32( $length + 4 * 4 )
        
        # int32 requestID
        # identifier for this message
        ~ self._int32( ( 1 .. 2147483647 ).pick )
        
        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
        ~ self._int32( 0 )
    
        # int32 opCode
        # request type
        ~ self._int32( %.op_codes{ $op_code } );

    return $msg_header;
}

multi method _msg_header ( Buf $b ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
    
    # struct MsgHeader
	my %msg_header = (
        
        # int32 messageLength
        # total message size, including this
        'message_length'    => self._int32( $b ),

        # int32 requestID
        # identifier for this message
		'request_id'        => self._int32( $b ),
    
        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
		'response_to'       => self._int32( $b ),
		
        # int32 opCode
        # request type
        'op_code'           => self._int32( $b ),
	
    );
	
    # the only allowed message returned from database is OP_REPLY
    die 'Unexpected OP_code' unless %msg_header{ 'op_code' } ~~ %.op_codes{ 'OP_REPLY' };
    
	return %msg_header;
}

method OP_INSERT ( MongoDB::Collection $collection, %document, Int $flags = 0 ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPINSERT

    my $OP_INSERT =
        
        # int32 flags
        # bit vector
        self._int32( $flags )
    
        # cstring fullCollectionName
        # "dbname.collectionname"
        ~ self._cstring( join '.', $collection.database.name, $collection.name )
        
        # document* documents
        # one or more documents to insert into the collection
        # TODO support multiple documents
        ~ self._document( %document );

    # MsgHeader header
    # standard message header
    my $msg_header = self._msg_header( +$OP_INSERT.contents, 'OP_INSERT' );
    
    # send message without waiting for response
    $collection.database.connection.send( $msg_header ~ $OP_INSERT, False );
}

method OP_QUERY ( MongoDB::Cursor $cursor ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

    my $OP_QUERY =

        # int32 flags
        # bit vector of query options
        self._int32( 0 )

        # cstring fullCollectionName
        # "dbname.collectionname"
        ~ self._cstring( join '.', $cursor.collection.database.name, $cursor.collection.name )

        # int32 numberToSkip
        # number of documents to skip
        ~ self._int32( 0 )

        # int32 numberToReturn
        # number of documents to return
        # in the first OP_REPLY batch
        ~ self._int32( 0 )

        # document query
        # query object
        ~ self._document( $cursor.query );
    
    # TODO
    # [ document  returnFieldSelector; ]
    # Selector indicating the fields to return

    # MsgHeader header
    # standard message header
    my $msg_header = self._msg_header( +$OP_QUERY.contents, 'OP_QUERY' );

    # send message and wait for response
    my $OP_REPLY = $cursor.collection.database.connection.send( $msg_header ~ $OP_QUERY, True );
    
    # parse response
    my %OP_REPLY = self.OP_REPLY( $OP_REPLY );

    say "OP_QUERY";
    %OP_REPLY.perl.say;
    
    # TODO check if requestID matches responseTo
    
    # return response back to cursor
    $cursor._feed( %OP_REPLY );
}

method OP_GETMORE ( MongoDB::Cursor $cursor ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPGETMORE
    
    my $OP_GETMORE =
    
        # int32 ZERO
        # 0 - reserved for future use
        self._int32( 0 )
    
        # cstring fullCollectionName
        # "dbname.collectionname"
        ~ self._cstring( join '.', $cursor.collection.database.name, $cursor.collection.name )
    
        # int32 numberToReturn
        # number of documents to return
        ~ self._int32( 0 )
    
        # int64 cursorID
        # cursorID from the OP_REPLY
        ~ $cursor.id;
    
    # MsgHeader header
    # standard message header
    # (watch out for inconsistent OP_code and messsage name)
    my $msg_header = self._msg_header( +$OP_GETMORE.contents, 'OP_GET_MORE' );
    
    # send message and wait for response
    my $OP_REPLY = $cursor.collection.database.connection.send( $msg_header ~ $OP_GETMORE, True );
    
    # parse response
    my %OP_REPLY = self.OP_REPLY( $OP_REPLY );
    
    say "OP_GETMORE";
    %OP_REPLY.perl.say;
    
    # TODO check if requestID matches responseTo
    
    # TODO check if cursorID matches (if present)
    
    # return response back to cursor
    $cursor._feed( %OP_REPLY );
}

method OP_REPLY ( Buf $b ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY
	
	my %OP_REPLY = (

        # MsgHeader header
        # standard message header
        'msg_header' => self._msg_header( $b ),
    
        # int32 responseFlags
        # bit vector
        'response_flags' => self._int32( $b ),
    
        # int64 cursorID
        # cursor id if client needs to do get more's
        # TODO big integers are not yet implemented in Rakudo
        # so cursor is build using raw Buf
        'cursor_id' => self._nyi( $b, 8 ),
    
        # int32 startingFrom
        # where in the cursor this reply is starting
        'starting_from' => self._int32( $b ),
    
        # int32 numberReturned
        # number of documents in the reply
        'number_returned' => self._int32( $b ),
    
        # document* documents
        # documents
        'documents' => ( ),
    
    );
    
    # extract documents in message
    for ^%OP_REPLY{ 'number_returned' } {
        my %document = self._document( $b );
        %OP_REPLY{ 'documents' }.push( { %document } );
    }

    # every response byte must be consumed
    die 'Response ended incorrectly' if +$b.contents;
    
    return %OP_REPLY;
}

multi method _nyi ( Buf $b, Int $length ) {
    # fetch given amount of bytes from buffer and return as buffer
    # mostly used to jump over not yet implemented decoding

    my $nyi = Buf.new( );
    
    $nyi.contents.push( $b.contents.shift ) for ^$length;
    
    return $nyi;
}

# HACK to concatenate 2 Buf()s
# workaround for https://rt.perl.org/rt3/Public/Bug/Display.html?id=96430
multi sub infix:<~>(Buf $a, Buf $b) {

    return Buf.new( $a.contents.list, $b.contents.list );
}
