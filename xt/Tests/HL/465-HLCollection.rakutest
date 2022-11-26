use v6;
use Test;

use MongoDB;
use MongoDB::HL::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::MdbLoglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::HL::Collection $table = collection-object(
  :uri<mongodb://:65010>,
  :db-name<contacts>,
  :cl-name<address>,

  :schema( [
      street => [ True, Str],
      number => [ True, Int],
      number-mod => [ False, Str],
      city => [ True, Str],
      zip => [ False, Str],
      state => [ False, Str],
      country => [ True, Str],
    ]
  )
);

#-------------------------------------------------------------------------------
subtest 'all optional fields test', {

  my MongoDB::HL::Collection $subtable = collection-object(
    :uri<mongodb://:65010>,
    :db-name<c0>,
    :cl-name<a0>,

    :schema( [
        street => [ False, Str],
        number => [ False, Int],
      ]
    )
  );

  my BSON::Document $doc = $subtable.insert( :inserts([{ },]));
  is $doc<fields><->, 'current record is empty', $doc<fields><->;
};

#-------------------------------------------------------------------------------
subtest 'field failure test', {

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

  diag $doc.perl;
  ok !$doc<ok>, 'Document has problems';
  is $doc<fields><number>, 'missing', 'field number is missing';
  is $doc<fields><city>, 'missing', 'field city is missing';
  is $doc<fields><zip>, 'type failure, is Num but must be Str',
     "field zip $doc<fields><zip>";
};

#-------------------------------------------------------------------------------
subtest 'Proper fields test', {

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

};

#-------------------------------------------------------------------------------
subtest '2nd Object test', {

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

};

#-------------------------------------------------------------------------------
subtest 'append unknown fields test', {

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
};

#-------------------------------------------------------------------------------
subtest 'multiple records test', {

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
  diag $doc.perl;
  ok $doc<ok>, 'write ok';
  is $doc<n>, 2, 'two records written';
};

#-------------------------------------------------------------------------------
# Cleanup
info-message("Test $?FILE end");
done-testing;
