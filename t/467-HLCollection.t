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
      street => [ 1, Str],
      number => [ 1, Int],
      number-mod => [ 0, Str],
      city => [ 1, Str],
      zip => [ 0, Str],
      state => [ 0, Str],
      country => [ 1, Str],
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


  $doc = $table.read( :criteria(%( number => ( '$gt' => 4307))));
say $doc.perl;



  $table.query-set( number => ( '$gt' => 4300));
  $doc = $table.delete( :!limit, :!ordered);
say $doc.perl;
}, 'read test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing;
