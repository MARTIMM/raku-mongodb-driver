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

for ^10 -> $i {
  %d1<test_record> = 'tr' ~ $i;
  $collection.insert(%d1);
}

#show-documents( $collection, {code => 'd1'});


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
ok $cursor.count == 10.0, 'Counting ten documents';

$cursor = $collection.find( %( code => 'd1', test_record => 'tr3'));
ok $cursor.count == 1.0, 'Counting one document';

$cursor = $collection.find();
ok $cursor.count(:limit(3)) == 3.0, 'Limiting count to 3 documents';


$cursor = $collection.find();
ok $cursor.count( :skip(8), :limit(3)) == 2.0, 'Skip eight then limit three yields 2';

$cursor.kill;
my $error-doc = $collection.database.get_last_error;
ok $error-doc<ok>.Bool, 'No error after kill cursor';

$cursor.count;
ok $cursor.count == 10.0, 'Still counting ten documents';

#$collection.ensure_index( %(test_record => Num.new(1.0)), %(name => 'testindex', background => True));

#------------------------------------------------------------------------------
# Cleanup and close
#
# TODO replace with drop when available
$collection.remove( );

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
