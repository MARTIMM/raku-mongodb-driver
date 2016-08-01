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

  my MongoDB::HL::Collection $subtable = collection-object(
    :uri<mongodb://:65010>,
    :db-name<c0>,
    :cl-name<a0>,

    :schema( BSON::Document.new: (
        street => [ 0, Str],
        number => [ 0, Int],
      )
    )
  );

  my $fr = $subtable.set;
  is $fr, 1, 'One failure';
  my BSON::Document $doc = $subtable.insert;
  is $doc<fields><->, 'current record is empty', $doc<fields><->;

}, 'all optional fields test';

#-------------------------------------------------------------------------------
subtest {

  is $table.^name,
     'MongoDB::HL::Collection::Address',
     "class type is $table.^name()";

  ok $table.^can('read'), 'table can read';
  ok $table.^can('insert'), 'table can insert';

  $table.set(
    street => 'Jan Gestelsteeg',
    country => 'Nederland',
    zip => 2.3.Num,
    extra => 'not described field'
  );

  my BSON::Document $doc = $table.insert;
  say $doc.perl;
  ok !$doc<ok>, 'Document has problems';
  is $doc<fields><number>, 'missing', 'field number is missing';
  is $doc<fields><city>, 'missing', 'field number is missing';
  is $doc<fields><zip>, 'type failure, is Num but must be Str',
     "field zip $doc<fields><zip>";
}, 'field failure test';

#-------------------------------------------------------------------------------
subtest {

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

  my BSON::Document $doc = $table.insert;
  ok $doc<ok>, 'Document written';

}, 'Proper fields test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = collection-object(
    :db-name<contacts>,
    :cl-name<address>
  );

  $sec-table.set(
    street => 'Nauwe Geldeloze pad',
    number => 400,
    country => 'Nederland',
    city => 'Elburg',
  );

  my BSON::Document $doc = $sec-table.insert;
  ok $doc<ok>, 'Document written';

}, '2nd Object test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = collection-object(
    :db-name<contacts>,
    :cl-name<address>
  );

  $sec-table.append-unknown-fields = True;
  $sec-table.set(
    street => 'Nauwe Geldeloze pad',
    number => 400,
    country => 'Nederland',
    city => 'Elburg',
    extra-field => 'etcetera'
  );

  my BSON::Document $doc = $sec-table.insert;
  ok $doc<ok>, 'write ok';
  is $doc<n>, 1, 'one record written';

}, 'append unknown fields test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = collection-object(
    :db-name<contacts>,
    :cl-name<address>
  );

  # Missing country and wrong number
  my Int $fe = $sec-table.set(
    street => 'Nauwe Geldeloze pad',
    number => 4.5.Num,
    city => 'Elburg',
  );
  is $fe, 2, 'Failures found';

  $fe = $sec-table.set-next(
    street => 'Mauve plein',
    number => 2,
    number-mod => 'a',
    country => 'Nederland',
    city => 'Groningen',
  );
  is $fe, 2, 'Same number of failures';
  is $sec-table.record-count, 1, 'Still one record';

  # retry
  $fe = $sec-table.set(
    street => 'Nauwe Geldeloze pad',
    number => 400,
    country => 'Nederland',
    city => 'Elburg',
  );
  is $fe, 0, 'No failures found';

  $sec-table.set-next(
    street => 'Mauve plein',
    number => 2,
    number-mod => 'a',
    country => 'Nederland',
    city => 'Groningen',
  );

  is $sec-table.record-count, 2, 'Two records';

  my BSON::Document $doc = $sec-table.insert;
  ok $doc<ok>, 'write ok';
  is $doc<n>, 2, 'two records written';
  say $doc.perl;

  is $sec-table.record-count, 1, 'reset to records';

}, 'multiple records test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing;
