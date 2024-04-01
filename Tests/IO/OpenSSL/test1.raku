use v6.d;
use Test;
use IO::Socket::SSL;

my IO::Socket::SSL $ssl .= new(:host<google.com>, :port(443));
note $ssl.print("GET / HTTP/1.1\r\nHost:www.google.com\r\nConnection:close\r\n\r\n");
note $ssl.get;
$ssl.close;
