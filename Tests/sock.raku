#!/usr/bin/env perl6

use v6.c;
my IO::Socket::INET $sock;

#$sock .= new( :host<192.168.0.2>, :port(65010));
#$sock .= new( :host<127.0.0.1>, :port(65010));
$sock .= new( :host<localhost>, :port<65010>);
#$sock .= new( :host<::1>, :port<65010>);
#$sock .= new( :host<localhost6>, :port<65010>);
#$sock .= new( :host<localhost:65010>);
#$sock .= new( :host<localhost.localdomain>, :port(65010));
say $sock.perl;
