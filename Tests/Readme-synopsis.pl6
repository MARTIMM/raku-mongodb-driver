use v6;

use Test;
use BSON::Document;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

my MongoDB::Client $client .= new(:uri('mongodb://:65010'));
my MongoDB::Database $database = $client.database('myPetProject');

# Drop database before start
$database.run-command(BSON::Document.new: (dropDatabase => 1));

# Inserting data in collection 'famous-people'
my BSON::Document $req .= new: (
  insert => 'famous-people',
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

my BSON::Document $doc = $database.run-command($req);
is $doc<ok>, 1, "insert request ok";
is $doc<n>, 1, "inserted 1 document in famous-people";

# Inserting more data in another collection 'names'
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

$doc = $database.run-command($req);
is $doc<ok>, 1, "insert request ok";
is $doc<n>, 6, "inserted 6 documents in names";

# Remove a record from the names collection
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
is $doc<n>, 1, "deleted 1 doc from names";

# Modifying all records where the name has the character 'y' in their name.
# Add a new field to the document
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
is $doc<n>, 2, "selected 2 docs in names";
is $doc<nModified>, 2, "modified 2 docs in names";

# And repairing a terrible mistake in the name of Larry Wall
$doc = $database.run-command: (
  findAndModify => 'famous-people',
  query => (surname => 'Walll'),
  update => ('$set' => surname => 'Wall'),
);

is $doc<ok>, 1, "findAndModify request ok";
is $doc<value><surname>, 'Walll', "old data returned";
is $doc<lastErrorObject><updatedExisting>, True, "existing document in famous-people updated";

# Trying it again will show that the record is updated.
$doc = $database.run-command: (
  findAndModify => 'famous_people',
  query => (surname => 'Walll'),
  update => ('$set' => surname => 'Wall'),
);

is $doc<ok>, 1, "findAndModify retry request ok";
is $doc<value>, Any, 'record not found';
is $doc<lastErrorObject><updatedExisting>, False, "updatedExisting returned False";

# Finding things
my MongoDB::Collection $collection = $database.collection('names');
my MongoDB::Cursor $cursor = $collection.find: :projection(
  ( _id => 0, name => 1, surname => 1, type => 1)
);

while $cursor.fetch -> BSON::Document $d {
  say "Name and surname: ", $d<name>, ' ', $d<surname>,
      ($d<type> ?? ", $d<type>" !! '');

  if $d<name> eq 'Moritz' {
    # Just to be sure
    $cursor.kill;
    last;
  }
}

done-testing;
