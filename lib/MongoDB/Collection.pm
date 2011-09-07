class MongoDB::Collection;

use MongoDB::Cursor;

has MongoDB::DataBase $.database is rw;
has Str $.name is rw;

submethod BUILD ( MongoDB::DataBase $database, Str $name ) {

    $.database = $database;

    # TODO validate name
    $.name = $name;
}

method insert ( %document ) {
    MongoDB.wire.OP_INSERT( self, %document );
}

method find ( %query = { } ) {
    
    return MongoDB::Cursor.new(
        collection  => self,
        query       => %query,
    );
}

