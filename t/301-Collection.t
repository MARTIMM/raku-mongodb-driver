use v6;
use lib 't'; #, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
use Test-support;
use Test;
use MongoDB::Connection;

#`{{
  Testing;
    count                       Count documents whithout using find.
    distinct                    Find distinct values
    list collections            Return collection info in database
    collection names            Return collectionnames in database
}}

my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database .= new(:name<test>);
my MongoDB::Database $db-admin .= new(:name<admin>);
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


}, "simple collection operations";

#-------------------------------------------------------------------------------
# Cleanup
#
$database.run-command: (dropDatabase => 1);

done-testing();
exit(0);
