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
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Trace));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client = $ts.get-connection;
my MongoDB::Database $database = $client.database('test');
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;

#------------------------------------------------------------------------------
subtest 'setup database', {

  $database.run-command: (dropDatabase => 1,);

  # Insert many documents to see proper working of get-more docs request
  # using wireshark
  #
  my Array $docs = [];

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

  $doc = $database.run-command($req);

  is $doc<ok>, 1, 'insert ok';
  is $doc<n>, 200, 'inserted 200 docs';

  # Request to get all documents listed to generate a get-more request
  $cursor = $collection.find(
    :criteria(test_record => 'tr100',),
    :projection(_id => 0,)
  );

  $doc = $cursor.fetch;
  is $doc.elems, 5, '5 fields in record, _id not returned';
  is $doc<test_record>, 'tr100', 'test record 100 found';
}

#------------------------------------------------------------------------------
subtest "Find tests", {

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
}

#------------------------------------------------------------------------------
subtest "Count tests", {

  $req .= new: ( count => $collection.name);
  $doc = $database.run-command($req);
  is $doc<n>, 200, '200 records';

  $req<query> = ( code => 'd1', test_record => 'tr3');
  $doc = $database.run-command($req);
  is $doc<n>, 1, '1 record';

  $req<query> = ();
  $req<limit> = 3;
  $doc = $database.run-command($req);
  is $doc<n>, 3, '3 records with limit';

  $req<query> = ();
  $req<limit> = 3;
  $req<skip> = 198;
  $doc = $database.run-command($req);
  is $doc<n>, 2, '2 records using skip and limit';
}

#-------------------------------------------------------------------------------
subtest "Testing explain and performance using cursor", {

  # The server needs to scan through all documents to see if the query matches
  # when there is no index set.
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
  $doc = $database.run-command: (
    createIndexes => $collection.name,
    indexes => [ (
        key => (test_record => 1,),
        name => 'tf_idx',
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
}

#-------------------------------------------------------------------------------
subtest "Testing explain and performance using hint", {

  # Give a bad hint and get explaination(another possibility from above
  # explain using find in stead of run-command)
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
}

#-------------------------------------------------------------------------------
subtest "Error testing", {

  $cursor.kill;
  $doc = $database.run-command: (getLastError => 1,);
  ok $doc<ok>.Bool, 'No error after kill cursor';

  # Is this ok (No fifty because of test with explain on cursor????
  $doc = $database.run-command: (
    count => $collection.name,
    query => BSON::Document.new: (test_record => 'tr38',),
    hint => BSON::Document.new: (test_record => 1,),
  );

  is $doc<n>, 1, 'Counting 1 document on search';
}

#-------------------------------------------------------------------------------
# Cleanup and close
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
