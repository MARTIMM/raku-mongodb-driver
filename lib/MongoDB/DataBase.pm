use MongoDB::Collection;

class MongoDB::DataBase;

has $.connection is rw;
has Str $.name is rw;

submethod BUILD ( :$connection, Str :$name ) {

    $!connection = $connection;

    # TODO validate name
    $!name = $name;
}

method collection ( Str $name ) {

    return MongoDB::Collection.new(
        database    => self,
        name        => $name,
    );
}
