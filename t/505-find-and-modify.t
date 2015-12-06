#`{{
  Testing;
    collection.find-and-modify()        Find and modify a record in the database
      sort                              Update first of same records dep on sort
      remove                            Remove found record
      update                            Update found record
      new                               Return modified record instead of original
      upsert                            with update, insert new if not found
      projection                        Select fields to return
}}

use lib 't';
use Test-support;

use v6;
use Test;
use MongoDB::Collection;
use BSON::Regex;

my MongoDB::Collection $collection = get-test-collection( 'test', 'testf');
$collection.database.drop;

my @places = <amsterdam NY LA haarlem utrecht parijs oradour poitiers vienna>;
my %d1 = code => 'd1 ';

for (^5, (5...1)).flat -> $code-postfix {
  %d1<code> ~= $code-postfix;
  %d1<city> = @places.roll;
  $collection.insert(%d1);
#say "insert using $code-postfix";
}

#show-documents( $collection, {}, { _id => 0, code => 1, city => 1});

# Check a doc
#
my MongoDB::Cursor $cursor = $collection.find({code => 'd1 012'});
is $cursor.count, 1, 'One of d1 012';

# Modify one record
#
my $doc = $collection.find-and-modify(
  {code => 'd1 0123'}, 
  update => { '$set' => {code => 'd1 012'}}
);
#show-document($doc);
is $doc<code>, 'd1 0123', 'Returned original doc, code = d1 0123';

$cursor = $collection.find({code => 'd1 0123'});
is $cursor.count, 0, 'Record d1 0123 gone (after update)';
$cursor = $collection.find({code => 'd1 012'});
is $cursor.count, 2, 'Two records of d1 012 (after update)';

# Find with new option
#
$doc = $collection.find-and-modify(
  {code => 'd1 01234543'}, 
  update => { '$set' => {code => 'd1 012'}},
  :new
);
#show-document($doc);
is $doc<code>, 'd1 012', 'Returned modified doc, code = d1 012';

$cursor = $collection.find({code => 'd1 01234543'});
is $cursor.count, 0, 'Record d1 01234543 gone (after update)';
$cursor = $collection.find({code => 'd1 012'});
is $cursor.count, 3, '3 records of d1 012 (after update)';


# Remove one record
#
$doc = $collection.find-and-modify( {code => 'd1 01234'}, :remove);
$cursor = $collection.find({code => 'd1 01234'});
is $cursor.count, 0, 'Record d1 01234 gone (after remove)';

# Remove one record. Use remove and return new throws an error
#
try {
  $doc = $collection.find-and-modify(
    {code => BSON::Regex.new(:regex('^d1 .*454.*'))},
    :remove, :sort({code => -1}), :new
  );

  CATCH {
    when X::MongoDB {
      ok .error-text ~~ m:s/ 'remove' 'and' 'returnNew' "can't" "co-exist" /,
         .error-text;
    }
  }
}

$doc = $collection.find-and-modify(
  {code => BSON::Regex.new(:regex('^d1 .*454.*'))},
  :remove, :sort({code => -1})
);
is $doc<code>, 'd1 0123454321', 'Returned removed doc, code = d1 0123454321';
$cursor = $collection.find({code => 'd1 0123454321'});
is $cursor.count, 0, 'Record d1 01 23454321 gone (after remove and sort)';


#------------------------------------------------------------------------------
# Cleanup and close
#
#$collection.database.drop;

done-testing();
exit(0);

