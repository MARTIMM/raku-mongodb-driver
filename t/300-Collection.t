use lib 't';#, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
use Test-support;
use v6;
use Test;
use MongoDB::Database;
use MongoDB::Client;

#`{{
  Testing;
    database.collection()               Create collection
    database.create-collection()        Create collection explicitly
    collection.drop()                   Drop collection

    X::MongoDB                          Catch exceptions
}}

my MongoDB::Client $connection = get-connection();
my MongoDB::Database $database .= new(:name<test>);

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');
isa-ok( $collection, 'MongoDB::Collection');

my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Cursor $cursor;

$database.run-command: (drop => $collection.name);

#-------------------------------------------------------------------------------
subtest {

  # Add records
  #
  $req .= new: (
    insert => $collection.name,
    documents => [
      ( name => 'Jan Klaassen'),        ( name => 'Piet B'),
      ( name => 'Me T'),                ( :name('Di D'))
    ]
  );

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 4, "Inserted 4 documents";

#  $cursor = $collection.find: :criteria(name => 'Me T',);
#  is $cursor.count, 1, '1 record of "Me T"';
  $req .= new: ( count => $collection.name, query => (name => 'Me T',));
  $doc = $database.run-command($req);
  is $doc<ok>, 1, "count request ok";
  is $doc<n>, 1, 'count 1 record of "Me T"';

#  $cursor = $collection.find: :criteria(name => 'Di D',);
#  is $cursor.count, 1, '1 record of "Di D"';
  $req<query> = (name => 'Di D',);
  $doc = $database.run-command($req);
  is $doc<n>, 1, 'count 1 record of "Di D"';

#  $cursor = $collection.find: :criteria(name => 'Jan Klaassen',);
#  is $cursor.count, 1, '1 record of "Jan Klaassen"';
  $req<query> = (name => 'Di D',);
  $doc = $database.run-command($req);
  is $doc<n>, 1, '1 record of "Jan Klaassen"';

  # Add next few records
  #
  $req .= new: (
    insert => $collection.name,
    documents => [
      (:name('n1'), :test(0)),  (:name('n2'), :test(0)),
      (:name('n3'), :test(0)),  (:name('n4'), :test(0)),
      (:name('n5'), :test(0)),  (:name('n6'), :test(0))
    ]
  );

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 6, "Inserted 6 documents";

  $cursor = $collection.find: :criteria(:test(0),);
#  is $cursor.count, 6, '6 records of Test(0)';
  $req<query> = (name => 'Di D',);
  $doc = $database.run-command($req);
  is $doc<n>, 6, '6 records of Test(0)';

#show-documents( $collection, {:test(0)}, {:_id(0)});

}, "Several inserts";

#-------------------------------------------------------------------------------
# Drop current collection twice
#
$req .= new: (drop => $collection.name);
$doc = $database.run-command($req);

ok $doc<ok>.Bool == True, 'Dropping cl1 ok';
is $doc<ns>, 'test.cl1', 'Dropped collection';
is $doc<nIndexesWas>, 1, 'Number of dropped indexes';

# Do it a second time
#
try {
  $doc = $database.run-command($req);
  CATCH {
    when X::MongoDB {
      ok $_.message ~~ m/ns \s+ not \s* found/, 'Collection cl1 not found';
    }
  }
}

done-testing();
exit(0);
=finish

#-------------------------------------------------------------------------------
# Create using illegal collection name
#
try {
  $database.create-collection('abc-def and a space');
  CATCH {
    when X::MongoDB {
      ok $_.message ~~ m/Illegal \s* collection \s* name/, 'Illegal collection name';
    }
  }
}

#-------------------------------------------------------------------------------
# Drop collection and create one explicitly with some parameters
#
#$collection.drop;
$database.create-collection( 'cl1', :capped, :size(1000));

# Fill collection with 100 records. Should be too much.
#
for ^200 -> $i, $j {
  my %d = %( code1 => 'd' ~ $i, code2 => 'n' ~ (100 - $j));
  $collection.insert(%d);
}

# Find all documents
#
my MongoDB::Cursor $cursor = $collection.find();
isnt $cursor.count, 100, 'Less than 100 records in collection';

#-------------------------------------------------------------------------------
# Drop collection and create one explicitly with other parameters
#
$collection.drop;
$database.create-collection( 'cl1', :capped, :size(1000), :max(10));

# Fill collection with 100 records. Should be too much.
#
for ^200 -> $i, $j {
  my %d = %( code1 => 'd' ~ $i, code2 => 'n' ~ (100 - $j));
  $collection.insert(%d);
}

# Find all documents
#
$cursor = $collection.find();
is $cursor.count, 10, 'Only 10 records in collection';

#-------------------------------------------------------------------------------
# Cleanup
#
$req .= new: ( dropDatabase => 1 );
$doc = $database.run-command($req);

done-testing();
exit(0);
