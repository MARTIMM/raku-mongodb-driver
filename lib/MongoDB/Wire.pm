use BSON:ver<0.5.1+>;

class MongoDB::Wire is BSON;

# Implements Mongo Wire Protocol
# http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol

has Bool $.debug is rw = False;
has Int $.request_id is rw = 0;

# http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
has %.op_codes = (
    'OP_REPLY'          => 1,       # Reply to a client request. responseTo is set
    'OP_MSG'            => 1000,    # generic msg command followed by a string. depricated
    'OP_UPDATE'         => 2001,    # update document
    'OP_INSERT'         => 2002,    # insert new document
    'RESERVED'          => 2003,    # formerly used for OP_GET_BY_OID
    'OP_QUERY'          => 2004,    # query a collection
    'OP_GET_MORE'       => 2005,    # Get more data from a query. See Cursors
    'OP_DELETE'         => 2006,    # Delete documents
    'OP_KILL_CURSORS'   => 2007,    # Tell database client is done with a cursor
);

multi method _msg_header ( Int $length, Str $op_code --> Buf ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader

    # struct MsgHeader
    my Buf $msg_header =

        # int32 messageLength
        # total message size, including this
        self._int32( $length + 4 * 4 )

        # int32 requestID
        # identifier for this message
        ~ self._int32( $.request_id++ )

        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
        ~ self._int32( 0 )

        # int32 opCode
        # request type
        ~ self._int32( %.op_codes{ $op_code } );

    return $msg_header;
}

multi method _msg_header ( Array $a --> Hash ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader

    # struct MsgHeader
    my %msg_header = %(

        # int32 messageLength
        # total message size, including this
        'message_length'    => self._int32( $a ),

        # int32 requestID
        # identifier for this message
        'request_id'        => self._int32( $a ),

        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
        'response_to'       => self._int32( $a ),

        # int32 opCode
        # request type
        'op_code'           => self._int32( $a ),

    );

    # the only allowed message returned from database is OP_REPLY
    die 'Unexpected OP_code' unless %msg_header{ 'op_code' } ~~ %.op_codes{ 'OP_REPLY' };

    return %msg_header;
}

method OP_INSERT ( $collection, Int $flags, *@documents --> Nil ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPINSERT

    my Buf $OP_INSERT =

        # int32 flags
        # bit vector
        self._int32( $flags )

        # cstring fullCollectionName
        # "dbname.collectionname"
        ~ self._cstring( join '.', $collection.database.name, $collection.name );

    # document* documents
    # one or more documents to insert into the collection
    for @documents -> $document {
        $OP_INSERT ~= self._document( $document );
    }

    # MsgHeader header
    # standard message header
    my Buf $msg_header = self._msg_header( $OP_INSERT.elems, 'OP_INSERT' );

    # send message without waiting for response
    $collection.database.connection.send( $msg_header ~ $OP_INSERT, False );
}

method OP_QUERY ( $collection, $flags, $number_to_skip, $number_to_return,
                  %query, %return_field_selector
                  --> Hash
                ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

    my Buf $OP_QUERY =

        # int32 flags
        # bit vector of query options
        #
        self._int32( $flags )

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        ~ self._cstring( join '.', $collection.database.name, $collection.name )

        # int32 numberToSkip
        # number of documents to skip
        #
        ~ self._int32( $number_to_skip )

        # int32 numberToReturn
        # number of documents to return
        # in the first OP_REPLY batch
        #
        ~ self._int32( $number_to_return )

        # document query
        # query object
        #
        ~ self._document( %query )
        ;
        
    # [ document  returnFieldSelector; ]
    # Optional. Selector indicating the fields to return
    #
    if +%return_field_selector {
        $OP_QUERY ~= self._document(%return_field_selector);
    }


    # MsgHeader header
    # standard message header
    my Buf $msg_header = self._msg_header( $OP_QUERY.elems, 'OP_QUERY' );

    # send message and wait for response
    my Buf $OP_REPLY = $collection.database.connection.send( $msg_header ~ $OP_QUERY, True );

    # parse response
    my %OP_REPLY = self.OP_REPLY( $OP_REPLY );

    if $.debug {
        say 'OP_QUERY:', %OP_REPLY.perl;
    }

    # TODO check if requestID matches responseTo

    # return response back to cursor
    return %OP_REPLY;
}

method OP_GETMORE ( $cursor --> Hash ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPGETMORE

    my Buf $OP_GETMORE =

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
    my Buf $msg_header = self._msg_header( $OP_GETMORE.elems, 'OP_GET_MORE' );

    # send message and wait for response
    my Buf $OP_REPLY = $cursor.collection.database.connection.send( $msg_header ~ $OP_GETMORE, True );

    # parse response
    my %OP_REPLY = self.OP_REPLY( $OP_REPLY );

    if $.debug {
        say 'OP_GETMORE:', %OP_REPLY.perl;
    }

    # TODO check if requestID matches responseTo

    # TODO check if cursorID matches (if present)

    # return response back to cursor
    return %OP_REPLY;
}

method OP_KILL_CURSORS ( *@cursors --> Nil ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPKILLCURSORS
    
    my Buf $OP_KILL_CURSORS =
    
        # int32 ZERO
        # 0 - reserved for future use
        self._int32( 0 )
    
        # int32 numberOfCursorIDs
        # number of cursorIDs in message
        ~ self._int32( +@cursors );
    
    # int64* cursorIDs
    # sequence of cursorIDs to close
    for @cursors -> $cursor {
        $OP_KILL_CURSORS ~= $cursor.id;
    }
    
    # MsgHeader header
    # standard message header
    my Buf $msg_header = self._msg_header( $OP_KILL_CURSORS.elems, 'OP_KILL_CURSORS' );
    
    # send message without waiting for response
    @cursors[0].collection.database.connection.send( $msg_header ~ $OP_KILL_CURSORS, False );
}

method OP_UPDATE ( $collection, Int $flags, %selector, %update --> Nil ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPUPDATE

    my Buf $OP_UPDATE =

        # int32 ZERO
        # 0 - reserved for future use
        self._int32( 0 )

        # cstring fullCollectionName
        # "dbname.collectionname"
        ~ self._cstring( join '.', $collection.database.name, $collection.name )

        # int32 flags
        # bit vector
        ~ self._int32( $flags )

        # document selector
        # query object
        ~ self._document( %selector )

        # document update
        # specification of the update to perform
        ~ self._document( %update );

    # MsgHeader header
    # standard message header
    my Buf $msg_header = self._msg_header( $OP_UPDATE.elems, 'OP_UPDATE' );

    # send message without waiting for response
    $collection.database.connection.send( $msg_header ~ $OP_UPDATE, False );
}

method OP_DELETE ( $collection, Int $flags, %selector --> Nil ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPDELETE

    my Buf $OP_DELETE =

        # int32 ZERO
        # 0 - reserved for future use
        self._int32( 0 )

        # cstring fullCollectionName
        # "dbname.collectionname"
        ~ self._cstring( join '.', $collection.database.name, $collection.name )

        # int32 flags
        # bit vector
        ~ self._int32( $flags )

        # document selector
        # query object
        ~ self._document( %selector );

    # MsgHeader header
    # standard message header
    my Buf $msg_header = self._msg_header( $OP_DELETE.elems, 'OP_DELETE' );

    # send message without waiting for response
    $collection.database.connection.send( $msg_header ~ $OP_DELETE, False );
}

method OP_REPLY ( Buf $b --> Hash ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY

    my $a = $b.list;

    my %OP_REPLY = %(

        # MsgHeader header
        # standard message header
        'msg_header' => self._msg_header( $a ),

        # int32 responseFlags
        # bit vector
        'response_flags' => self._int32( $a ),

        # int64 cursorID
        # cursor id if client needs to do get more's
        # TODO big integers are not yet implemented in Rakudo
        # so cursor is build using raw Buf
        'cursor_id' => self._nyi( $a, 8 ),

        # int32 startingFrom
        # where in the cursor this reply is starting
        'starting_from' => self._int32( $a ),

        # int32 numberReturned
        # number of documents in the reply
        'number_returned' => self._int32( $a ),

        # document* documents
        # documents
        'documents' => [ ],

    );

    # extract documents from message
    for ^%OP_REPLY{ 'number_returned' } {
        my %document = self._document( $a );
        %OP_REPLY{ 'documents' }.push( { %document } );
    }

    # every response byte must be consumed
    die 'Unexpected bytes at the end of response' if $a.elems;

    return %OP_REPLY;
}

multi method _nyi ( Array $a, Int $length --> Buf ) {
    # fetch given amount of bytes from Array and return as Buffer
    # mostly used to jump over not yet implemented decoding

    my @a;

    @a.push( $a.shift ) for ^$length;

    return Buf.new( @a );
}
