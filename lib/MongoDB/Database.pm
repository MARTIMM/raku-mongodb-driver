use MongoDB::Collection;

class MongoDB::Database;

has $.connection is rw;
has Str $.name is rw;

submethod BUILD ( :$connection, Str :$name ) {

    $!connection = $connection;

    # TODO validate name
    $!name = $name;
}

method collection ( Str $name --> MongoDB::Collection ) {

    return MongoDB::Collection.new(
        database    => self,
        name        => $name,
    );
}
