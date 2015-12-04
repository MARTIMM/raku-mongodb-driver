#`{{
  Testing;
    collection.find()                   Query database
    collection.ensure-index()           Create indexes
    collection.get-indexes()            Get index info
    collection.drop-index()             Drop an index
    collection.drop-indexes()           Drop all indexes
    cursor.fetch()                      Fetch a document
    
    X::MongoDB                          Catch exceptions

    collection.stats()                  Collection statistics
    collection.data-size()              $stats<size>
}}

use lib 't';
use Test-support;

use v6;
use Test;
use MongoDB::Collection;

my MongoDB::Collection $collection = get-test-collection( 'test', 'testf');

for 1..10 -> $i, $j
{
  my %d = %( code1 => 'd' ~ $i, code2 => 'n' ~ (100 -$j));
  $collection.insert(%d);
}

#show-documents( $collection, {});
#show-documents( $collection, %(code1 => 'd1'));

my MongoDB::Cursor $cursor = $collection.find(%(code1 => 'd1'));
is $cursor.count, 1, 'There is one document';

# This should go well
#
$collection.ensure-index( %( code1 => 1),
                          %( name => 'testindex',
                             background => True
                           )
                        );

$cursor = $collection.get-indexes();
is $cursor.count, 2, "Two indexes found";
my $doc;
my @index-names;
while $doc = $cursor.fetch {
    @index-names.push($doc<name>);
}

ok any(@index-names) ~~ '_id_', 'Index name _id_ found';
ok any(@index-names) ~~ 'testindex', 'Index name testindex found';

# Now we kick it
#
try {
  # Its an empty key specification, but will complain about 'no index
  # name'. This is because of ensure-index() not being able to generate
  # one from the key specification.
  #
  $collection.ensure-index(%());
  CATCH {
    when X::MongoDB {
       ok .message ~~ m:s/exception\: index names cannot be empty/, .error-text;
    }
  }
}

try {
  # Now the name is specified, We can get a 'bad add index' error.
  #
  $collection.ensure-index( %(), %(name => 'testindex'));
  CATCH {
    when X::MongoDB {
       ok .message ~~ m:s/ 'exception:' 'bad' 'index' 'key' 'pattern'
          '{}:' 'Index' 'keys' 'cannot' 'be' 'empty'/, .error-text;
    }
  }
}

# Drop the same index twice. We get a 'can't find index' error.
#
$doc = $collection.drop-index( %( code1 => 1));
try {
  $doc = $collection.drop-index( %( code1 => 1));
  CATCH {
    when X::MongoDB {
      ok .message ~~ m/can\'t \s+ find \s+ index \s+ with \s+ key/,
         .error-text;
    }
  }
}

# Create index again and delete using the index name
#
$collection.ensure-index( %( code1 => 1),
                          %( name => 'testindex',
                             background => True
                           )
                        );
$doc = $collection.drop-index('testindex');
is $doc<ok>.Bool, True, 'Drop index ok';

#-------------------------------------------------------------------------------
# Create index again and get some statistics for it
#
$collection.ensure-index( %( code1 => 1),
                          %( name => 'testindex',
                             background => True
                           )
                        );
my $stats = $collection.stats(:scale(1));
ok $stats<indexSizes><_id_>:exists, 'Found index stats info on _id_';
ok $stats<indexSizes><testindex>:exists, 'Found index stats info on testindex';

$collection.ensure-index( %( code1 => 1),
                          %( name => 'testindex',
                             background => True
                           )
                        );

#-------------------------------------------------------------------------------
# Get statistics and read size
#
$stats = $collection.stats( :scale(1), :index-details,
                            :index-details-fields({_id_ => 0})
                          );
#say $stats.perl;

my $size = $collection.data-size();
is( $size, $stats<size>, "Size $size");

#-------------------------------------------------------------------------------
# Drop all indexes
#
$doc = $collection.drop-indexes;
ok $doc<msg> ~~ m/non\-_id \s+ indexes \s+ dropped \s+ for \s+ collection/,
   'All non-_id indexes dropped'
   ;

#-------------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done-testing();
exit(0);

#-------------------------------------------------------------------------------
# Check one document for its fields. Something like {code => 1, nofield => 0}
# use find-one()
#
sub check-document ( $criteria, %field-list, %projection = { })
{
  my %document = %($collection.find-one( $criteria, %projection));
  if +%document {
    for %field-list.keys -> $k {
      if %field-list{$k} {
        is %document{$k}:exists,
           True,
           "Key '$k' exists. Check using find-one()"
           ;
      }
      
      else {
        is %document{$k}:exists,
           False,
           "Key '$k' does not exist. Check using find-one()"
           ;
      }
    }
  }
}
