use v6;
use MongoDB::Protocol;

class MongoDB::Cursor does MongoDB::Protocol;

has $.collection is rw;
has %.criteria is rw;

# int64 (8 byte buffer)
has Buf $.id is rw;

# batch of documents in last response
has @.documents is rw;

submethod BUILD ( :$collection!, :%criteria!, :%OP_REPLY ) {

    $!collection = $collection;
    %!criteria = %criteria;

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

# Add support for next() as in the mongo shell
method next ( --> Any ) { return self.fetch }

method kill ( --> Nil ) {

    # invalidate cursor on database
    self.wire.OP_KILL_CURSORS( self );
    
    # invalidate cursor id
    $.id = Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 );

    return;
}

# Get count of found documents
#
method count ( Int :$skip = 0, Int :$limit = 0 --> Num ) {

    my $database = $!collection.database;
    my $request = %( count => $!collection.name, query => %!criteria);
    $request<skip> = $skip if $skip;
    $request<limit> = $limit if $limit;

    my %docs = $database.run_command($request);

    return %docs<n>;
}

