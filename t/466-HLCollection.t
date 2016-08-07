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

  # Insert enaugh records
  my Array $r = [];
  $r.push: %(
    street => 'Jan Gestelsteeg',
    number => 253,
    number-mod => 'zwart',
    country => 'Nederland',
    zip => '1043 XY',
    city => 'Lutjebroek',
    state => 'Gelderland',
  );
  for ^10 {
    $r.push: %(
      street => 'Jan Gestelsteeg',
      number => 253,
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


  $doc = $table.delete(:deletes([(q => (number => 253),),]));
  ok $doc<ok>, 'Delete ok';
  is $doc<n>, 1, 'One doc deleted';

  $doc = $table.delete(
    :deletes( [
      (q => (number => 253),),
      (q => (number => 253),)
    ])
  );

  ok $doc<ok>, 'Delete ok';
  is $doc<n>, 2, 'Two docs deleted';


  $doc = $table.delete(
    :deletes( [
        (:q(number => 253), :!limit),
        (:q(number => 400), :!limit),
        (:q(number => 2), :!limit)
      ]
    ),
    :!ordered
  );

  ok $doc<ok>, 'Delete ok';
  ok $doc<n> > 0, "More than 1($doc<n>) doc deleted";

}, 'delete test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing;
