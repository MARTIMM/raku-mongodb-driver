use v6.c;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use BSON::Document;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my MongoDB::Client $client = $ts.get-connection();
my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');
my BSON::Document $req;
my BSON::Document $doc;

# Drop database first, not checked for success.
#
$database.run-command(BSON::Document.new: (dropDatabase => 1));

#-------------------------------------------------------------------------------
subtest {

  $req .= new: (
    insert => 'famous_people',
    documents => [
      BSON::Document.new((
        name => 'Larry',
        surname => 'Walll',
        languages => BSON::Document.new((
          Perl0 => 'introduced Perl to my officemates.',
          Perl1 => 'introduced Perl to the world',
          Perl2 => "introduced Henry Spencer's regular expression package.",
          Perl3 => 'introduced the ability to handle binary data.',
          Perl4 => 'introduced the first Camel book.',
          Perl5 => 'introduced everything else, including the ability to introduce everything else.',
          Perl6 => 'A perl changing perl event, Dec 12,2015'
        )),
      )),
    ]
  );

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 1, "Inserted 1 document";

  $doc = $database.run-command: (
    findAndModify => 'famous_people',
    query => (surname => 'Walll'),
    update => ('$set' => surname => 'Wall'),
  );

#say "\nDoc: ", $doc.perl, "\n";

  is $doc<ok>, 1, "Result is ok";
  is $doc<value><surname>, 'Walll', "Old data returned";
  is $doc<lastErrorObject><updatedExisting>, True, "Existing document updated";


  $req .= new: (
    insert => 'names',
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
#say "RP:\n", $req.perl;

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 5, "Inserted 5 documents";

}, "Query and Write Operation Commands";

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

  #-------------------------------------------------------------------------------
  #
  $doc = $database.run-command: (
    insert => 'cl1',
    documents => [(code => 10)]
  );

  $doc = $database.run-command: (
    insert => 'cl2',
    documents => [(code => 15)]
  );

  $doc = $database.run-command: (listCollections => 1,);
  is $doc<ok>, 1, 'list collections request ok';
#say "LC: ", $doc.perl;
  my MongoDB::Cursor $c .= new( :$client, :cursor-doc($doc<cursor>));
  my Bool $f-cl1 = False;
  my Bool $f-cl2 = False;
  while $c.fetch -> BSON::Document $d {
    $f-cl1 = True if $d<name> eq 'cl1';
    $f-cl2 = True if $d<name> eq 'cl2';
  }

  ok $f-cl1, 'Collection cl1 listed';
  ok $f-cl2, 'Collection cl2 listed';

  # Second attempt using iteratable role
  #
  $f-cl1 = False;
  $f-cl2 = False;
  $doc = $database.run-command: (listCollections => 1,);
  for MongoDB::Cursor.new( :$client, :cursor-doc($doc<cursor>)) -> BSON::Document $d {
    $f-cl1 = True if $d<name> eq 'cl1';
    $f-cl2 = True if $d<name> eq 'cl2';
  }

  ok $f-cl1, 'Collection cl1 listed';
  ok $f-cl2, 'Collection cl2 listed';

}, "Diagnostic Commands";

#-------------------------------------------------------------------------------
subtest {

  # Drop database
  #
  $req .= new: (dropDatabase => 1,);
  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Drop database test ok";

}, "Instance Administration Commands";

#-------------------------------------------------------------------------------
subtest {

  $doc = $database.run-command: (unknownDbCommand => 'unknownCollection',);
  is $doc<ok>, 0, 'unknown request';
  is $doc<errmsg>, 'no such command: unknownDbCommand', 'Err: no such command';
  is $doc<code>, 59, 'Code 59';
#say "\nDoc: ", $doc.perl, "\n";
}, "Error tests";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);


=finish

#-------------------------------------------------------------------------------
subtest {
  
}, '';
