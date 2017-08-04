#!/usr/bin/env perl6

use v6;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::Server;
use MongoDB::Server::Socket;

use Bench;
my Bench $b;

my MongoDB::Test-support $ts .= new;
my Int $p1 = $ts.server-control.get-port-number('s1');

my MongoDB::Client $cln;
my MongoDB::Server $srv;
my MongoDB::Server::Socket $sck;

my Str $uri = "mongodb://localhost:$p1";

#`{{
$b .= new;
$b.timethese(
  5, {
    new-select-cleanup => sub {
      $cln .= new(:uri($uri));
      $cln.select-server;
      $cln.cleanup;
    }
  }
);
}}


$b .= new;
$b.timethese(
  10, {
    new-select => sub {
      my MongoDB::Client $c .= new(:uri($uri));
      $srv = $c.select-server;
      # (20170722) Forget about cleanup... 10 temporary threads + 1 monitoring threads
      start {$c.cleanup};
    }
  }
);

#`{{
$b .= new;
$b.timethese(
  500, {
    new => sub {
      my MongoDB::Client $c .= new(:uri($uri));
    }
  }
);
}}

#`{{
# Select server once
$cln .= new(:uri($uri));
$srv = $cln.select-server;
$b .= new;
$b.timethese(
  400, {
    socket => sub {
      $sck = $srv.get-socket;
      $sck.close;
    }
  }
);
}}
