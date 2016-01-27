use v6;
use lib 't';
use Test-support;
use Test;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#`{{
  Testing;
    Replication using mongodb at localhost:27017
}}

set-exception-process-level(MongoDB::Severity::Trace);
#open-logfile();

my MongoDB::Client $client .= instance(:url('mongodb:///'));
my MongoDB::Database $database .= new(:name<test>);
my MongoDB::AdminDB $db-admin .= new;
my MongoDB::Collection $collection = $database.collection('repl-test');
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

  $doc = $database.run-command: (isMaster => 1);
  if $doc<setName>:exists and $doc<setName> eq 'myreplset' {
    my Int $new-version = $doc<setVersion> + 1;
    $doc = $db-admin.run-command: (
      replSetReconfig => (
        _id => 'myreplset',
        version => $new-version,
        members => [ (
            _id => 0,
            host => 'localhost:27017',
            tags => (
              name => 'default-server',
              use => 'testing'
            )
          ),
        ]
      ),
      force => False
    );

say "Doc: ", $doc.perl unless $doc<ok>;
  }

  else {
    $doc = $db-admin.run-command: (
      replSetInitiate => (
        _id => 'myreplset',
        members => [ (
            _id => 0,
            host => 'localhost:27017',
            tags => (
              name => 'default-server',
              use => 'testing'
            )
          ),
        ]
      )
    );

say "Doc: ", $doc.perl unless $doc<ok>;
  }

  $doc = $database.run-command: (isMaster => 1);
say "Doc: ", $doc.perl;
  is $doc<ok>, 1, 'is master request ok';
  is $doc<setName>, 'myreplset', "replication name = $doc<setName>";


}, "replication";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
