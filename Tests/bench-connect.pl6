#!/usr/bin/env perl6

use v6;

use Bench;
use MongoDB::Client;

constant $port = 65000;

my $b = Bench.new;
my MongoDB::Client $cln .= instance( :uri('mongodb://localhost' ~ ":$port"));;
my MongoDB::Server $srv;
my MongoDB::Socket $sck;

$b.timethese(
  50, {
    connect => sub {
      $srv = $cln.select-server;
      $sck = $srv.get-socket;
      $sck.close;
    }
  }
);

