#!/usr/bin/env perl6

use v6.c;
use lib 't';

use Test;
use Test-support;
use BSON::Document;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Config;

# Run test 610 first to start server as replicaset server

set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);

my Hash $config = MongoDB::Config.instance.config;
my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
my MongoDB::Client $client .= new(:uri("mongodb://:65001/?replicaSet=$rs1-s2"));
my MongoDB::Database $database = $client.database('test');
my MongoDB::Collection $collection = $database.collection('mycll');

sleep 3;
my BSON::Document $doc = $database.run-command( (
    insert => $collection.name,
    documents => [
      (a => 1876, b => 2, c => 20),
      (:p<data1>, :q(20), :2r, :s),
    ]
  )
);

if $doc.defined {
  info-message($doc.perl);
}

else {
  warn-message('Doc not defined');
}


my $server = $client.select-server: :needed-state(MongoDB::C-REPLICA-PRE-INIT);
$doc = $database.run-command( (
    insert => $collection.name,
    documents => [
      (a => 1876, b => 2, c => 20),
      (:p<data1>, :q(20), :2r, :s),
    ]
  ),
  :$server
);

if $doc.defined {
  info-message($doc.perl);
}

else {
  warn-message('Doc not defined');
}
