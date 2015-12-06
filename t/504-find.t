#`{{
  Testing;
    collection.group()                  Group records
    collection.map-reduce()             Map reduce
}}

use lib 't';
use Test-support;

use v6;
use Test;
use MongoDB::Connection;
use BSON::Javascript-old;

#-------------------------------------------------------------------------------
my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database = $connection.database('test');

#is 1, 1, '1';
#done();
#exit(0);

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');

for ^100 -> $c {
  $collection.insert( { name => 'k' ~ Int(6.rand), value => Int($c.rand)});
}

#show-documents( $collection, {});

# Javascript reduce fnction. If prev[name] is undefined it cannot be set to
# the initial document because these values stay .
#
my $reduce-func = q:to/EOJS/;
   function( doc, prev) {
     prev.value = prev.value + doc.value;
     prev.count = prev.count + 1;
     prev.count_offset = prev.count + offset;
   }
   EOJS

my $key-func = q:to/EOJS/;
   function(doc) {
     printjson(doc);
     return {'xname': doc.name};
   }
   EOJS

my BSON::Javascript $js-r-scope .= new( javascript => $reduce-func,
                                        scope => {offset => -100}
                                      );

my BSON::Javascript $js-kf .= new(javascript => $key-func);

#say "BJ: {$js-r-scope.perl}\nType BSON::Javascript = {$js-r-scope ~~ BSON::Javascript}";
#say "$js-r-scope\n";

# Run de grouping function using the javascript reduce function and return
# all results in $r-doc. The results from reduce are found in the field retval.
#
my Hash $result = $collection.group( $js-r-scope,
                                     key => 'name',
                                     initial => { value => 0, count => 0},
                                     condition => %(name => %('$gt' => 'k0'))
#                                     key_js_func => $js-kf,
                                   );
#say "\nR:  {$result.perl}\n";
#exit(0);

# Now do the same in perl by getting the docs and do the work of $reduce
#
my %v;
my MongoDB::Cursor $cursor = $collection.find;
while $cursor.next -> %doc {

  # Condition skips all names below k1
  #
  next unless %doc<name> gt 'k0';

  # Change name of key as in the key javascript function
  #
#  %doc<name> = 'long_' ~ %doc<name>;

  if %v{%doc<name>}:!exists {
    %v{%doc<name>}<value> = 0;
    %v{%doc<name>}<count> = 0;
  }

  %v{%doc<name>}<value> += %doc<value>;
  %v{%doc<name>}<count>++;
}

# Compare the results
#
my $r = $result<retval>;
#say "\nA: {$r.perl}\n";
loop ( my $i = 0; $i < +$r; $i++) {
  my $r-doc = $r[$i];
#say "\nL: {$r-doc.perl}\n";
  my $k = $r-doc<name>;
  ok %v{$k}:exists, "V $k exists";
  is $r-doc<value>, %v{$k}<value>, "Value %v{$k}<value>";
  is $r-doc<count>, %v{$k}<count>, "Value %v{$k}<count>";
}

#-----------------------------------------------------------------------------
#
my $map-func = q:to/EOJS/;
   function() {
     emit( 'othername', this.name);
     emit( 'othervalue', this.value);
   }
   EOJS

$reduce-func = q:to/EOJS/;
   function( k, vs) {
     return { k : vs};
   }
   EOJS

$result = $collection.map-reduce(
            $map-func, $reduce-func, 
            :criteria(%(name => %('$gt' => 'k0'))),
          );
#say "\nR:  {$result.perl}\n";
my $nrecs = $result<counts><output>;
my $mrColl = $result<result>;
my MongoDB::Collection $mrc = $database.collection($mrColl);
#show-documents( $mrc, {});
is $mrc.count, $nrecs, "There are $nrecs results in collection $mrColl";
is $mrc.count(%(_id => 'othername')), 1, 'One othername id';
is $mrc.count(%(_id => 'othervalue')), 1, 'One othervalue id';

#-----------------------------------------------------------------------------
# Cleanup and close
#
$collection.database.drop;

done-testing();
exit(0);
