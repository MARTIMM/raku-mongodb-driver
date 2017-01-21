use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use BSON::Document;

#-------------------------------------------------------------------------------
#drop-send-to('mongodb');
#drop-send-to('screen');
#add-send-to( 'screen', :to($*ERR), :level(* >= MongoDB::Loglevels::Trace));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client = $ts.get-connection();
my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');
my MongoDB::Collection $collection = $database.collection('cl1');
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {
  # Create collection and insert data in it!
  #
  $doc = $database.run-command: (
    insert => $collection.name,
    documents => [
      ( name => 'Jan Klaassen', code => 14),
      ( name => 'Piet Hein',    code => 20),
      ( name => 'Jan Hein',     code => 20)
    ]
  );

  #-------------------------------------------------------------------------------
  #
  $doc = $database.run-command: (count => $collection.name,);
  is $doc<ok>, 1, 'Count request ok';
  is $doc<n>, 3, 'Three documents in collection';

  $doc = $database.run-command: (
    count => $collection.name,
    query => (name => 'Piet Hein')
  );
  is $doc<n>, 1, 'One document found';

  #-------------------------------------------------------------------------------
  #
  $doc = $database.run-command: (
    distinct => $collection.name,
    key => 'code'
  );
  is $doc<ok>, 1, 'Distinct request ok';
  
  is-deeply $doc<values>.sort, ( 14, 20), 'Codes found are 14, 20';

  $doc = $database.run-command: (
    distinct => $collection.name,
    key => 'code',
    query => (name => 'Piet Hein')
  );
  is-deeply $doc<values>, [20], 'Code found is 20';


}, "simple collection operations";

#-------------------------------------------------------------------------------
# Cleanup
#
$database.run-command: (dropDatabase => 1,);
$client.cleanup;
info-message("Test $?FILE stop");
sleep .2;
drop-all-send-to();
done-testing();
exit(0);
