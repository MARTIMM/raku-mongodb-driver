#!/usr/bin/env perl6

use v6;

use lib 't';
use Test-support;

use MongoDB;
use MongoDB::Client;
use BSON::Document;

use Bench;

my MongoDB::Test-support $ts .= new;
my Int $p1 = $ts.server-control.get-port-number('s1');
my MongoDB::Client $cln .= new( :uri('mongodb://localhost' ~ ":$p1"));

my $db = $cln.database('test');
my $cl = $db.collection('bench1');

# drop data first
$db.run-command: (drop => $cl.name,);

# insert a few records
for ^10 -> $i {
  my BSON::Document $req .= new: (
    insert => $cl.name,
    documents => [
      BSON::Document.new( (
          field1 => "test $i",
          field2 => 'test xyz',
        )
      ),
    ]
  );

  my BSON::Document $doc = $db.run-command($req);
  die "insert failed [$i]" unless $doc<ok> == 1;
}



my $b = Bench.new;
$b.cmpthese(
  100, {
    find => sub { my $c = $cl.find(); },

    count => sub {
      my BSON::Document $doc = $db.run-command: (
        count => $cl.name,
        query => BSON::Document.new()
      );
    }
  }
);

