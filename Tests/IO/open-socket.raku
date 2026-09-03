#!/usr/bin/env perl6

use v6;

my IO::Socket::INET $sock;
$sock .= new( :host('localhost'), :port(65010));
$sock.close;
note $sock.raku;

$sock .= new( :host('localhost'), :port(65333));
$sock.close;
