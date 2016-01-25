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
    Replication using mongodb at localhost:27012
}}

my MongoDB::Client $client .= instance(:url('mongodb:///'));
my MongoDB::Database $database .= new(:name<test>);
my MongoDB::Collection $collection = $database.collection('repl-test');
my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest {

  $doc = $database.run-command: (isMaster => 1);
say "Doc: ", $doc.perl;

  is $doc<ok>, 1, 'is master request ok';

}, "replication";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
