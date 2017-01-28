#!/usr/bin/env perl6

use v6;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;

use Bench;

my MongoDB::Test-support $ts .= new;
my Int $p1 = $ts.server-control.get-port-number('s1');
my MongoDB::Client $cln .= new( :uri('mongodb://localhost' ~ ":$p1"));

my $b = Bench.new;
$b.timethese(
  50, {
    connect => sub {
      my $srv = $cln.select-server;
      my $sck = $srv.get-socket;
      $sck.close;
    }
  }
);

