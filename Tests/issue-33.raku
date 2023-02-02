#!/usr/bin/env rakudo

#`{{
  Program to investigate issue 33:
    Advice / Idea on how to Improve Insert / Update performance

  Beside this, there was also a question of lock up of threads in the method used. Program is copied and details added.

  The program runs now but is not showing much.
  Look into 'issue-33-benchmark.raku to have more insight in time and technique
}}

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = 'Tests/issue-33.log'.IO.open(:w);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Monitor Socket SocketPool Server ServerPool>);
set-filter(|<ObserverEmitter Timer Monitor Socket SocketPool>);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my Str $host = 'localhost';
my Str $port = '65010';

my MongoDB::Client $client .= new(:uri("mongodb://$host:$port"));
my MongoDB::Database $db = $client.database('Issue33');
my MongoDB::Collection $col = $db.collection('concurrency');

my Lock $lock .= new;

my $mongoq = Channel.new;
my $mongoc = {
  react {
    whenever $mongoq -> Hash $h {
#note "$?LINE, $*THREAD.id()";
      $lock.protect: {
        mongoStore($h);

        insert( $h, [ BSON::Document.new( (
                :code($h<code>), :name($h<name>), :address($h<address>),
                :test_record($h<test_record>)
              )
            )
          ]
        )
      } # protect
    } # whenever
  }
};

my @mongop;
do { @mongop.push: Promise.start($mongoc) for ^5; };

for ^20 -> $i {
  $mongoq.send: %(
    code                => "n$i",
    name                => "name $i and lastname $i",
    address             => "address $i",
    test_record         => "tr$i",

    :$host, :$port#, :$client  #, :$db, :$col
  );
}

$mongoq.close;
await Promise.allof(@mongop);

say '';
say now - INIT now;

#-------------------------------------------------------------------------------
sub insert ( Hash $h, Array $docs ) {

  my $host=$h<host>;
  my $port=$h<port>;

  my BSON::Document $req .= new: (
    insert => $col.name,
    documents => $docs
  );

  my BSON::Document $doc = $db.run-command($req);
}

#-------------------------------------------------------------------------------
sub mongoStore (Hash $h) {

  my $sub=callframe.code.name;
  my $host=$h<host>;
  my $port=$h<port>;
  my BSON::Document ( $req, $doc);

  $req .= new: ( count => $col.name, query => ( :$host, :$port),);
  $doc = $db.run-command($req);
#note $doc.raku;

  if ($doc<n> eq 0) {
    $h<ctime>=DateTime.now;
  }

  else {
    $h<mtime>=DateTime.now;
  }

  my $hr = {
    :host($h<host>),
    :port($h<port>),
  };

  $hr<ip>=$h<ip> if $h<ip>;

  my $uq=(
    q => (:$host, :$port,),
    u => ('$set' => @($hr)),
    upsert => True,
  );
  
  $req .= new: (update => $col.name, updates => [$uq]);
  $db.run-command($req);


  CATCH {
    default {
      say "$sub update exception: ",.^name, '→ ', .Str , " ip: $h<ip> port: $h<port>";
    }
  }
}