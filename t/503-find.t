#`{{
  Testing
    collection.find()                   Query database
      Implicit AND selection            Find with more fields
      $eq, $gt, $gte                    Equal, Greater than and friends
      $lt, $lte                         Less than and friends
      $ne                               not equal
      $in, $nin                         any/none of the values
      $or, $andm, $not, $nor            or, and, not, nor
      $exists                           field exists
      $type                             type check on field
      $mod                              modulo operation on the value of a field
      $regex                            using BSON::Regex
      $text                             text search
      $where                            serverside javascript testing
}}

use lib 't';
use Test-support;

use v6;
use Test;
use MongoDB::Collection;
use BSON::Regex;
use BSON::Javascript-old;

my MongoDB::Collection $collection = get-test-collection( 'test', 'testf');
$collection.database.drop;

# Fill: d0/n99, d2/n97, d4/n95, d6/n93 ... d96/n3, d98/n1
#
for ^100 -> $i, $j {
  my %d = %( code1 => 'd' ~ $i, code2 => 'n' ~ (100 - $j));
  %d<code3> = $i + $j if any(10..20) ~~ $i;
  $collection.insert(%d);
}

#show-documents( $collection, {}, {_id => 0});

my MongoDB::Connection $connection = $collection.database.connection;
my Hash $version = $connection.version;

#-----------------------------------------------------------------------------
# Implicit $and
#
my Hash $query = %( code1 => 'd1', code2 => 'n1');
my MongoDB::Cursor $cursor = $collection.find($query);
is $cursor.count, 0, 'Implicit $and, There are no documents';

#-----------------------------------------------------------------------------
# $eq. Mongod release below 3 returns errors for $eq
#
try {
  $query = %( code1 => {'$eq' => 'd80'},
              code2 => {'$eq' => 'n19'}
            );

  if $version<release1> < 3 {
    $cursor = $collection.find($query);
    my $c = $cursor.count;

    CATCH {
      when X::MongoDB {
        ok .message ~~ ms/'exception:' 'invalid' 'operator:' '$eq'/,
           'exception: invalid operator: $eq';
      }

      default {
        say .perl;
      }
    }
  }

  else {
    $cursor = $collection.find($query);
    is $cursor.count, 1, 'There is 1 document';
  }
}

#-----------------------------------------------------------------------------
# $gt,
#
$query<code1> = %('$gt' => 'd50');
$query<code2>:delete;
$cursor = $collection.find($query);

# d6, d8 are gt d50! => d6, d8, d52, d54, ...d98 = 26 docs
#
is $cursor.count, 26, 'code1 $gt d50, 26 documents';

#-----------------------------------------------------------------------------
# $gte
#
$query<code1> = %('$gte' => 'd50');
$cursor = $collection.find($query);

# d6, d8 are gt d50! => d6, d8, d50, d52, d54, ...d98 = 27 docs
#
is $cursor.count, 27, 'code1 $gte d50, 27 documents';

#-----------------------------------------------------------------------------
# $lt
#
$query<code1>:delete;
$query<code2> = %('$lt' => 'n51');
$cursor = $collection.find($query);

# n49, n47, n45, .., n1 = 23 docs
#
is $cursor.count, 23, 'code2 $lt n51, 23 documents';

#-----------------------------------------------------------------------------
# $lte
#
$query<code2> = %('$lte' => 'n51');
$cursor = $collection.find($query);

# n51, n49, n47, n45, .., n1 = 23 docs
#
is $cursor.count, 24, 'code2 $lte n51, 24 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$gt' => 'd42');
$query<code2> = %('$gte' => 'n51');
$cursor = $collection.find($query);

# d6/n93, d8/n91, d44/n55, d46/n53, d48/n51, d90/n9, d92/n7 = 7 docs
#
is $cursor.count, 7, 'code1 $gt d42 and code2 $gte n51, 7 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$ne' => 'd42');
$query<code2> = %('$ne' => 'n99');
$cursor = $collection.find($query);

is $cursor.count, 48, 'code1 $ne d42 and code2 ne n99, 48 documents';

#-----------------------------------------------------------------------------
$query<code1> = %('$in' => [<d42 d64 d96 d98>]);
$query<code2> = %('$in' => [<n1 n3 n11>]);
$cursor = $collection.find($query);

# 2 documents because of d96/n3 and d98/n1
#
is $cursor.count,
   2,
   'code1 $in [<d42 d64 d96 d98>] and code2 $in [<n1 n3 n11>], 2 documents';

#-----------------------------------------------------------------------------
# $or
#
$query<code1> = %('$in' => [<d42 d64 d96 d98>]);
$query<code2> = %('$in' => [<n1 n3 n11>]);
$cursor = $collection.find( %(
    '$or' => [
      { code1 => {'$in' => [<d42 d64 d96 d98>]}},
      { code2 => {'$in' => [<n1 n3 n11>]}}
    ]
  )
);

# 5 documents because of d96/n3 and d98/n1 overlap
#
is $cursor.count,
   5,
   '$or [{code1 => {$in => []},{code2 => {$in => []}], 2 documents';

#-----------------------------------------------------------------------------
# $and
#
$query<code1> = %('$in' => [<d42 d64 d96 d98>]);
$query<code2> = %('$in' => [<n1 n3 n11>]);
$cursor = $collection.find( %(
    '$and' => [
      { code1 => {'$in' => [<d42 d64 d96 d98>]}},
      { code2 => {'$in' => [<n1 n3 n11>]}}
    ]
  )
);

# 2 documents because of d96/n3 and d98/n1 are found together
#
is $cursor.count,
   2,
   '$and [{code1 => {$in => []},{code2 => {$in => []}], 2 documents';

#-----------------------------------------------------------------------------
# $nor
#
$query<code1> = %('$in' => [<d42 d64 d96 d98>]);
$query<code2> = %('$in' => [<n1 n3 n11>]);
$cursor = $collection.find( %(
    '$nor' => [
      { code1 => {'$nin' => [<d42 d64 d96 d98>]}},
      { code2 => {'$nin' => [<n1 n3 n11>]}}
    ]
  )
);

# 2 documents because of d96/n3 and d98/n1 are found together
#
is $cursor.count,
   2,
   '$nor [{code1 => {$nin => []},{code2 => {$nin => []}], 2 documents';

#-----------------------------------------------------------------------------
# $mod
#
try {
  $cursor = $collection.find( %(code3 => {'$mod' => [ 3, 0]}));
  my $cc = $cursor.count;

  CATCH {
    when X::MongoDB {
      is .error-text ~~ m:s/divisor cannot be 0/, .error-text;
    }
  }
}

#$cursor = $collection.find( %(code3 => {'$mod' => [ 3, 7]}));
#say "cc: ", $cursor.count;
#is $cursor.count, 2, 'code3 => {$mod => [ 3, 0]}, 2 documents';

#-----------------------------------------------------------------------------
# $mod faulty args
#
if $version<release1> == 2 and $version<release2> < 6 {
  $cursor = $collection.find( %(code3 => {'$mod' => [ ]}));
  is $cursor.count, 2, 'code3 => {$mod => [ ]}, 2 documents';
  CATCH {
    when X::MongoDB {
      ok .message ~~ ms/'mod' 'can\'t' 'be' '0'/,
         'exception: mod can\'t be 0 (code3 => {$mod => [ ]})';
    }

    default {
      say .perl;
    }
  }
}

elsif $version<release1> == 2 and $version<release2> >= 6 {
  $cursor = $collection.find( %(code3 => {'$mod' => [ 3, 0, 1]}));
  is $cursor.count, 2, 'code3 => {$mod => [ ]}, 2 documents';
  CATCH {
    when X::MongoDB {
      ok .message ~~ m:s/mod can\'t be 0/,
         .error-text;
    }

    default {
      say .perl;
    }
  }
}


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
# $exists
#
$cursor = $collection.find(%(code3 => {'$exists' => 1}));

# 6 documents have code3
#
is $cursor.count, 6, 'code 3 $exists, 6 documents';

#-----------------------------------------------------------------------------
# $exists = 0
#
$cursor = $collection.find(%(code3 => {'$exists' => 0}));

# 44 documents have code3
#
is $cursor.count, 50 - 6, 'code 3 $exists = 0, 44 documents';

#-----------------------------------------------------------------------------
# $not $exists
#
$cursor = $collection.find(%(code3 => {'$not' => {'$exists' => 1}}));

# 44 documents have code3
#
is $cursor.count, 50 - 6, 'code 3 $not $exists, 44 documents';

#-----------------------------------------------------------------------------
# $exists and $in
#
$cursor = $collection.find(%(code3 => {'$exists' => 1, '$in' => [33..45]}));

# 3 documents have code3 and whithin range
#
is $cursor.count, 3, 'code 3 $exists and $in => [33..45], 3 documents';

#-----------------------------------------------------------------------------
# $type
#
$cursor = $collection.find(%(code3 => {'$type' => 16}));

# 3 documents have code3 and whithin range
#
is $cursor.count, 6, 'code 3 has type int32, 3 documents';

#-----------------------------------------------------------------------------
# $regex
#
$query = { code1 => BSON::Regex.new(:regex('d.2')) };
$cursor = $collection.find($query);
is $cursor.count, 9, "Regex 9 documents for /d.2/";

$query = { code2 => BSON::Regex.new(:regex('n.5')) };
$cursor = $collection.find($query);
is $cursor.count, 9, "Regex 9 documents for /n.5/";

$query = { code2 => BSON::Regex.new(:regex('n\\d$')) };
$cursor = $collection.find($query);
is $cursor.count, 5, 'Regex 5 documents for /n\\d$/';

#-----------------------------------------------------------------------------
# $text
#
if $version<release1> == 2 and $version<release2> < 6 {
  $cursor = $collection.find( %(
      '$text' => {
         '$search' => 'n9',
         '$language' => 'none'
      }
    )
  );

  # 2 documents has n9: n9 and n99
  #
  is $cursor.count, 2, '$text => {$search => n9}, 2 documents';
  CATCH {
    when X::MongoDB {
      ok .message ~~ m/'invalid operator: ' ('$language'|'$search')/,
         'exception: invalid operator: $language/$search, $text => {$search => n9}';
    }
  }
}

#-----------------------------------------------------------------------------
# $where
#
$cursor = $collection.find(%('$where' => 'this.code3 <= 27'));

# 3 documents have code3 and whithin range
#
is $cursor.count, 2, 'code 3 $where <= 27, 2 documents';

my BSON::Javascript $js .= new(javascript => 'this.code3 <= 29');
$cursor = $collection.find(%('$where' => $js));

# 3 documents have code3 and whithin range
#
is $cursor.count, 3, 'code 3 $where <= 29, 3 documents';


#-----------------------------------------------------------------------------
#@code-list = $collection.distinct( 'code', %(name => %(regex =>'Hein')));

#-----------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done-testing();
exit(0);
