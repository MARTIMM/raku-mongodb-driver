use v6;
use lib 't'; #, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
use Test-support;
use Test;
use MongoDB::Connection;

#`{{
  Testing: Query and Write Operation Commands
    insert

  Testing: Instance Administration Commands

  Testing: Diagnostic Commands
    list databases
    drop database

}}

my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database = $connection.database('test');
my MongoDB::Database $db-admin = $connection.database('admin');
my BSON::Document $req;
my BSON::Document $doc;

# Drop database first, not checked for success.
#
$database.run-command(BSON::Document.new: (dropDatabase => 1));

#-------------------------------------------------------------------------------
subtest {

  $req .= new: (
    insert => 'test',
    documents => [ (
        name => 'Larry',
        surname => 'Wall',
      ), (
        name => 'Damian',
        surname => 'Conway',
      ), (
        name => 'Jonathan',
        surname => 'Worthington',
      ), (
        name => 'Moritz',
        surname => 'Lenz',
      ), (
        name => 'Many',
        surname => 'More',
      ),
    ]
  );

#`{{ The bulky way
  $req .= new: (
    insert => 'test',
    documents => [
      BSON::Document.new((
        name => 'Larry',
        surname => 'Wall',
      )),
      BSON::Document.new((
        name => 'Damian',
        surname => 'Conway',
      )),
      BSON::Document.new((
        name => 'Jonathan',
        surname => 'Worthington',
      )),
      BSON::Document.new((
        name => 'Moritz',
        surname => 'Lenz',
      )),
      BSON::Document.new((
        name => 'Many',
        surname => 'More',
      )),
    ]
  );
}}

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 5, "Inserted 5 documents";

}, "Query and Write Operation Commands";

#-------------------------------------------------------------------------------
subtest {

  is $doc<ok>, 1, "Result is ok";

}, "Instance Administration Commands";

#-------------------------------------------------------------------------------
subtest {

  # List databases
  #
  $doc = $db-admin.run-command(BSON::Document.new: (listDatabases => 1));
  is $doc<ok>, 1, 'List databases response ok';
  ok $doc<databases>[0]<name>:exists, "name field in doc[0] ok";
  ok $doc<databases>[0]<sizeOnDisk>:exists, "sizeOnDisk field in do[0]c ok";
  ok $doc<databases>[0]<empty>:exists, "empty field in doc[0] ok";

  # Get the database name from the statistics and save the index into the array
  # with that name. Use the zip operator to pair the array entries %doc with
  # their index number $idx.
  #
  my Array $db-docs = $doc<databases>;
  my %db-names;
  for $db-docs.kv -> $idx, $doc {
    %db-names{$doc<name>} = $idx;
  }

  ok %db-names<test>:exists, 'database test found';
  ok !$db-docs[%db-names<test>]<empty>, 'Database test is not empty';

  # Drop database
  #
#  $doc = $database.run-command(BSON::Document.new: (dropDatabase => 1));
#  is $doc<ok>, 1, "Drop database test ok";

}, "Diagnostic Commands";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);


=finish

#-------------------------------------------------------------------------------
subtest {
  
}, '';
