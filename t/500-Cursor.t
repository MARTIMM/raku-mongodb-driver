use v6.d;

use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use BSON::Document;
use MongoDB::Cursor;

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
# single server tests => one server key
my Hash $clients = $ts.create-clients;

my MongoDB::Client $client = $clients{$clients.keys[0]};
my MongoDB::Database $database = $client.database('test');
my MongoDB::Collection $collection = $database.collection('names');
my BSON::Document $req;
my BSON::Document $doc;

# get version to skip certain tests
my Str $version = $ts.server-version($database);
#note $version;

# Drop database first, not checked for success.
$database.run-command(BSON::Document.new: (dropDatabase => 1));

#-------------------------------------------------------------------------------
subtest "cursor iteration", {

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
        name => 'piet',
        surname => 'jansen',
      ), (
        name => 'marcel',
        surname => 'timmerman',
      ), (
        name => 'foo',
        surname => 'bar',
      ),
    ]
  );

  $doc = $database.run-command($req);
  is $doc<ok>, 1, "Result is ok";
  is $doc<n>, 8, "Inserted $doc<n> documents";

  my MongoDB::Cursor $cursor := $collection.find;

#TODO: are documents returned in same order as insert?
  my Int $c = 0;
  for $cursor -> BSON::Document $d {
    is $d<name>, $req<documents>[$c++]<name>, $d<name>;
  }


  $doc = $database.run-command(BSON::Document.new: (listCollections => 1));
  my MongoDB::Cursor $c2 = MongoDB::Cursor.new(
    :$client, :cursor-doc($doc<cursor>)
  );

  my BSON::Document $d = $c2.iterator.pull-one;
  is $d<idIndex><ns>, 'test.names', "index on $d<idIndex><ns>";

#note "\nc2; ", '-' x 75, $d.raku, '-' x 80;
}


#-------------------------------------------------------------------------------
# Cleanup
done-testing();
