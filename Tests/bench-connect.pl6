#!/usr/bin/env perl6

use v6;

my $time;

#BEGIN { $time = time; say "BEGIN Time: {time - $time}"; }
BEGIN { $time = time; }
INIT { say "INIT Time: {time - $time}"; }
END { say "END Time: {time - $time}"; }

say "RUN 1 Time: {time - $time}";

use MongoDB::Connection;
use Bench;

say "RUN 2 Time: {time - $time}";

constant $port = 65000;

my $b = Bench.new;
my MongoDB::Connection $c;

$b.timethese(
  50, {
    connect => sub { $c .= new( :host<localhost>, :$port);}
  }
);

say "RUN 3 Time: {time - $time}";

