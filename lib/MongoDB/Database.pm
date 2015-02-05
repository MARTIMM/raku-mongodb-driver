use v6;
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

# Run command should ony be working on the admin database using the virtual
# $cmd collection. Method is placed here because it works on a database be it a
# special one.
#
# Possible returns are:
# %("ok" => 0e0, "errmsg" => <Some error string>)
# %("ok" => 1e0, ...);
#
method run_command ( %command --> Hash ) {

    my MongoDB::Collection $c .= new(
        database    => self,
        name        => '$cmd',
    );

    return %($c.find_one(%command));
}

# Drop the database
#
method drop ( --> Hash ) {

    return self.run_command(%(dropDatabase => 1));
}

# Get the last error. Returns one or more of the following keys: ok, err, code,
# connectionId, lastOp, n, shards, singleShard, updatedExisting, upserted,
# wnote, wtimeout, waited, wtime, 
#
method get_last_error ( Bool :$j = True, Int :$w = 0, Int :$wtimeout = 1000,
                        Bool :$fsync = False
                        --> Hash
                      ) {

    my %options = :$j, :$fsync;
    if $w and $wtimeout {
        %options<w> = $w;
        %options<wtimeout> = $wtimeout;
    }
    
    return self.run_command(%( getLastError => 1, %options));
}

# Get errors since last reset error command
#
method get_prev_error ( --> Hash ) {

    return self.run_command(%( getPrevError => 1));
}

# Reset error command
#
method reset_error ( --> Hash ) {

    return self.run_command(%( resetError => 1));
}
