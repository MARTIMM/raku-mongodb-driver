#`{{
  Testing;
    database.collection()               Create collection
    database.create-collection()        Create collection explicitly
    collection.drop()                   Drop collection

    X::MongoDB                          Catch exceptions
}}

use lib 't';
use Test-support;

use v6;
use Test;
use MongoDB::Connection;

my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database = $connection.database('test');

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');
isa-ok( $collection, 'MongoDB::Collection');

#-------------------------------------------------------------------------------
subtest {
  $collection.insert( $%( name => 'Jan Klaassen'));
  $collection.insert( { name => 'Piet B'},{ name => 'Me T'});
  $collection.insert( %( :name('Di D')));

  my MongoDB::Cursor $cursor = $collection.find({name => 'Me T'});
  is $cursor.count, 1, '1 record of "Me T"';

  $cursor = $collection.find({name => 'Di D'});
  is $cursor.count, 1, '1 record of "Di D"';

  $cursor = $collection.find({name => 'Jan Klaassen'});
  is $cursor.count, 1, '1 record of "Jan Klaassen"';

  my %r1 = :name('n1'), :test(0);
  my Hash $r2 = {:name('n2'), :test(0)};
  my @r3 = ( %(:name('n3'), :test(0)), %(:name('n4'), :test(0)));
  my Array $r4 = [ %(:name('n5'), :test(0)), %(:name('n6'), :test(0))];
  $collection.insert( %r1, $r2, |@r3, |$r4);

  $cursor = $collection.find({:test(0)});
  is $cursor.count, 6, '6 records of Test(0)';

#show-documents( $collection, {:test(0)}, {:_id(0)});

}, "Several inserts";

#-------------------------------------------------------------------------------
# Drop current collection twice
#
my $doc = $collection.drop;
ok $doc<ok>.Bool == True, 'Dropping cl1 ok';
is $doc<ns>, 'test.cl1', 'Dropped collection';
is $doc<nIndexesWas>, 1, 'Number of dropped indexes';

try {
  $doc = $collection.drop;
  CATCH {
    when X::MongoDB {
      ok $_.message ~~ m/ns \s+ not \s* found/, 'Collection cl1 not found';
    }
  }
}

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
$database.drop;

done-testing();
exit(0);
