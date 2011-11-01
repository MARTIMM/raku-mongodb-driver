use MongoDB::Protocol;
use MongoDB::Cursor;

class MongoDB::Collection does MongoDB::Protocol;

has $.database is rw;
has Str $.name is rw;

submethod BUILD ( :$database, Str :$name ) {

    $.database = $database;

    # TODO validate name
    $.name = $name;
}

method insert ( *@documents ) {
    self.wire.OP_INSERT( self, 0, @documents );
}

method find ( %query = { } ) {

    return MongoDB::Cursor.new(
        collection  => self,
        query       => %query,
    );
}

method update ( %selector, %update ) {
    self.wire.OP_UPDATE( self, %selector, %update );
}

method delete ( %selector = { } ) {
    self.wire.OP_DELETE( self, %selector );
}

