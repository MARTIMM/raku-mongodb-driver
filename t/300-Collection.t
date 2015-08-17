#`{{
  Testing;
    database.collection()               Create collection
    database.create_collection()        Create collection explicitly
    collection.drop()                   Drop collection

    X::MongoDB::Collection              Catch exceptions
}}

BEGIN { @*INC.unshift( './t' ) }
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
$collection.insert( $%( 'name' => 'Jan Klaassen'));

# Drop current collection twice
#
my $doc = $collection.drop;
ok $doc<ok>.Bool == True, 'Dropping cl1 ok';
is $doc<ns>, 'test.cl1', 'Dropped collection';
is $doc<nIndexesWas>, 1, 'Number of dropped indexes';

if 1 {
  $doc = $collection.drop;
  CATCH {
    when X::MongoDB::Collection {
      ok $_.message ~~ m/ns \s+ not \s* found/, 'Collection cl1 not found';
    }
  }
}

#-------------------------------------------------------------------------------
# Create using illegal collection name
#
if 1 {
  $database.create_collection('abc-def and a space');
  CATCH {
    when X::MongoDB::Database {
      ok $_.message ~~ m/Illegal \s* collection \s* name/, 'Illegal collection name';
    }
  }
}

#-------------------------------------------------------------------------------
# Drop collection and create one explicitly with some parameters
#
#$collection.drop;
$database.create_collection( 'cl1', :capped, :size(1000));

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
$database.create_collection( 'cl1', :capped, :size(1000), :max(10));

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

done();
exit(0);
