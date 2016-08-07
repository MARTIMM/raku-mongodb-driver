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

  my MongoDB::HL::Collection $subtable = collection-object(
    :uri<mongodb://:65010>,
    :db-name<c0>,
    :cl-name<a0>,

    :schema( BSON::Document.new: (
        street => [ False, Str],
        number => [ False, Int],
      )
    )
  );

  my BSON::Document $doc = $subtable.insert( :inserts([{ },]));
  is $doc<fields><->, 'current record is empty', $doc<fields><->;

}, 'all optional fields test';

#-------------------------------------------------------------------------------
subtest {

  is $table.^name,
     'MongoDB::HL::Collection::Address',
     "class type is $table.^name()";

  ok $table.^can('read'), 'table can read';
  ok $table.^can('insert'), 'table can insert';

  my BSON::Document $doc = $table.insert(
    :inserts( [ %(
          street => 'Jan Gestelsteeg',
          country => 'Nederland',
          zip => 2.3.Num,
          extra => 'not described field'
        ),
      ]
    )
  );

say $doc.perl;
  ok !$doc<ok>, 'Document has problems';
  is $doc<fields><number>, 'missing', 'field number is missing';
  is $doc<fields><city>, 'missing', 'field number is missing';
  is $doc<fields><zip>, 'type failure, is Num but must be Str',
     "field zip $doc<fields><zip>";
}, 'field failure test';

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $doc = $table.insert(
    :inserts( [ %(
          street => 'Jan Gestelsteeg',
          number => 253,
          number-mod => 'zwart',
          country => 'Nederland',
          zip => '1043 XY',
          city => 'Lutjebroek',
          state => 'Gelderland',
        ),
      ]
    )
  );
  ok $doc<ok>, 'Document written';

}, 'Proper fields test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = collection-object(
    :db-name<contacts>,
    :cl-name<address>
  );

  my BSON::Document $doc = $sec-table.insert(
    :inserts( [ %(
          street => 'Nauwe Geldeloze pad',
          number => 400,
          country => 'Nederland',
          city => 'Elburg',
        ),
      ]
    )
  );
  ok $doc<ok>, 'Document written';

}, '2nd Object test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = collection-object(
    :db-name<contacts>,
    :cl-name<address>
  );

  $sec-table.append-unknown-fields = True;
  my BSON::Document $doc = $sec-table.insert(
    :inserts( [ %(
          street => 'Nauwe Geldeloze pad',
          number => 400,
          country => 'Nederland',
          city => 'Elburg',
          extra-field => 'etcetera'
        ),
      ]
    )
  );

  ok $doc<ok>, 'write ok';
  is $doc<n>, 1, 'one record written';

}, 'append unknown fields test';

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::HL::Collection $sec-table = collection-object(
    :db-name<contacts>,
    :cl-name<address>
  );

  my BSON::Document $doc = $sec-table.insert(
    :inserts( [ %(
          street => 'Nauwe Geldeloze pad',
          number => 400,
          country => 'Nederland',
          city => 'Elburg',
        ), %(
          street => 'Mauve plein',
          number => 2,
          number-mod => 'a',
          country => 'Nederland',
          city => 'Groningen',
        )
      ]
    )
  );
  ok $doc<ok>, 'write ok';
  is $doc<n>, 2, 'two records written';
  say $doc.perl;

}, 'multiple records test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing;
