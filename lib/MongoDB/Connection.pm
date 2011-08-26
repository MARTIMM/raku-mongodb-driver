class MongoDB::Connection;

use MongoDB::DataBase;

has IO::Socket::INET $!sock;

submethod BUILD ( Str $host = 'localhost', Int $port = 27017 ) {

    $!sock = IO::Socket::INET.new( host => $host, port => $port );
}

method database ( Str $name ) {

    return MongoDB::DataBase.new(
        connection  => self,
        name        => $name,
    );
}

method send ( Buf $b, Bool $has_response ) {

    $!sock.send( $b.unpack( 'A*' ) );

    if $has_response {
        # obtain int32 response length
        my $l = $!sock.recv( 4 ).encode;
        my $r = $!sock.recv( $l.unpack( 'V' ) - 4 ).encode;
        
        # receive remaining response bytes from socket
        return Buf.new( $l.contents.list, $r.contents.list );
    }
}