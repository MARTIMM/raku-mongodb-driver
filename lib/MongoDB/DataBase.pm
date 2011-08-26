class MongoDB::DataBase;

use MongoDB::Collection;

has MongoDB::Connection $.connection is rw;
has Str $.name is rw;

submethod BUILD ( MongoDB::Connection $connection, Str $name ) {

    $.connection = $connection;

    # TODO validate name
    $.name = $name;
}

method collection ( Str $name ) {

    return MongoDB::Collection.new(
        database    => self,
        name        => $name,
    );
}
