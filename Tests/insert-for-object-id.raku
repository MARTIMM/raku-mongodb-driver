#!/usr/bin/env perl6
#

use MongoDB;

my MongoDB::Connection $connection .= new;
my MongoDB::Database $database = $connection.database('test');
my MongoDB::Collection $collection = $database.collection('objectidtest');

my %document1 = name => 'test';
$collection.insert(%document1);

my $cursor = $collection.find;
while $cursor.fetch() -> %document
{
  say "Document:";
  say sprintf( "    %10.10s: %s", $_, %document{$_}) for %document.keys;
  say "";
}

$collection.drop;
