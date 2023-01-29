#!/usr/bin/env rakudo

#`{{
  Program to investigate issue 33:
    Advice / Idea on how to Improve Insert / Update performance

  Beside this, there was also a question of lock up of threads in the method used. Program is copied and details added.
}}

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

# Native MongoDB driver
my MongoDB::Client $client .= new(:uri("mongodb://:65010"));
my MongoDB::Database $db = $client.database('Test');
my MongoDB::Collection $col = $db.collection('test');

my BSON::Document $req;

my $mongoq = Channel.new;
my $k;

my $mongoc = {
  react {
    whenever $mongoq {
      say $_;
      $k++;
      mongoStore($_);
    }
  }
};


my @mongop;
do { @mongop.push: Promise.start($mongoc) for 1..1 };


#-------------------------------------------------------------------------------
sub mongoStore (Hash $h) {
  my $sub=callframe.code.name;
  my $host=$h<host>;
  my $port=$h<port>;
  my $start=DateTime.now;
  my ($countperf,$packperf,$insertperf);
  my $doc;

  $req .= new: (count => $col.name, query => ( :$host, :$port),);
  try {
    $doc=$db.run-command($req);
    $countperf=DateTime.now - $start;
    if ($doc<n> eq 0) {
      $h<ctime>=DateTime.now;
    }
    else {
      $h<mtime>=DateTime.now;
    }
    CATCH {
      default {
        say "$sub count exception: ",.^name, '→ ', .Str , " host: $h<host> port: $h<port>";
      }
    }
  }
my $hr= {
    :host($h<host>),
    :port($h<port>),
  };
$hr<ip>=$h<ip> if $h<ip>;
my $uq=(
    q => (:$host, :$port,),
    u => ('$set' => @($hr)),
    upsert => True,
  );
  # say $uq;
  $req .= new: (update => $col.name, updates => [$uq]);
  try {
    $db.run-command($req);
    CATCH {
      default {
        say "$sub update exception: ",.^name, '→ ', .Str , " ip: $h<ip> port: $h<port>";
      }
    }
  }
  $insertperf=DateTime.now - $start;
