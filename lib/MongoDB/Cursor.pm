class MongoDB::Cursor;

has MongoDB::Collection $.collection is rw;

has %.query is rw;

# int64 (8 byte buffer)
has Buf $.id is rw;

# batch of documents in last response
has @!documents is rw;

submethod BUILD ( MongoDB::Collection $collection, %query ) {

    $.collection = $collection;

    %.query = %query;

    MongoDB.wire.OP_QUERY( self );
}

method fetch ( ) {

    # there are no more documents in last response batch
    # but there is next batch to fetch from database
    if not @!documents and [+]$!id.contents {
        MongoDB.wire.OP_GETMORE( self );
    }

    return @!documents.shift;
}

method _feed ( %OP_REPLY ) {

    # assign cursorID
    # buffer of 0x00 x 8 means there are no more documents to fetch
    $.id = %OP_REPLY{ 'cursor_id' };

    # assign documents
    @!documents = %OP_REPLY{ 'documents' }.list;
}
