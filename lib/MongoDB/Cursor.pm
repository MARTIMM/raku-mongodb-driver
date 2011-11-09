use MongoDB::Protocol;

class MongoDB::Cursor does MongoDB::Protocol;

has $.collection is rw;

has %.query is rw;

# int64 (8 byte buffer)
has Buf $.id is rw;

# batch of documents in last response
has @.documents is rw;

submethod BUILD ( :$collection, :%query ) {

    $.collection = $collection;

    %.query = %query;

    # request first batch of documents
    my %OP_REPLY = self.wire.OP_QUERY( self );
    
    # assign cursorID
    $.id = %OP_REPLY{ 'cursor_id' };
    
    # assign documents
    @.documents = %OP_REPLY{ 'documents' }.list;
}

method fetch ( ) {

    # there are no more documents in last response batch
    # but there is next batch to fetch from database
    if not @.documents and [+]$.id.list {

        # request next batch of documents
        my %OP_REPLY = self.wire.OP_GETMORE( self );
        
        # assign cursorID
        $.id = %OP_REPLY{ 'cursor_id' };
        
        # assign documents
        @.documents = %OP_REPLY{ 'documents' }.list;
    }

    return @.documents.shift;
}

