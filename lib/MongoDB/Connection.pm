use MongoDB::Protocol;
use MongoDB::Database;

class MongoDB::Connection does MongoDB::Protocol;

has IO::Socket::INET $!sock;

submethod BUILD ( Str :$host = 'localhost', Int :$port = 27017 ) {

    $!sock = IO::Socket::INET.new( host => $host, port => $port );
#    $!sock = IO::Socket::INET.new( host => "$host/?connectTimeoutMS=3000", port => $port );
}

method database ( Str $name --> MongoDB::Database ) {

    return MongoDB::Database.new(
        connection  => self,
        name        => $name,
    );
}

# List databases using MongoDB db.runCommand({listDatabases: 1});
#
method list_databases ( --> Array ) {

    my $database = self.database('admin');
    my %docs = %($database.run_command(%(listDatabases => 1)));
    return @(%docs<databases>);
}

# Get database names.
#
method database_names ( --> Array ) {

    my @db_docs = self.list_databases();
    my @names = map {$_<name>}, @db_docs; # Need to do it like this otherwise
                                          # returns List instead of Array.
    return @names;
}

method send ( Buf $b, Bool $has_response --> Any ) {

    $!sock.write( $b );

    # some calls do not expect response
    return unless $has_response;

    # check response size
    my Buf $l = $!sock.read( 4 );
    my Int $w = self.wire._int32( $l.list ) - 4;

    # receive remaining response bytes from socket
    return $l ~ $!sock.read( $w );
}
