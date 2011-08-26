class MongoDB::Collection;

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

method query ( %query = { } ) {
    MongoDB.wire.OP_QUERY( self, %query );
}

