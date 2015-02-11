#`{{
  Testing;
    database.collection()               Create collection.
    collection.drop()                   Drop collection

    X::MongoDB::Collection              Catch exceptions
}}

#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Connection $connection .= new();
my MongoDB::Database $database = $connection.database('test');

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');
isa_ok( $collection, 'MongoDB::Collection');
$collection.insert( $%( 'name' => 'Jan Klaassen'));

# Drop current collection twice
#
my $doc = $collection.drop;
ok $doc<ok>.Bool == True, 'Drop ok';
is $doc<msg>, 'indexes dropped for collection', 'Drop message ok';

if 1 {
  $doc = $collection.drop;
  CATCH {
    when X::MongoDB::Collection {
      ok $_.message ~~ m/ns \s+ not \s* found/, 'Collection not found';
    }
    
    default {
      say "E: ", $_.perl;
    }
  }
}

#-------------------------------------------------------------------------------
# Cleanup
#
$database.drop;

done();
exit(0);
