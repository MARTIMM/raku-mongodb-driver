
use v6.d;

use Net::DNS;

note $?LINE;
# With expressvpn the google dns server can not be used to find jabber.org
# Take an ip from ss -tunl using port 53
my Net::DNS $resolver .= new( '100.64.100.1', IO::Socket::INET);
#127.0.0.54

note $?LINE;
my @srv = $resolver.lookup( 'srv', '_xmpp-client._tcp.jabber.org');
note "$?LINE; jabber servers: @srv.join(', ')";

