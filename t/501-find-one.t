#`{{
  Testing;
    collection.find_one()               Query database returning one doc
      implicit AND selection            Find with more fields
      projection                        Select fields to return
}}

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Collection $collection = get-test-collection( 'test', 'testf');

my %d1 = code           => 'd1'
       , name           => 'name and lastname'
       , address        => 'address'
       , city           => 'new york'
       ;

$collection.insert(%d1);

#show-documents( $collection, {code => 'd1'});

check-document( {code => 'd1'},
                { _id => 1, code => 1, name => 1, 'some-name' => 0}
              );

check-document( {code => 'd1'},
                { _id => 1, code => 1, name => 0, address => 0, city => 0},
                { code => 1}
              );

check-document( {code => 'd1'},
                { _id => 0, code => 0, name => 1, address => 1, city => 1},
                { _id => 0, code => 0}
              );

#------------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done();
exit(0);

#-------------------------------------------------------------------------------
# Check one document for its fields. Something like {code => 1, nofield => 0}
# use find_one()
#
sub check-document ( $criteria, %field-list, %projection = { })
{
  my %document = %($collection.find_one( $criteria, %projection));
  if +%document {
    for %field-list.keys -> $k {
      if %field-list{$k} {
        is( %document{$k}:exists, True, "Key '$k' exists. Check using find_one()");
      }
      
      else {
        is( %document{$k}:exists, False, "Key '$k' does not exist. Check using find_one()");
      }
    }
  }
}
