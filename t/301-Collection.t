use v6;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use BSON::Document;

#------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "t/Log/301-C0llection.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
set-filter(|<ObserverEmitter Timer Socket>);

info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

# single server tests => one server key
my Hash $clients = $ts.create-clients;
my Str $skey = $clients.keys[0];
#my Str $bin-path = $ts.server-control.get-binary-path( 'mongod', $skey);
my MongoDB::Client $client = $clients{$clients.keys[0]};
my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');
my MongoDB::Collection $collection = $database.collection('cl1');
my BSON::Document $req;
my BSON::Document $doc;

#------------------------------------------------------------------------------
subtest {
  # Create collection and insert data in it!
  $req .= new: (
    insert => $collection.name,
    documents => [
      ( name => 'Jan Klaassen', code => 14),
      ( name => 'Piet Hein',    code => 20),
      ( name => 'Jan Hein',     code => 20)
    ]
  );
  $doc = $database.run-command($req);

  #----------------------------------------------------------------------------
  $req .= new: (count => $collection.name);
  $doc = $database.run-command($req);
  is $doc<ok>, 1, 'Count request ok';
  is $doc<n>, 3, 'Three documents in collection';

  $req .= new: (
    count => $collection.name,
    query => (name => 'Piet Hein')
  );
  $doc = $database.run-command($req);
  is $doc<n>, 1, 'One document found';

  #----------------------------------------------------------------------------
  $req .= new: (
    distinct => $collection.name,
    key => 'code'
  );
  $doc = $database.run-command($req);
  is $doc<ok>, 1, 'Distinct request ok';

  is-deeply $doc<values>.sort, ( 14, 20), 'Codes found are 14, 20';

  $req .= new: (
    distinct => $collection.name,
    key => 'code',
    query => (name => 'Piet Hein')
  );
  $doc = $database.run-command($req);
  is-deeply $doc<values>, [20], 'Code found is 20';


}, "simple collection operations";

#------------------------------------------------------------------------------
# Cleanup
$database.run-command: (dropDatabase => 1,);
$client.cleanup;
done-testing();
