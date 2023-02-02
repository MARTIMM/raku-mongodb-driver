
use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;
#`{{
#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = 'Tests/issue-33.log'.IO.open(:w);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Monitor Socket SocketPool Server ServerPool>);
set-filter(|<ObserverEmitter Timer Monitor Socket SocketPool>);

info-message("Test $?FILE start");
}}
#-------------------------------------------------------------------------------
my Str $host = 'localhost';
my Str $port = '65010';

my MongoDB::Client $client .= new(:uri("mongodb://$host:$port"));
my MongoDB::Database $db = $client.database('Issue33');
my MongoDB::Collection $col = $db.collection('concurrency');

note "\n1st test; separate insert commands";
$db.run-command(BSON::Document.new((:1dropDatabase,))).raku;

my Lock $lock .= new;
my Int $n = 100;
my Num $total-i0 = 0e0;

my Instant $t0 = now;
await ^$n .map: {
  start {
    my Instant $ti0 = now;
    my BSON::Document $req .= new: (
      insert => $col.name,
      documents => [ BSON::Document.new( (
            :code('c'), :name('n'), :address('a'), :test_record('t')
          )
        ),
      ]
    );

    $lock.protect: {
      $db.run-command($req);
      my $p = (now - $ti0).Num;
      $total-i0 += $p;
#note "$_, $p, $total-i0";
    };
  }
}

my Num $t0n = (now - $t0).Num;
note "\nTotal run time 1st test: ", $t0n.fmt('%5.3f');
note "Divide by nbr of inserts ($n): ", ($t0n/$n).fmt('%5.3f');
note 'Time per insert in thread: ', ($total-i0/$n).fmt('%5.3f');
#note $db.run-command(BSON::Document.new((:count($col.name),))).raku;






note "\n\n2nd test; gather all in one array, then send to database";
$db.run-command(BSON::Document.new((:1dropDatabase,))).raku;

my Num $total-i1 = 0e0;
my Instant $t1 = now;
my Array $docs = [];

await ^$n .map: {
  start {
    my Instant $ti1 = now;
    $lock.protect: {
        $docs.push: BSON::Document.new( (
          :code('c'), :name('n'), :address('a'), :test_record('t')
        )
      );

      $total-i1 += (now - $ti1).Num; 
    };
  }
}

my Instant $t2 = now;
my BSON::Document $req .= new: (
  insert => $col.name,
  documents => $docs
);

my BSON::Document $doc = $db.run-command($req);
my Num $t2n = (now - $t2).Num; 

my Num $t1n = (now - $t1).Num; 
note "\nTotal run time 2nd test: ", $t1n.fmt('%5.3f');
note "Divide by nbr of records ($n): ", ($t1n/$n).fmt('%5.3f');
note 'Time per push in thread: ', ($total-i1/$n).fmt('%5.3f');
note "Time of single insert of $n documents: ", $t2n.fmt('%5.3f');
#note $db.run-command(BSON::Document.new((:count($col.name),))).raku;
