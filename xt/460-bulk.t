use v6.c;
use lib 't';

use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Cursor;
use BSON::ObjectId;


#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Client $client = get-connection();
my MongoDB::Database $database = $client.database('test');

my MongoDB::Collection $collection = $database.collection('bulk');
my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;

#$database.run-command: (dropDatabase => 1);

#-------------------------------------------------------------------------------
my $nbr-docs = $database.run-command( (
    count => $collection.name,
  ),
)<n>;

say "N Docs = $nbr-docs";

if $nbr-docs < 6000 {
  for ^1000 -> $count {

    $doc = $database.run-command: (
      insert => $collection.name,
      documents => [ (
          BSON::Document.new((
            a => $nbr-docs + $count,
            b => $nbr-docs + $count + 2
          ))
        ),
      ]
    );

    ok $doc<ok>, "Doc {$nbr-docs + $count} inserted" unless $count % 200;
  }
}

$cursor = $collection.find(:number-to-return(100));
my $count = 0;
while $cursor.fetch -> $doc {
  is $doc<a>, $count, "Doc $doc<a>, $doc<b> found" unless $count % 200;
  $count++
}

#-------------------------------------------------------------------------------
# Cleanup and close
#
#$collection.database.drop;

info-message("Test $?FILE stop");
done-testing();
exit(0);
