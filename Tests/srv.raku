
use v6.d;

use Net::DNS;

my $nameserver;
for < 8.8.8.8 8.8.4.4
      127.0.0.54
      208.67.222.222 208.67.220.220
      1.1.1.1 1.0.0.1
    > -> $host {
  note "Try $host:53";


  my $search = start {
    try my IO::Socket::INET $srv .= new( :$host, :port(53));
    $srv.close if ?$srv;
  }

  my $timeout = Promise.in(2).then({
    say 'Timeout after 2 seconds';
    $search.break;
  });

  await Promise.anyof( $timeout, $search);
  note "sts $timeout.status(), $search.status()";
  if $search.status eq 'Kept' {
    $nameserver = $host;
    last;
  }
}

note $?LINE;
# With expressvpn the google dns server can not be used to find jabber.org
# Take an ip from ss -tunl using port 53
#my Net::DNS $resolver .= new( '100.64.100.1', IO::Socket::INET);
my Net::DNS $resolver .= new( $nameserver, IO::Socket::INET);
#127.0.0.54

note $?LINE;
my @srv = $resolver.lookup( 'srv', '_xmpp-client._tcp.jabber.org');
note "$?LINE; jabber servers: @srv.join(', ')";

