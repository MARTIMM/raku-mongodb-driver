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

    self.wire.OP_QUERY( self );
}

method fetch ( ) {

    #say $!id;
    # there are no more documents in last response batch
    # but there is next batch to fetch from database
    if not @.documents and [+]$.id.list {
        self.wire.OP_GETMORE( self );
    }

    return @.documents.shift;
}

method _feed ( %OP_REPLY ) {

    # assign cursorID
    # buffer of 0x00 x 8 means there are no more documents to fetch
    $.id = %OP_REPLY{ 'cursor_id' };

    # assign documents
    @.documents = %OP_REPLY{ 'documents' }.list;
}
