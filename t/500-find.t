#`{{
  Testing;
    collection.find()                   Query database
      implicit AND selection            Find with more fields
      projection                        Select fields to return
    cursor.count()                      Count number of docs
    collection.explain()                Explain what is done for a search
    cursor.explain()                    Explain what is done for a search
    cursor.hint()                       Control choice of index
    cursor.kill()                       Kill a cursor
    cursor.next()                       Fetch a document
}}

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Collection $collection = get-test-collection( 'test', 'testf');

my Hash $d1 = { code           => 'd1'
              , name           => 'name and lastname'
              , address        => 'address'
              , city           => 'new york'
              };

for ^50 -> $i {
  $d1<test_record> = 'tr' ~ $i;
  $collection.insert($d1);
}

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

#------------------------------------------------------------------------------

my $cursor = $collection.find();
ok $cursor.count == 50.0, 'Counting fifty documents';

$cursor = $collection.find( %( code => 'd1', test_record => 'tr3'));
ok $cursor.count == 1.0, 'Counting one document';

$cursor = $collection.find();
ok $cursor.count(:limit(3)) == 3.0, 'Limiting count to 3 documents';

$cursor = $collection.find();
ok $cursor.count( :skip(48), :limit(3)) == 2.0, 'Skip 48 then limit 3 yields 2';

#-------------------------------------------------------------------------------
# The server needs to scan through all documents to see if the query matches
# when there is no index set.
#
my $doc = $collection.explain({test_record => 'tr38'});
is $doc<cursor>, "BasicCursor", 'No index -> basic cursor';
is $doc<n>, 1, 'One doc found';
is $doc<nscanned>, 50, 'Scanned 50 docs, bad searching';

# Do the same via a cursor
$cursor = $collection.find({test_record => 'tr38'});
$doc = $cursor.explain;
is $doc<cursor>, "BasicCursor", 'No index -> basic cursor, explain via cursor';
is $doc<n>, 1, 'One doc found, explain via cursor';
is $doc<nscanned>, 50, 'Scanned 50 docs, bad searching, explain via cursor';

# Now set an index on the field and the scan goes only through one document
#
$collection.ensure_index(%(test_record => 1));
$doc = $collection.explain({test_record => 'tr38'});
#say $doc.perl;
#say "N, scanned: ", $doc<n>, ', ', $doc<nscanned>;
ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type';
is $doc<n>, 1, 'One doc found';
is $doc<nscanned>, 1, 'Scanned 1 doc, great indexing';

# Do the same via a cursor
$cursor = $collection.find({test_record => 'tr38'});
$doc = $cursor.explain;
ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type, explain via cursor';
is $doc<n>, 1, 'One doc found, explain via cursor';
is $doc<nscanned>, 1, 'Scanned 1 doc, great indexing, explain via cursor';

#-------------------------------------------------------------------------------
$doc = $cursor.hint( %("_id" => 1), :explain);
#$doc = $cursor.explain;
#say $doc.perl;
#say "N, scanned: ", $doc<n>, ', ', $doc<nscanned>;
ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type, explain via bad hint';
is $doc<n>, 1, 'One doc found, explain via bad hint';
is $doc<nscanned>, 50, 'Scanned 50 docs, bad searching, explain via bad hint';

$doc = $cursor.hint( %(test_record => 1), :explain);
ok $doc<cursor> ~~ m/BtreeCursor/, 'Different cursor type, explain via good hint';
is $doc<n>, 1, 'One doc found, explain via a good hint';
is $doc<nscanned>, 1, 'Scanned 1 doc, great indexing, explain via good hint';

#-------------------------------------------------------------------------------
$cursor.kill;
my $error-doc = $collection.database.get_last_error;
ok $error-doc<ok>.Bool, 'No error after kill cursor';

# Is this ok (No fifty because of test with explain on cursor????
$cursor.count;
is $cursor.count, 1, 'Still counting 1 document';

#-------------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done();
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
        is( %document{$k}:exists, True, "Key '$k' exists. Check using find()/fetch()");
      }
      
      else {
        is( %document{$k}:exists, False, "Key '$k' does not exist. Check using find()/fetch()");
      }
    }
  
    last;
  }
}
