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

  my Int $fq = $table.query-set-next(
    number => 253,
  );
  is $fq, 1, 'One failure ofter query-set-next';
  my BSON::Document $doc = $table.delete;
  is $doc<fields><->, 'current query/criteria is empty', $doc<fields><->;

  $fq = $table.query-set;
  is $fq, 1, 'One failure after query-set';
  $doc = $table.delete;
  is $doc<fields><->, 'current query/criteria is empty', $doc<fields><->;


  # missing fields not checked
  $table.query-set(
    zip => 2.3.Num,
    extra => 'not described field'
  );

  $doc = $table.delete;
  ok !$doc<ok>, 'Document has problems';
  is $doc<fields><zip>, 'type failure, is Num but must be Str',
     "field zip $doc<fields><zip>";
  is $doc<fields><extra>, 'not described in schema',
     'extra is not described in schema';

}, 'query field failure test';

#-------------------------------------------------------------------------------
subtest {

  # Insert enaugh records
  $table.reset;
  $table.set(
    street => 'Jan Gestelsteeg',
    number => 253,
    number-mod => 'zwart',
    country => 'Nederland',
    zip => '1043 XY',
    city => 'Lutjebroek',
    state => 'Gelderland',
  );
  for ^10 {
    $table.set-next(
      street => 'Jan Gestelsteeg',
      number => 253,
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



  my Int $fq = $table.query-set(
    number => 253,
  );

  $doc = $table.delete;
  ok $doc<ok>, 'Delete ok';
  is $doc<n>, 1, 'One doc deleted';



  $fq = $table.query-set(
    number => 253,
  );

  $fq = $table.query-set-next(
    number => 253,
  );

  is $fq, 0, 'No field errors';
  is $table.query-count, 2, '2 queries';
  $doc = $table.delete;
  ok $doc<ok>, 'Delete ok';
  is $doc<n>, 2, 'Two docs deleted';



  $fq = $table.query-set( number => 253, );
  $fq = $table.query-set-next( number => 400 );
  $fq = $table.query-set-next( number => 2 );

  $doc = $table.delete( :!limit, :!ordered);
  ok $doc<ok>, 'Delete ok';
  ok $doc<n> > 0, "More than 1($doc<n>) doc deleted";

}, 'delete test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing;
