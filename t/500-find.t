use v6;
use lib 't'; #, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
use Test-support;
use Test;
use MongoDB::Connection;
use MongoDB::Cursor;
use BSON::ObjectId;

#`{{
  Testing;
    collection.find()                   Query database
      implicit AND selection            Find with more fields
      projection                        Select fields to return
    collection.find() with pairs ipv hash
    cursor.count()                      Count number of docs
    collection.explain()                Explain what is done for a search
    cursor.explain()                    Explain what is done for a search
    cursor.hint()                       Control choice of index
    cursor.kill()                       Kill a cursor
    cursor.next()                       Fetch a document
}}

my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database .= new(:name<test>);
my MongoDB::Database $db-admin .= new(:name<admin>);
my MongoDB::Collection $collection = $database.collection('testf');
my BSON::Document $req;
my BSON::Document $doc;

$database.run-command: (dropDatabase => 1);

$req .= new: (
  insert => $collection.name,
  documents => []
);

#say "RP: ", $req.perl;
#exit(0);

# Insert many documents to see proper working of get-more docs request
# using wireshark
#
my Array $docs = [];
my $t0 = now;
for ^200 -> $i {
  $docs.push: (
    code                => 'd1',
    name                => 'name and lastname',
    address             => 'address',
    city                => 'new york',
    test_record         => "tr$i"
  );
}

say "RTT modify array: ", now - $t0;

$req .= new: (
  insert => $collection.name,
  documents => $docs
);

#say "RP:\n", $req.perl;

$doc = $database.run-command($req);
is $doc<ok>, 1, 'insert ok';
is $doc<n>, 200, 'inserted 200 docs';
say $doc<errmsg> unless $doc<ok>;

# Request to get all documents listed to generate a get-more request
#
my MongoDB::Cursor $cursor = $collection.find(:projection(_id => 0,));
while $cursor.fetch -> BSON::Document $document {
#  say $document.perl;
}

done-testing();
exit(0);
=finish

#------------------------------------------------------------------------------
subtest {
  check-document( %( code => 'd1', test_record => 'tr3')
                , %( _id => 1, code => 1, name => 1, 'some-name' => 0)
                );

  check-document( %( code => 'd1', test_record => 'tr4')
                , %( _id => 1, code => 1, name => 0, address => 0, city => 0)
                , %( code => 1)
                );

  check-document( %( code => 'd1', test_record => 'tr5')
                , %( _id => 0, code => 0, name => 1, address => 1, city => 1)
                , %( _id => 0, code => 0)
                );
}, "Find tests";

#------------------------------------------------------------------------------
my Hash $doc;
my $cursor;

subtest {
  $cursor = $collection.find();
  ok $cursor.count == 50.0, 'Counting fifty documents';

  $cursor = $collection.find( %( code => 'd1', test_record => 'tr3'));
  ok $cursor.count == 1.0, 'Counting one document';

  $cursor = $collection.find();
  ok $cursor.count(:limit(3)) == 3.0, 'Limiting count to 3 documents';

  $cursor = $collection.find();
  ok $cursor.count( :skip(48), :limit(3)) == 2.0, 'Skip 48 then limit 3 yields 2';
}, "Count tests";

#-------------------------------------------------------------------------------
subtest {
  # Testing find() using Pairs instead of hash.
  #
  my Pair @f = code => 'd1', test_record => 'tr3';
  $cursor = $collection.find( @f, %( _id => 0, code => 1));
  #$cursor = $collection.find( @f);
  is $cursor.count, 1, 'Counting one document';
  $doc = $cursor.next;
  #show-document($doc);
  ok $doc<code>:exists, 'code field returned';
  ok $doc<_id>:!exists, 'id field not returned';
  ok $doc<name>:!exists, 'name field not returned';
}, 'Testing with pairs';

#-------------------------------------------------------------------------------
subtest {
  # The server needs to scan through all documents to see if the query matches
  # when there is no index set.
  #
  $doc = $collection.explain({test_record => 'tr38'});
  my $s = $doc<executionStats>;
#  is $doc<cursor>, "BasicCursor", 'No index -> basic cursor';
  is $s<nReturned>, 1, 'One doc found';
  is $s<totalDocsExamined>, 50, 'Scanned 50 docs, bad searching';

  # Do the same via a cursor
  $cursor = $collection.find({test_record => 'tr38'});
  $doc = $cursor.explain;
  $s = $doc<executionStats>;
#  is $doc<cursor>, "BasicCursor", 'No index -> basic cursor, explain via cursor';
  is $s<nReturned>, 1, 'One doc found, explain via cursor';
  is $s<totalDocsExamined>, 50, 'Scanned 50 docs, bad searching, explain via cursor';

  # Now set an index on the field and the scan goes only through one document
  #
  $collection.ensure-index(%(test_record => 1));
  $doc = $collection.explain({test_record => 'tr38'});
#  ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type';
  $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found';
  is $s<totalDocsExamined>, 1, 'Scanned 1 doc, great indexing';

  # Do the same via a cursor
  $cursor = $collection.find({test_record => 'tr38'});
  $doc = $cursor.explain;
#  ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type, explain via cursor';
  $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found, explain via cursor';
  is $s<totalDocsExamined>, 1, 'Scanned 1 doc, great indexing, explain via cursor';
}, "Testing explain and performance using cursor";

#-------------------------------------------------------------------------------
subtest {
  $doc = $cursor.hint( %("_id" => 1), :explain);
  #$doc = $cursor.explain;
  #say $doc.perl;
  #say "N, scanned: ", $doc<n>, ', ', $doc<nscanned>;
#  ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type, explain via bad hint';
  my $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found, explain via bad hint';
  is $s<totalDocsExamined>, 50, 'Scanned 50 docs, bad searching, explain via bad hint';

  $doc = $cursor.hint( %(test_record => 1), :explain);
#  ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type, explain via good hint';
  $s = $doc<executionStats>;
  is $s<nReturned>, 1, 'One doc found, explain via a good hint';
  is $s<totalDocsExamined>, 1, 'Scanned 1 doc, great indexing, explain via good hint';
}, "Testing explain and performance using hint";

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
      when X::MongoDB {
        ok $_.message ~~ m:s/is not properly defined/, "Key '\$abc' not properly defined";
      }
    }
  }

  try {
    $d2 = { 'abc.def' => 'pqr'};
    $collection.insert($d2);
    CATCH {
      when X::MongoDB {
        ok .message ~~ m:s/is not properly defined/, "Key 'abc.def' not properly defined";
      }
    }
  }

  try {
    $d2 = { x => {'abc.def' => 'pqr'}};
    $collection.insert($d2);
    CATCH {
      when X::MongoDB {
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
      when X::MongoDB {
        ok .message ~~ m:s/not unique/, .error-text;
      }
    }
  }
}, 'Faulty insert tests';

#-------------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done-testing();
exit(0);

#-------------------------------------------------------------------------------
# Check one document for its fields. Something like {code => 1, nofield => 0}
# use find()
#
sub check-document ( $criteria, %field-list, %projection = { })
{
  my $cursor = $collection.find( $criteria, %projection);
  while $cursor.next() -> %document {
    for %field-list.keys -> $k {
      if %field-list{$k} {
        is( %document{$k}:exists, True, "Key '$k' exists");
      }

      else {
        is( %document{$k}:exists, False, "Key '$k' does not exist");
      }
    }

    last;
  }
}
