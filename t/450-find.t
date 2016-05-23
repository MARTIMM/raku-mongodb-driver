use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Cursor;
use BSON::ObjectId;
use BSON::Document;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client = $ts.get-connection();
my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;

$database.run-command: (dropDatabase => 1,);

# Insert many documents to see proper working of get-more docs request
# using wireshark
#
my Array $docs = [];
#my $t0 = now;
for ^200 -> $i {
  $docs.push: (
    code                => 'd1',
    name                => 'name and lastname',
    address             => 'address',
    city                => 'new york',
    test_record         => "tr$i"
  );
}

$req .= new: (
  insert => $collection.name,
  documents => $docs
);

#say "Time create request: ", now - $t0;

$doc = $database.run-command($req);

#say "Time insert in database: ", now - $t0;

is $doc<ok>, 1, 'insert ok';
is $doc<n>, 200, 'inserted 200 docs';
#say $doc<errmsg> unless $doc<ok>;

# Request to get all documents listed to generate a get-more request
#
$cursor = $collection.find(:projection(_id => 0,));

#say "Time to get cursor with some docs: ", now - $t0;

while $cursor.fetch -> BSON::Document $document {
#  say $document.perl;
}

#say "Time after reading all docs: ", now - $t0;

#------------------------------------------------------------------------------
subtest {
  check-document(
    ( code => 'd1', test_record => 'tr3'),
    ( _id => 1, code => 1, name => 1, 'some-name' => 0)
  );

  check-document(
    ( code => 'd1', test_record => 'tr4'),
    ( _id => 1, code => 1, name => 0, address => 0, city => 0),
    ( code => 1,)
  );

  check-document(
    ( code => 'd1', test_record => 'tr5'),
    ( _id => 0, code => 0, name => 1, address => 1, city => 1),
    ( _id => 0, code => 0)
  );
}, "Find tests";

#------------------------------------------------------------------------------
subtest {
  $req .= new: ( count => $collection.name);
#  $cursor = $collection.find();
#  ok $cursor.count == 50.0, 'Counting fifty documents';
#  $req<query> = ();
  $doc = $database.run-command($req);
  is $doc<n>, 200, '200 records';

#  $cursor = $collection.find( %( code => 'd1', test_record => 'tr3'));
#  ok $cursor.count == 1.0, 'Counting one document';
  $req<query> = ( code => 'd1', test_record => 'tr3');
  $doc = $database.run-command($req);
  is $doc<n>, 1, '1 record';

#  $cursor = $collection.find();
#  ok $cursor.count(:limit(3)) == 3.0, 'Limiting count to 3 documents';
  $req<query> = ();
  $req<limit> = 3;
  $doc = $database.run-command($req);
  is $doc<n>, 3, '3 records with limit';

#  $cursor = $collection.find();
#  ok $cursor.count( :skip(48), :limit(3)) == 2.0, 'Skip 48 then limit 3 yields 2';
  $req<query> = ();
  $req<limit> = 3;
  $req<skip> = 198;
  $doc = $database.run-command($req);
  is $doc<n>, 2, '2 records using skip and limit';
}, "Count tests";

#-------------------------------------------------------------------------------
subtest {
  # The server needs to scan through all documents to see if the query matches
  # when there is no index set.
  #
  $req .= new: (
    explain => (
      find => 'testf',
      filter => (test_record => 'tr38'),
      options => ()
    ),
    verbosity => 'executionStats'
  );
  $doc = $database.run-command($req);
  my $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found';
  is $s<totalDocsExamined>, 200, 'Scanned 200 docs, bad searching';

  # Now set an index on the field and the scan goes only through one document
  #
#  my MongoDB::Database $db-system .= new(:name<system>);
  $doc = $database.run-command: (
    createIndexes => $collection.name,
    indexes => [ (
        key => (test_record => 1,),
        name => 'tf_idx',
#        ns => 'test.testf',
      ),
    ]
  );
  is $doc<createdCollectionAutomatically>, False, 'Not created automatically';
  is $doc<numIndexesBefore>, 1, 'Only 1 index before call';
  is $doc<numIndexesAfter>, 2, 'Now there are 2';

  $doc = $database.run-command($req);
  $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found';
  is $s<totalDocsExamined>, 1, 'Scanned 1 doc, great searching';
}, "Testing explain and performance using cursor";

#-------------------------------------------------------------------------------
subtest {

  # Give a bad hint and get explaination(another possibility from above
  # explain using find in stead of run-command)
  #
  $cursor = $collection.find(
    :criteria(
      '$query' => (test_record => 'tr38',),
      '$hint' => (_id => 1,),
      '$explain' => 1
    ),
    :number-to-return(1)
  );

  $doc = $cursor.fetch;
  my $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found, explain via bad hint';
  is $s<totalDocsExamined>, 200, 'Scanned 200 docs, bad searching, explain via bad hint';

  # Give a good hint and get explaination(another possibility from above
  # explain using find in stead of run-command)
  #
  $cursor = $collection.find(
    :criteria(
      '$query' => (test_record => 'tr38',),
      '$hint' => (test_record => 1,),
      '$explain' => 1
    ),
    :number-to-return(1)
  );
  $doc = $cursor.fetch;
  $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found, explain via a good hint';
  is $s<totalDocsExamined>, 1, 'Scanned 1 doc, great indexing, explain via good hint';
}, "Testing explain and performance using hint";






info-message("Test $?FILE stop");
done-testing();
exit(0);





#-------------------------------------------------------------------------------
subtest {
  $cursor.kill;
  my $error-doc = $collection.database.get-last-error;
  ok $error-doc<ok>.Bool, 'No error after kill cursor';

  # Is this ok (No fifty because of test with explain on cursor????
  $cursor.count;
  is $cursor.count, 1, 'Still counting 1 document';
}, "Error testing";

#-------------------------------------------------------------------------------
subtest {
  my Hash $d2;
  try {
    $d2 = { '$abc' => 'pqr'};
    $collection.insert($d2);
    CATCH {
      when MongoDB::Message {
        ok $_.message ~~ m:s/is not properly defined/, "Key '\$abc' not properly defined";
      }
    }
  }

  try {
    $d2 = { 'abc.def' => 'pqr'};
    $collection.insert($d2);
    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/is not properly defined/, "Key 'abc.def' not properly defined";
      }
    }
  }

  try {
    $d2 = { x => {'abc.def' => 'pqr'}};
    $collection.insert($d2);
    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/is not properly defined/, "Key 'abc.def' not properly defined";
      }
    }
  }

  try {
    $d2 = { _id => BSON::ObjectId.encode('123456789012123456789012'),
            x => 'y',
            a => 'c'
          };
    $collection.insert($d2);
    $d2 = { _id => BSON::ObjectId.encode('123456789012123456789012'),
            b => 'c'
          };
    $collection.insert($d2);
    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/not unique/, .error-text;
      }
    }
  }
}, 'Faulty insert tests';

#-------------------------------------------------------------------------------
# Cleanup and close
#
#$collection.database.drop;

info-message("Test $?FILE stop");
done-testing();
exit(0);

#-------------------------------------------------------------------------------
# Check one document for its fields. Something like {code => 1, nofield => 0}
# use find()
#
sub check-document ( $criteria, $field-list, $projection = ())
{
#  $cursor = $collection.find( :$criteria, :$projection);
#  while $cursor.fetch() -> BSON::Document $document {

  for $collection.find( :$criteria, :$projection) -> BSON::Document $document {
    for @$field-list -> $pair {
      if $pair.value == 1 {
        is( $document{$pair.key}:exists, True, "Key '{$pair.key}' exists");
      }

      else {
        is( $document{$pair.key}:exists,
            False, "Key '{$pair.key}' does not exist"
        );
      }
    }

    last;
  }
}
