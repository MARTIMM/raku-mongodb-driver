use v6;
use Test;

use lib 't';
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::HL::Users;
use MongoDB::Authenticate::Credential;
use BSON::Document;
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
my MongoDB::Test-support $ts .= new;
my MongoDB::Client $client;
my MongoDB::Authenticate::Credential $cred .= new(
    :username<user>, :password<pencil>,
    :auth-mechanism<SCRAM-SHA-1>
);
ok $cred.defined, 'T0';
is $cred.password, "pencil", 'T1';
my $x = {
    $cred .= new(
        :username<user>, :password<pencil>, :auth-mechanism<MONGODB-X509>
    );
};
dies-ok $x, 'T2';
my $y = {
    $cred .= new( :password<pencil>, :auth-mechanism<MONGODB-CR>);
};
dies-ok $y, 'T3';
my Int $port1 = $ts.server-control.get-port-number('s1');
$client .= new(:uri("mongodb://localhost"));
my MongoDB::Database $database = $client.database('tdb');
my MongoDB::HL::Users $users .= new(:$database);
my BSON::Document $doc = $users.create-user(
    'user', 'pencil',
    :roles([(role => 'readWrite', db => 'tdb'),])
);
ok $doc<ok>, 'T4';
$client .= new(:uri("mongodb://user:pencil@localhost:$port1/tdb"));
$database = $client.database('tdb');
ok $client.defined, 'T5';
is $client.credential.auth-mechanism, "", 'T6';
$doc = $database.run-command: (
    insert => 'tcol',
    documents => [
        BSON::Document.new: (
            name => 'Larry',
            surname => 'Walll',
        ),
    ]
);
say "Doc:", $doc.perl;
is $doc<ok>, 1, 'T7';
is $doc<n>, 1, 'T8';
is $client.credential.auth-mechanism, "SCRAM-SHA-1", 'T9';
$client.cleanup;
$client .= new(:uri("mongodb://localhost:$port1"));
ok $client.defined, 'T10';
$client.cleanup;

done-testing;
