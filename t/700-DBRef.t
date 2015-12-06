#`{{
  Testing;
    DBRef
}}

use lib 't';
use Test-support;

use v6;
use Test;

use MongoDB::Connection;
use MongoDB::DBRef;

plan 1;
skip-rest('No DBRef tests yet');
exit(0);

#-------------------------------------------------------------------------------
#
my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database = $connection.database('test');

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');

for ^10 -> $c {
  $collection.insert( { idx => $c,
                        name => 'k' ~ Int(6.rand),
                        value => Int($c.rand)
                      }
                    );
}

my Hash $d1 = $collection.find-one({idx => 8});
show-document($d1);

#-------------------------------------------------------------------------------
#
my MongoDB::DBRef $dbr .= new( :id($d1<_id>, :$collection));
isa-ok $dbr, 'MongoDB::DBRef';

my BSON::ObjectId $i = $dbr.doc();
is $i, $d1<_id>, 'Compare object id';

$dbr .= new( :id($d1<_id>), :collection($collection.name));
my Hash $h = $dbr.doc();
is $h<$ref>, $collection.name, 'Test collection name';

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done-testing();
exit(0);
