use MongoDB::Protocol;
use MongoDB::DataBase;

class MongoDB::Connection does MongoDB::Protocol;

has IO::Socket::INET $!sock;

submethod BUILD ( Str :$host = 'localhost', Int :$port = 27017 ) {

    $!sock = IO::Socket::INET.new( host => $host, port => $port );
}

method database ( Str $name ) {

    return MongoDB::DataBase.new(
        connection  => self,
        name        => $name,
    );
}

method send ( Buf $b, Bool $has_response ) {

    $!sock.send( [~]$b.list>>.chr );

    # some calls do not expect response
    return unless $has_response;

    # check response size
    my $l = $!sock.read( 4 );
    my $w = self.wire._int32( $l.list ) - 4;

    # receive remaining response bytes from socket
    return $l ~ $!sock.read( $w );
}