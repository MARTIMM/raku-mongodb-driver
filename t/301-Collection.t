use v6;
use lib 't'; #, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
use Test-support;
use Test;
use MongoDB::Connection;
use MongoDB::Cursor;

#`{{
  Testing;
    collection.count()                  Count documents whithout using find.
    collection.distinct()               Find distinct values
    list_collections()                  Return collection info in database
    collection-names()                  Return collectionnames in database
}}

my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database = $connection.database('test');
my MongoDB::Database $db-admin = $connection.database('admin');
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
  $doc = $database.run-command: (count => $collection.name);
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

  #-------------------------------------------------------------------------------
  #
  $doc = $database.run-command: (
    insert => 'cl2',
    documents => [(code => 15)]
  );

  $doc = $database.run-command: (listCollections => 1);
  is $doc<ok>, 1, 'list collections request ok';

  my MongoDB::Cursor $c .= new(:cursor-doc($doc<cursor>));
  my Bool $f-cl1 = False;
  my Bool $f-cl2 = False;
  while $c.fetch -> $d {
#say "N & O: ", $d<name>, $d<options>;
    $f-cl1 = True if $d<name> eq 'cl1';
    $f-cl2 = True if $d<name> eq 'cl2';
  }

  ok $f-cl1, 'Collection cl1 listed';
  ok $f-cl2, 'Collection cl2 listed';

}, "simple collection operations";

#-------------------------------------------------------------------------------
# Cleanup
#
$database.run-command: (dropDatabase => 1);

done-testing();
exit(0);
