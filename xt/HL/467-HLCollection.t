use v6.c;

use Test;

use MongoDB;
use MongoDB::HL::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::HL::Collection $table = collection-object(
  :uri<mongodb://:65010>,
  :db-name<contacts>,
  :cl-name<address>,

  :schema( BSON::Document.new: (
      street => [ True, Str],
      number => [ True, Int],
      number-mod => [ False, Str],
      city => [ True, Str],
      zip => [ False, Str],
      state => [ False, Str],
      country => [ True, Str],
    )
  )
);

#-------------------------------------------------------------------------------
subtest {

  my Int $count = 4304;
  # Insert enaugh records
  my Array $r = [];
  $r.push: %(
    street => 'Jan Gestelsteeg',
    number => $count++,
    number-mod => 'zwart',
    country => 'Nederland',
    zip => '1043 XY',
    city => 'Lutjebroek',
    state => 'Gelderland',
  );
  for ^10 {
    $r.push: %(
      street => 'Jan Gestelsteeg',
      number => $count++,
      number-mod => 'zwart',
      country => 'Nederland',
      zip => '1043 XY',
      city => 'Lutjebroek',
      state => 'Gelderland',
    );
  }
  my BSON::Document $doc = $table.insert(:inserts($r));
  ok $doc<ok>, 'Write ok';
  is $doc<n>, 11, '11 docs written';


  $doc = $table.count( :criteria(%( number => ( '$gt' => 4307),)));
  ok $doc<ok>, 'Count ok';
  is $doc<n>, 7, '7 records counted';

  my $n = 1;
  $doc = $table.read( :criteria(%( number => ( '$gt' => 4307),)));
  while $table.read-next { $n++; }
  is $n, 7, '7 records read';

}, 'read test';

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $doc = $table.update(
    :updates( [ (
          q => ( number => 4307, ),
          u => ( '$inc' => ( number => 1, )),
        ), (
        
          q => ( number => 4304, ),
          u => ( '$inc' => ( number => -1, )),
        )
      ]
    )
  );

  is $doc<nModified>, 2, '2 records modified';
say $doc.perl;
  
  $doc = $table.count( :criteria(%( number => 4307,)));
  is $doc<n>, 0, '0 records with original number';
  $doc = $table.count( :criteria(%( number => 4308,)));
  is $doc<n>, 2, '2 records with same number';


  $doc = $table.replace(
    :replaces( [ (
          q => ( number => 4306, ),
          r => %(
            street => 'Jan Gestelsteeg',
            number => 8000,
            number-mod => 'zwart',
            country => 'Nederland',
            zip => '1043 XY',
            city => 'Lutjebroek',
            state => 'Gelderland',
          ),
        ),
      ]
    )
  );

  is $doc<nModified>, 1, '1 record modified';
say $doc;

  $doc = $table.count( :criteria(%( number => 8000,)));
  is $doc<n>, 1, '1 record with new number';

say $doc.perl;
}, 'update test';

#-------------------------------------------------------------------------------
# Cleanup
#

# delete data
my BSON::Document $doc = $table.delete(
  :deletes( [
      ( :q(number => ('$gt' => 4300)), :!limit),
    ]
  ),
  :!ordered
);
#say $doc.perl;

info-message("Test $?FILE end");
done-testing;
