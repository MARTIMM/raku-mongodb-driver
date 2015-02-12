#`{{
  Testing
    collection.find()                   Query database
      Implicit AND selection            Find with more fields
      $gt, $gte                         Greater than and friends
      $lt, $lte                         Less than and friends
      $ne                               not equal
      $in, $nin, $or                    or
      $not                              not
}}

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Collection $collection = get-test-collection( 'test', 'testf');

# Fill: d0/n99, d2/n97, d4/n95, d6/n93 ... d96/n3, d98/n1
#
for ^100 -> $i, $j {
  my %d = %( code1 => 'd' ~ $i, code2 => 'n' ~ (100 - $j));
  $collection.insert(%d);
}

#show-documents( $collection, {});

#show-documents( $collection, %(code1 => 'd1'));

#-----------------------------------------------------------------------------
my Hash $query = %( code1 => 'd1', code2 => 'n1');
my MongoDB::Cursor $cursor = $collection.find($query);
is $cursor.count, 0, 'There are no documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$gt' => 'd50');
$query<code2>:delete;
$cursor = $collection.find($query);

# d6, d8 are gt d50! => d6, d8, d52, d54, ...d98 = 26 docs
#
is $cursor.count, 26, '26 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$gte' => 'd50');
$cursor = $collection.find($query);

# d6, d8 are gt d50! => d6, d8, d50, d52, d54, ...d98 = 27 docs
#
is $cursor.count, 27, '27 documents';

#-----------------------------------------------------------------------------
$query<code1>:delete;
$query<code2> = %('$lt' => 'n51');
$cursor = $collection.find($query);

# n49, n47, n45, .., n1 = 23 docs
#
is $cursor.count, 23, '23 documents';

#-----------------------------------------------------------------------------
$query<code2> = %('$lte' => 'n51');
$cursor = $collection.find($query);

# n51, n49, n47, n45, .., n1 = 23 docs
#
is $cursor.count, 24, '24 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$gt' => 'd42');
$query<code2> = %('$gte' => 'n51');
$cursor = $collection.find($query);

# d6/n93, d8/n91, d44/n55, d46/n53, d48/n51, d90/n9, d92/n7 = 7 docs
#
is $cursor.count, 7, '7 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$ne' => 'd42');
$query<code2> = %('$ne' => 'n99');
$cursor = $collection.find($query);

is $cursor.count, 48, '48 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$in' => [<d42 d64 d96 d98>]);
$query<code2> = %('$in' => [<n1 n3 n11>]);
$cursor = $collection.find($query);

# 2 documents because of d96/n3 and d98/n1
#
is $cursor.count, 2, '2 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$in' => [<d42 d64 d96 d98>]);
$query<code2> = %('$in' => [<n1 n3 n11>]);
#say %('$or' => [$query]).perl;
$cursor = $collection.find(%('$or' => [$query]));

# 5 documents because of d96/n3 and d98/n1 overlap
# ?????????????
is $cursor.count, 2, '2 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$nin' => [<d42 d64 d96 d98>]);
$query<code2> = %('$in' => [<n1 n3 n11>]);
$cursor = $collection.find($query);

# 1 documents because of d96/n3 and d98/n1 are not in code1, n11 is.
#
is $cursor.count, 1, '1 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$not' => %('$gte' => 'd98'));
$query<code2>:delete;
$cursor = $collection.find($query);

# All but one = 49 docs
#
is $cursor.count, 49, '49 documents';

#-----------------------------------------------------------------------------
#@code-list = $collection.distinct( 'code', %(name => %(regex =>'Hein')));

#-----------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done();
exit(0);
