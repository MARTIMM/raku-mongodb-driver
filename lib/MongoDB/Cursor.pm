use MongoDB::Protocol;

class MongoDB::Cursor does MongoDB::Protocol;

has $.collection is rw;

# int64 (8 byte buffer)
has Buf $.id is rw;

# batch of documents in last response
has @.documents is rw;

submethod BUILD ( :$collection, :%OP_REPLY ) {

    $!collection = $collection;

    # assign cursorID
    $!id = %OP_REPLY{ 'cursor_id' };
    
    # assign documents
    @!documents = %OP_REPLY{ 'documents' }.list;
}

method fetch ( --> Any ) {

    # there are no more documents in last response batch
    # but there is next batch to fetch from database
    if not @.documents and [+]( $.id.list ) {

        # request next batch of documents
        my %OP_REPLY = self.wire.OP_GETMORE( self );
        
        # assign cursorID,
        # it may change to "0" if there are no more documents to fetch
        $.id = %OP_REPLY{ 'cursor_id' };
        
        # assign documents
        @.documents = %OP_REPLY{ 'documents' }.list;
    }

    # Return a document when there is one. If none left, return Nil
    #
    return +@.documents ?? @.documents.shift !! Nil;
}

method kill ( --> Nil ) {

    # invalidate cursor on database
    self.wire.OP_KILL_CURSORS( self );
    
    # invalidate cursor id
    $.id = Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 );

    return;
}
