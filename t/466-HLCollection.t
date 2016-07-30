use v6.c;

use Test;

use MongoDB;
use MongoDB::HL::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

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

  # missing fields not checked
  $table.query-set(
    zip => 2.3.Num,
    extra => 'not described field'
  );

  my BSON::Document $doc = $table.delete;
  say $doc.perl;
  ok !$doc<ok>, 'Document has problems';
  is $doc<fields><zip>, 'type failure, is Num but must be Str',
     "field zip $doc<fields><zip>";
  is $doc<fields><extra>, 'not described in schema',
     'extra is not described in schema';

}, 'query field failure test';

#-------------------------------------------------------------------------------
subtest {

  $table.reset;
  my $fq = $table.query-set(
    number => 253,
  );
  
  is $fq, 0, 'No field errors';

  my BSON::Document $doc = $table.delete;
  say $doc.perl;
  ok $doc<ok>, 'Delete ok';
  is $doc<n>, 1, 'One doc deleted';

}, 'delete test';

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing;
