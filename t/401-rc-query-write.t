use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Client $client = get-connection();
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
  is $doc<ok>, 1, "insert request ok";
  is $doc<n>, 1, "inserted 1 document";

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
      ), (
        name => 'Someone',
        surname => 'Unknown',
      ),
    ]
  );
#say "RP:\n", $req.perl;

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "insert request ok";
  is $doc<n>, 6, "inserted 6 documents";

}, "Insert";

#-------------------------------------------------------------------------------
subtest {

  $req .= new: (
    delete => 'names',
    deletes => [ (
        q => ( surname => ('Unknown'),),
        limit => 1,
      ),
    ],
  );

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "delete request ok";
  is $doc<n>, 1, "deleted 1 doc";

}, 'delete';


#-------------------------------------------------------------------------------
subtest {

  $req .= new: (
    update => 'names',
    updates => [ (
        q => ( name => ('$regex' => BSON::Regex.new( :regex<y>, :options<i>),),),
        u => ('$set' => (type => "men with 'y' in name"),),
        upsert => True,
        multi => True,
      ),
    ],
  );

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "update request ok";
  is $doc<n>, 2, "selected 2 docs";
  is $doc<nModified>, 2, "modified 2 docs using multi";

}, 'update';

#-------------------------------------------------------------------------------
subtest {

  $doc = $database.run-command: (
    findAndModify => 'famous_people',
    query => (surname => 'Walll'),
    update => ('$set' => surname => 'Wall'),
  );

  is $doc<ok>, 1, "findAndModify request ok";
  is $doc<value><surname>, 'Walll', "old data returned";
  is $doc<lastErrorObject><updatedExisting>, True, "existing document updated";

  $doc = $database.run-command: (
    findAndModify => 'famous_people',
    query => (surname => 'Walll'),
    update => ('$set' => surname => 'Wall'),
  );

  is $doc<ok>, 1, "findAndModify request ok";
  is $doc<value>, Any, 'record not found';

}, "findAndModify";

#-------------------------------------------------------------------------------
subtest {

  $doc = $database.run-command: (getLastError => 1,);
  is $doc<ok>, 1, 'getLastError request ok';
  is $doc<err>, Any, 'no errors';
  is $doc<errmsg>, Any, 'No message';

}, "getLastError";

#-------------------------------------------------------------------------------
subtest {

  $doc = $database.run-command: (
    parallelCollectionScan => 'names',
    numCursors => 1
  );
  is $doc<ok>, 1, 'parallelCollectionScan request ok';
  ok $doc<cursors> ~~ Array, 'found array of cursors';
  is $doc<cursors>.elems, 1, "returned {$doc<cursors>.elems} cursor";
#say "\nDoc: ", $doc.perl, "\n";


  for $doc<cursors>.list -> $cdoc {
#say 'C doc: ', $cdoc.perl;

    is $cdoc<ok>, True, 'returned cursor ok';
    if $cdoc<ok> {
      my MongoDB::Cursor $c .= new( :$client, :cursor-doc($cdoc<cursor>));
      my BSON::Document $d = $c.fetch;
      is $d<name>, 'Larry', "First name $d<name>";
      is $d<surname>, 'Wall', "Last name $d<surname>";
      is $d<type>, "men with 'y' in name", $d<type>;
#say 'D doc: ', $d.perl;

      $c.kill;
    }
  }

}, "parallelCollectionScan";

#-------------------------------------------------------------------------------
# Cleanup
#
# Number of stored objects can be one when Server object monitors
# the mongod server
#
info-message("Test $?FILE stop");
done-testing();
exit(0);




=finish

#-------------------------------------------------------------------------------
subtest {

}, '';

say "\nReq: ", $req.perl, "\n";
say "\nDoc: ", $doc.perl, "\n";

