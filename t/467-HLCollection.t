use v6.c;

use Test;

use MongoDB;
use MongoDB::HL::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
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
  $table.reset;
  $table.set(
    street => 'Jan Gestelsteeg',
    number => $count++,
    number-mod => 'zwart',
    country => 'Nederland',
    zip => '1043 XY',
    city => 'Lutjebroek',
    state => 'Gelderland',
  );
  for ^10 {
    $table.set-next(
      street => 'Jan Gestelsteeg',
      number => $count++,
      number-mod => 'zwart',
      country => 'Nederland',
      zip => '1043 XY',
      city => 'Lutjebroek',
      state => 'Gelderland',
    );
  }
  my BSON::Document $doc = $table.insert;
  ok $doc<ok>, 'Write ok';
  is $doc<n>, 11, '11 docs written';


  $doc = $table.count( :criteria(%( number => ( '$gt' => 4307),)));
  ok $doc<ok>, 'Count ok';
  is $doc<n>, 7, '7 records counted';

  my $n = 1;
  $doc = $table.read( :criteria(%( number => ( '$gt' => 4307),)));
  while $table.read-next { $n++; }
  is $n, 7, '7 records read';

  # delete data
  $doc = $table.delete(
    :deletes( [
        ( :q(number => ('$gt' => 4300)), :!limit),
      ]
    ),
    :!ordered
  );
#say $doc.perl;

}, 'read test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing;
