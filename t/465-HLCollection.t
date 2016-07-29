use v6.c;

use Test;
use lib 'Tests';
use MongoDB::HL::Collection;
use BSON::Document;

my MongoDB::HL::Collection $table = gen-table-class(
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

  is $table.^name,
     'MongoDB::HL::Collection::Address',
     "class type is $table.^name()";

  ok $table.^can('read'), 'table can read';
  ok $table.^can('insert'), 'table can insert';



  $table.set(
    street => 'Jan Gestelsteeg',
    country => 'Nederland',
    zip => 2.3.Num,

  #TODO extra field must be trapped
    extra => 'not described field'
  );

  my BSON::Document $doc = $table.insert;
  say $doc.perl;
  ok !$doc<ok>, 'Document has problems';
  is $doc<fields><number>, 'missing', 'field number is missing';
  is $doc<fields><zip>, 'type failure, is Num but must be Str',
     $doc<fields><zip>;
  is $doc<fields><extra>, 'not described in schema',
     'extra is not described in schema';

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
    country => 'Netherlands'
  );

  my BSON::Document $doc = $table.insert;
  ok $doc<ok>, 'Document written';
  say $doc.perl;

}, 'Proper fields test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = gen-table-class(
    :db-name<contacts>,
    :cl-name<address>
  );

  $sec-table.set(
    street => 'Nauwe Geldeloze pad',
    number => 400,
    country => 'Nederland',
    city => 'Elburg',
    country => 'Netherlands'
  );

  my BSON::Document $doc = $sec-table.insert;
  ok $doc<ok>, 'Document written';
  say $doc.perl;

}, '2nd Object test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = gen-table-class(
    :db-name<contacts>,
    :cl-name<address>
  );

  $sec-table.append-unknown-fields = True;
  $sec-table.set(
    street => 'Nauwe Geldeloze pad',
    number => 400,
    country => 'Nederland',
    city => 'Elburg',
    country => 'Netherlands',
    extra-field => 'etcetera'
  );

  my BSON::Document $doc = $sec-table.insert;
  ok $doc<ok>, 'Document written';
  say $doc.perl;

}, 'append unknown fields test';

#TODO $!append-unknown-fields

done-testing;
