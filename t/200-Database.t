use v6;
use lib 't'; #, '/home/marcel/Languages/Perl6/Projects/BSON/lib';
use Test-support;
use Test;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::AdminDB;

#`{{
  Testing;
    database.run-command()              Run command
    database.drop()                     Drop database
    database.create-collection()        Create collection explicitly
}}

my BSON::Document $req;
my BSON::Document $doc;
my MongoDB::Client $client = get-connection();
my MongoDB::Database $database .= new(:name<test>);
my MongoDB::AdminDB $db-admin .= new;

# Drop database first then create new databases
#
$req .= new: ( dropDatabase => 1 );
$doc = $database.run-command($req);

#-------------------------------------------------------------------------------
subtest {
  isa-ok $database, 'MongoDB::Database';
  is $database.name, 'test', 'Check database name';

  # Create a collection explicitly. Try for a second time
  #
  $req .= new: (create => 'cl1');
  $doc = $database.run-command($req);
  is $doc<ok>, 1, 'Created collection cl1';

  # Second try gets an error
  #
  $doc = $database.run-command($req);
  is $doc<ok>, 0, 'Second collection cl1 not created';
  is $doc<errmsg>, 'collection already exists', $doc<errmsg>;
  is $doc<code>, 48, 'mongo error code 40';

}, "Database, create collection, drop";

#-------------------------------------------------------------------------------
subtest {
  $doc = $database.run-command: (getLastError => 1);
  is $doc<ok>, 1, 'No last errors';

  $doc = $database.run-command: (getPrevError => 1);
  is $doc<ok>, 1, 'No previous errors';

  $doc = $database.run-command: (resetError => 1);
  is $doc<ok>, 1, 'Rest errors ok';
}, "Error checking";


#-------------------------------------------------------------------------------
subtest {
  is $db-admin.name, 'admin', 'Name admin database ok';
  try {
    $db-admin.collection('my-collection');
    
    CATCH {
      default {
        my $m = .message;
        $m ~~ s:g/\n+//;
        ok .message ~~ m:s/Cannot set collection name on virtual admin database/,
           'Cannot set collection name on virtual admin database';
      }
    }
  }

  $doc = $db-admin.run-command: (listDatabases => 1);
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
}, 'Database statistics';

#-------------------------------------------------------------------------------
subtest {
  $doc = $database.run-command: (dropDatabase => 1);
  is $doc<ok>, 1, 'Drop command went well';

  $doc = $db-admin.run-command: (listDatabases => 1);
  my %db-names = %();
  my $idx = 0;
  my Array $db-docs = $doc<databases>;
  for $db-docs[*] -> $d {
    %db-names{$d<name>} = $idx++;
  }

  nok %db-names<test>:exists, 'test not found';
}, 'Drop a database';

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
