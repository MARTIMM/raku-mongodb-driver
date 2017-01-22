use v6.c;
use Test;

use lib 't';
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
my MongoDB::Test-support $ts .= new;
my Int $p1 = $ts.server-control.get-port-number('s1');
my Int $p2 = $ts.server-control.get-port-number('s2');
my MongoDB::Client $client .= new(:uri<mongodb://localhost:34567/>);
ok $client.defined, 'T0';

done-testing;
