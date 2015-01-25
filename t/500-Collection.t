BEGIN { @*INC.unshift( 'lib' ) }

use Test;
use MongoDB;

my MongoDB::Connection $connection .= new();
my MongoDB::Database $database = $connection.database('test');
my MongoDB::Collection $collection = $database.collection('Collection-find1');

my %d1 = code           => 'd1'
       , name           => 'name and lastname'
       , address        => 'address'
       , city           => 'new york'
       ;

$collection.insert(%d1);

#show-documents({code => 'd1'});

check-document1( {code => 'd1'},
                 { _id => 1, code => 1, name => 1, 'some-name' => 0}
               );

check-document1( {code => 'd1'},
                 { _id => 1, code => 1, name => 0, address => 0, city => 0},
                 { code => 1}
               );

check-document1( {code => 'd1'},
                 { _id => 0, code => 0, name => 1, address => 1, city => 1},
                 { _id => 0, code => 0}
               );

check-document2( {code => 'd1'},
                 { _id => 1, code => 1, name => 1, 'some-name' => 0}
               );

check-document2( {code => 'd1'},
                 { _id => 1, code => 1, name => 0, address => 0, city => 0},
                 { code => 1}
               );

check-document2( {code => 'd1'},
                 { _id => 0, code => 0, name => 1, address => 1, city => 1},
                 { _id => 0, code => 0}
               );



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
sub check-document1 ( $criteria, %field-list, %projection = { })
{
  my $cursor = $collection.find( $criteria, %projection);
  while $cursor.fetch() -> %document {
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

#-------------------------------------------------------------------------------
# Check one document for its fields. Something like {code => 1, nofield => 0}
# use find_one()
#
sub check-document2 ( $criteria, %field-list, %projection = { })
{
  my %document = %($collection.find_one( $criteria, %projection));
  if %document.keys {
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

#-------------------------------------------------------------------------------
#
sub show-documents ( $criteria )
{
  say '-' x 80;
  my MongoDB::Cursor $cursor = $collection.find($criteria);
  while $cursor.fetch() -> %document
  {
    say "Document:";
    say sprintf( "    %10.10s: %s", $_, %document{$_}) for %document.keys;
    say "";
  }
}
