use v6;
use lib 't';
use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use BSON::Document;

#-------------------------------------------------------------------------------
#drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

my BSON::Document $req;
my BSON::Document $doc;

# single server tests => one server key
my Hash $clients = $ts.create-clients;
my Str $skey = $clients.keys[0];
my Str $bin-path = $ts.server-control.get-binary-path( 'mongod', $skey);

my MongoDB::Client $client = $clients{$clients.keys[0]};
my MongoDB::Database $database = $client.database('test');
my MongoDB::Database $db-admin = $client.database('admin');

# Drop database first then create new databases
$req .= new: ( dropDatabase => 1 );
$database.run-command($req);

#-------------------------------------------------------------------------------
subtest "Database, create collection, drop", {

  isa-ok $database, 'MongoDB::Database';
  is $database.name, 'test', 'Check database name';

  # Create a collection explicitly. Try for a second time
  $req .= new: (create => 'cl1');
  $doc = $database.run-command($req);
  is $doc<ok>, 1, 'Created collection cl1';

  # Second try gets an error
  $doc = $database.run-command($req);
  is $doc<ok>, 0, 'Second collection cl1 not created';
  diag $doc.perl;
  like $doc<errmsg>, /:s already exists/, $doc<errmsg>;
#TODO get all codes and test on code instead of messages to prevent changes
# in mongod in future

  if $bin-path ~~ / '2.6.' \d+ / {
    skip "No error code returned from 2.6.* server", 1;
  }

  else {
    is $doc<code>, 48, 'error code 48';
  }
}

#-------------------------------------------------------------------------------
subtest "Error checking", {
  $doc = $database.run-command: (getLastError => 1,);
  is $doc<ok>, 1, 'No last errors';

  $doc = $database.run-command: (getPrevError => 1,);
  is $doc<ok>, 1, 'No previous errors';

  $doc = $database.run-command: (resetError => 1,);
  is $doc<ok>, 1, 'Rest errors ok';
}

#-------------------------------------------------------------------------------
subtest 'Database admin tests', {
  is $db-admin.name, 'admin', 'Name admin database ok';
  try {
    $db-admin.collection('my-collection');

    CATCH {
      default {
        my $m = .message;
        $m ~~ s:g/\n+//;
        like .message, /:s Cannot set collection name/, .message;
      }
    }
  }
}

#-------------------------------------------------------------------------------
subtest 'Database statistics server 1', {

  $doc = $db-admin.run-command: (listDatabases => 1,);
#say $doc.perl;
  ok $doc<ok>.Bool, 'Run command ran ok';
  ok $doc<totalSize> > 1, 'Total size at least bigger than one byte ;-)';

  my %db-names;
  my Array $db-docs = $doc<databases>;
  my $idx = 0;
  for $db-docs[*] -> $d {
    %db-names{$d<name>} = $idx++;
  }

  ok %db-names<test>:exists, 'test found';
  ok !@($doc<databases>)[%db-names<test>]<empty>, 'Database test is not empty';
}

#-------------------------------------------------------------------------------
subtest 'Drop a database', {

  try {
    $doc = $database.run-command: (dropDatabase => 1,);
    is $doc<ok>, 1, 'Drop command went well';

    $doc = $db-admin.run-command: (listDatabases => 1,);
    my %db-names = %();
    my $idx = 0;
    my Array $db-docs = $doc<databases>;
    for $db-docs[*] -> $d {
      %db-names{$d<name>} = $idx++;
    }

    nok %db-names<test>:exists, 'test not found';

    CATCH {
      default {
        .say;
      }
    }
  }
}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
