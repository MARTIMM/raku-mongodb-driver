#!/usr/bin/env perl6

use v6.c;

use BSON::Document;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);

my MongoDB::Client $client .= new(:uri<mongodb://:65000>);
my MongoDB::Database $database = $client.database('test');
my MongoDB::Collection $collection = $database.collection('mycll');

sleep 3;
my BSON::Document $doc = $database.run-command( (
    insert => $collection.name,
    documents => [
      BSON::Document.new((a => 1876, b => 2),),
    ]
  )
);

say "\n", $doc.perl;

